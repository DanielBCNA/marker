import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @EnvironmentObject private var store: ConversionStore
    @State private var isTargeted = false

    var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.06) : Color.clear)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
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
