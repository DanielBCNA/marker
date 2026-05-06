import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    var compact: Bool = false

    @EnvironmentObject private var store: ConversionStore
    @State private var isTargeted = false

    var body: some View {
        Group {
            if compact {
                compactBody
            } else {
                fullBody
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var fullBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Arrastra PDFs o una carpeta aquí")
                    .font(.title3)
                Text("Selecciona uno o varios archivos PDF, o una carpeta que los contenga.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Selecciona PDFs o una carpeta", action: openPanel)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(borderShape)
    }

    private var compactBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text(isTargeted ? "Suelta los PDFs aquí" : "Arrastra más PDFs o carpetas")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Añadir…", action: openPanel)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(borderShape)
    }

    private var borderShape: some View {
        let radius: CGFloat = compact ? 8 : 12
        let lineWidth: CGFloat = compact ? 1.5 : 2
        let dash: [CGFloat] = compact ? [6, 4] : [8, 6]
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                style: StrokeStyle(lineWidth: lineWidth, dash: dash)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
            )
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .folder]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            store.add(urls: panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in store.add(urls: [url]) }
            }
        }
    }
}
