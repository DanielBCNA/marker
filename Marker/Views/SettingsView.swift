import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ConversionStore
    @State private var apiKey: String = ""
    @State private var savedFeedback: String?

    var body: some View {
        Form {
            Section {
                SecureField("GEMINI_API_KEY", text: $apiKey, prompt: Text("Pega tu API key"))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Guardar") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Borrar") { clear() }
                        .disabled(apiKey.isEmpty)

                    Spacer()

                    if let savedFeedback {
                        Text(savedFeedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Google Gemini")
            } footer: {
                Text("Se guarda en una carpeta protegida de tu Mac. Obtén la key en aistudio.google.com/apikey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 220)
        .onAppear {
            apiKey = APIKeyStore.load() ?? ""
        }
    }

    private func save() {
        let ok = APIKeyStore.save(apiKey)
        savedFeedback = ok ? "Guardada" : "Error al guardar"
        if ok { store.refreshAPIKeyStatus() }
    }

    private func clear() {
        APIKeyStore.delete()
        apiKey = ""
        savedFeedback = "Borrado"
        store.refreshAPIKeyStatus()
    }
}
