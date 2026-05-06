import Foundation
import AppKit

@MainActor
final class ConversionStore: ObservableObject {
    @Published private(set) var items: [PDFItem] = []
    @Published private(set) var isConverting: Bool = false
    @Published var apiKeyConfigured: Bool = APIKeySource.isConfigured

    private let scriptManager = ScriptManager()
    private let maxConcurrent = 3

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
        let pendingIDs = items.compactMap { $0.status == .pending ? $0.id : nil }
        guard !pendingIDs.isEmpty else { return }

        isConverting = true
        defer { isConverting = false }

        await withTaskGroup(of: Void.self) { group in
            var iterator = pendingIDs.makeIterator()
            var inFlight = 0

            while inFlight < maxConcurrent, let id = iterator.next() {
                guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
                items[index].status = .converting
                group.addTask { [weak self] in await self?.runOne(id: id) }
                inFlight += 1
            }

            while await group.next() != nil {
                inFlight -= 1
                if let id = iterator.next() {
                    guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
                    items[index].status = .converting
                    group.addTask { [weak self] in await self?.runOne(id: id) }
                    inFlight += 1
                }
            }
        }
    }

    private func runOne(id: PDFItem.ID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        do {
            try await scriptManager.convert(input: item.url, output: item.outputURL)
            updateStatus(id: id, status: .done)
        } catch {
            updateStatus(id: id, status: .failed(error.localizedDescription))
        }
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
