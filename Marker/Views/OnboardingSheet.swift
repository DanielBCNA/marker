import SwiftUI

struct OnboardingSheet: View {
    var onSaved: () -> Void

    @State private var apiKey: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 6) {
                Text("Configura tu API key de Gemini")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Marker convierte los PDFs llamando a Google Gemini. Pega tu API key una vez y queda guardada en el Keychain del sistema.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SecureField("GEMINI_API_KEY", text: $apiKey, prompt: Text("Pega tu API key"))
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Link("Obtener una API key", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)

                Spacer()

                Button("Guardar") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 460)
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainStore.saveAPIKey(trimmed) {
            errorMessage = nil
            onSaved()
        } else {
            errorMessage = "No se pudo guardar en el Keychain. Prueba de nuevo."
        }
    }
}
