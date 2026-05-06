import SwiftUI

@main
struct MarkerApp: App {
    @StateObject private var store = ConversionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 480)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
