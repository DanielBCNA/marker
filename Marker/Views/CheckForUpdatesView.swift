import SwiftUI
import Sparkle

/// Entrada de menú "Buscar actualizaciones…" que aparece en el menú
/// Marker (justo debajo de "Acerca de Marker"). Sparkle controla por
/// su cuenta la disponibilidad del botón: si una comprobación ya está
/// en curso, lo deshabilita.
struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Buscar actualizaciones…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
