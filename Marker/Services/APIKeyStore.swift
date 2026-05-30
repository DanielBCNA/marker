import Foundation
import Security

/// Almacena la API key de Gemini en un archivo local con permisos
/// restringidos al usuario (`~/Library/Application Support/Marker/api_key`).
///
/// Por qué archivo y no Keychain: Marker se firma ad-hoc (sin Apple
/// Developer ID), así que su code signature cambia en cada build. El
/// Keychain liga el acceso sin prompt a esa firma, de modo que cada
/// actualización forzaba a reautorizar. Además el Quick Action de Finder
/// corre `marker-cli.py` como proceso suelto, que tampoco puede leer el
/// Keychain sin pedir autorización. Un archivo 0600 lo leen los tres
/// caminos (app, APIKeySource y marker-cli.py) sin fricción.
enum APIKeyStore {
    private static let service = "com.marker.app"
    private static let account = "GEMINI_API_KEY"

    static func load() -> String? {
        if let value = readFile(at: primaryURL) { return value }
        if let value = readFile(at: legacyConfigURL) { return value }

        // Migración única desde el Keychain legacy (usuarios que guardaron
        // la key con versiones <= 1.0.0). Leerlo puede pedir autorización
        // una última vez; sólo borramos el item si la escritura del archivo
        // tuvo éxito, para no perder la key si algo falla.
        if let legacy = readLegacyKeychain() {
            if saveToFile(legacy) {
                _ = deleteLegacyKeychain()
            }
            return legacy
        }
        return nil
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }
        return saveToFile(trimmed)
    }

    @discardableResult
    static func delete() -> Bool {
        var ok = true
        if FileManager.default.fileExists(atPath: primaryURL.path) {
            ok = (try? FileManager.default.removeItem(at: primaryURL)) != nil
        }
        _ = deleteLegacyKeychain()
        return ok
    }

    // MARK: - File storage

    private static var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Marker", isDirectory: true)
    }

    private static var primaryURL: URL {
        directory.appendingPathComponent("api_key", isDirectory: false)
    }

    private static var legacyConfigURL: URL {
        URL(fileURLWithPath: ("~/.config/marker/api_key" as NSString).expandingTildeInPath)
    }

    private static func readFile(at url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @discardableResult
    private static func saveToFile(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try data.write(to: primaryURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: primaryURL.path
            )
            return true
        } catch {
            return false
        }
    }

    // MARK: - Legacy Keychain (sólo migración y limpieza)

    private static func readLegacyKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @discardableResult
    private static func deleteLegacyKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
