import SwiftUI

struct FileRowView: View {
    let item: PDFItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
            Text(item.filename)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statusView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending:
            Text("Pendiente")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .converting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Convirtiendo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            Label("Hecho", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
