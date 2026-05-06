import Foundation

enum FileStatus: Equatable {
    case pending
    case converting
    case done
    case failed(String)

    var label: String {
        switch self {
        case .pending: return "Pendiente"
        case .converting: return "Convirtiendo"
        case .done: return "Hecho"
        case .failed: return "Error"
        }
    }
}

struct PDFItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var status: FileStatus = .pending

    var filename: String { url.lastPathComponent }
    var outputURL: URL { url.deletingPathExtension().appendingPathExtension("md") }
}
