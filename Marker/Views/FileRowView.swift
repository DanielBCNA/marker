import SwiftUI
import AppKit

struct FileRowView: View {
    let item: PDFItem
    @State private var showingError = false

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
            Button {
                showingError = true
            } label: {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Click para ver el error completo")
            .popover(isPresented: $showingError, arrowEdge: .top) {
                ErrorPopover(message: message)
            }
        }
    }
}

private struct ErrorPopover: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Error de conversión")
                .font(.headline)

            ScrollView {
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxHeight: 220)

            HStack {
                Spacer()
                Button("Copiar") { copy() }
            }
        }
        .padding(14)
        .frame(width: 460)
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(message, forType: .string)
    }
}
