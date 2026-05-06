import Foundation

enum APIKeySource {
    static func current() -> String? {
        if let env = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !env.isEmpty {
            return env
        }
        return KeychainStore.loadAPIKey()
    }

    static var isConfigured: Bool { current() != nil }
}
