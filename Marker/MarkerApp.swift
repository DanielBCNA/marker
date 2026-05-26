import SwiftUI
import Sparkle

@main
struct MarkerApp: App {
    @StateObject private var store = ConversionStore()

    // Sparkle 2: con startingUpdater: true arranca el chequeo automático
    // según SUScheduledCheckInterval del Info.plist (24 h).
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    init() {
        Task { @MainActor in
            QuickActionInstaller.installIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
