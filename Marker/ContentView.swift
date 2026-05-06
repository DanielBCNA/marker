import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ConversionStore
    @State private var showOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                DropZoneView()
                    .padding(20)
            } else {
                DropZoneView(compact: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                fileList
                Divider()
                toolbar
            }
        }
        .onAppear {
            showOnboarding = !store.apiKeyConfigured
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet {
                store.refreshAPIKeyStatus()
                showOnboarding = false
            }
        }
    }

    private var fileList: some View {
        List(store.items) { item in
            FileRowView(item: item)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
    }

    private var toolbar: some View {
        HStack {
            Button("Limpiar") { store.clear() }
                .disabled(store.isConverting)

            if store.hasFailures {
                Button("Reintentar fallidos") { store.retryFailed() }
                    .disabled(store.isConverting)
            }

            Spacer()

            if store.hasResults {
                Button("Abrir carpeta MD") { store.openOutputFolder() }
            }

            Button("Convertir") { store.convertAll() }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(!store.canConvert)
        }
        .padding(12)
    }
}
