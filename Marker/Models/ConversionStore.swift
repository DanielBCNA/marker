import Foundation
import AppKit

@MainActor
final class ConversionStore: ObservableObject {
    @Published private(set) var items: [PDFItem] = []
    @Published private(set) var isConverting: Bool = false
    @Published var apiKeyConfigured: Bool = APIKeySource.isConfigured

    private let scriptManager = ScriptManager()
    private let maxConcurrent = 3
    private var activeProcesses: [PDFItem.ID: Process] = [:]
    private var cancellingIDs: Set<PDFItem.ID> = []

    func refreshAPIKeyStatus() {
        apiKeyConfigured = APIKeySource.isConfigured
    }

    var hasFailures: Bool { items.contains { if case .failed = $0.status { return true }; return false } }
    var hasResults: Bool { items.contains { $0.status == .done } }
    var canConvert: Bool { !isConverting && items.contains { $0.status == .pending } }

    func add(urls: [URL]) {
        let pdfs = urls.flatMap { expandPDFs(from: $0) }
        let existing = Set(items.map(\.url))
        let new = pdfs.filter { !existing.contains($0) }.map { PDFItem(url: $0) }
        items.append(contentsOf: new)
    }

    func clear() {
        guard !isConverting else { return }
        items.removeAll()
    }

    func remove(id: PDFItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        // No quitamos un archivo en plena conversión: el subproceso ya está en
        // marcha y crearía un fantasma sin fila a donde reportar el resultado.
        if items[index].status == .converting { return }
        items.remove(at: index)
    }

    func cancel(id: PDFItem.ID) {
        guard items.contains(where: { $0.id == id && $0.status == .converting }) else { return }
        cancellingIDs.insert(id)
        activeProcesses[id]?.terminate()
    }

    func openOutputFolder() {
        guard let item = items.first(where: { $0.status == .done }) else { return }
        NSWorkspace.shared.open(item.outputDirectory)
    }

    func convertAll() {
        Task { await runConversion() }
    }

    func retryFailed() {
        for index in items.indices {
            if case .failed = items[index].status {
                items[index].status = .pending
            }
        }
        Task { await runConversion() }
    }

    private func runConversion() async {
        guard !isConverting else { return }
        guard items.contains(where: { $0.status == .pending }) else { return }

        isConverting = true
        defer { isConverting = false }

        var attemptedIDs: Set<PDFItem.ID> = []

        await withTaskGroup(of: PDFItem.ID.self) { group in
            var inFlight = 0

            while true {
                // Rellena huecos con nuevos pendientes en cada vuelta: así los
                // PDFs que el usuario añade durante la conversión entran al
                // ciclo en cuanto se libera un slot. attemptedIDs evita que un
                // PDF cancelado (que vuelve a .pending) se relance dentro de la
                // misma tanda — queda esperando al siguiente Convertir.
                while inFlight < maxConcurrent,
                      let id = claimNextPending(excluding: attemptedIDs) {
                    attemptedIDs.insert(id)
                    group.addTask { [weak self] in
                        await self?.runOne(id: id)
                        return id
                    }
                    inFlight += 1
                }
                if inFlight == 0 { break }
                if await group.next() != nil {
                    inFlight -= 1
                }
            }
        }

        let processed = items.filter { attemptedIDs.contains($0.id) }
        let succeeded = processed.filter { $0.status == .done }.count
        let failed = processed.filter {
            if case .failed = $0.status { return true }; return false
        }.count
        await NotificationManager.shared.notifyBatchComplete(succeeded: succeeded, failed: failed)
    }

    private func claimNextPending(excluding: Set<PDFItem.ID>) -> PDFItem.ID? {
        guard let index = items.firstIndex(where: {
            $0.status == .pending && !excluding.contains($0.id)
        }) else { return nil }
        items[index].status = .converting
        return items[index].id
    }

    private func runOne(id: PDFItem.ID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        do {
            try await scriptManager.convert(input: item.url, output: item.outputURL) { [weak self] process in
                self?.activeProcesses[id] = process
            }
            updateStatus(id: id, status: .done)
        } catch {
            if cancellingIDs.contains(id) {
                // Cancelación deliberada: vuelve a pendiente para que el
                // usuario decida si lo relanza o lo quita.
                updateStatus(id: id, status: .pending)
            } else {
                updateStatus(id: id, status: .failed(error.localizedDescription))
            }
        }
        activeProcesses.removeValue(forKey: id)
        cancellingIDs.remove(id)
    }

    private func updateStatus(id: PDFItem.ID, status: FileStatus) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].status = status
        }
    }

    private func expandPDFs(from url: URL) -> [URL] {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }
        if isDir.boolValue {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )) ?? []
            return contents.filter { $0.pathExtension.lowercased() == "pdf" }
        }
        return url.pathExtension.lowercased() == "pdf" ? [url] : []
    }
}
