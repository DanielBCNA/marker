import Foundation
import AppKit

@MainActor
final class ConversionStore: ObservableObject {
    @Published private(set) var items: [PDFItem] = []
    @Published private(set) var isConverting: Bool = false

    private let scriptManager = ScriptManager()

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
        guard let parent = items.first(where: { $0.status == .done })?.url.deletingLastPathComponent() else {
            return
        }
        NSWorkspace.shared.open(parent)
    }

    func convertAll() {
        Task { await runConversion(retryFailedOnly: false) }
    }

    func retryFailed() {
        for index in items.indices {
            if case .failed = items[index].status {
                items[index].status = .pending
            }
        }
        Task { await runConversion(retryFailedOnly: false) }
    }

    private func runConversion(retryFailedOnly: Bool) async {
        guard !isConverting else { return }
        isConverting = true
        defer { isConverting = false }

        for index in items.indices {
            guard items[index].status == .pending else { continue }
            items[index].status = .converting
            do {
                try await scriptManager.convert(input: items[index].url, output: items[index].outputURL)
                items[index].status = .done
            } catch {
                items[index].status = .failed(error.localizedDescription)
            }
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
