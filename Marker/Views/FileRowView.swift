import SwiftUI
import AppKit

struct FileRowView: View {
    let item: PDFItem
    var onRemove: () -> Void

    @State private var showingError = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
            Text(item.filename)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statusView
            removeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
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

    @ViewBuilder
    private var removeButton: some View {
        if isHovering && item.status != .converting {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .help("Quitar de la lista")
            .transition(.opacity)
        } else {
            // Reserva el ancho del botón para que el resto de la fila no
            // baile cuando aparece el ícono al hacer hover.
            Color.clear.frame(width: 16, height: 16)
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
