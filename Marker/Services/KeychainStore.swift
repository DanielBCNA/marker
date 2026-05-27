import Foundation
import Security

enum KeychainStore {
    private static let service = "com.marker.app"
    private static let account = "GEMINI_API_KEY"

    static func loadAPIKey() -> String? {
        if let value = loadFromDataProtection() {
            return value
        }
        // Primer arranque post-1.0.1: el item vive en el legacy keychain
        // (file-based, ligado a code signature). Lo leemos una última vez —
        // macOS pedirá autorización porque la firma de esta build es nueva —
        // y lo migramos al Data Protection Keychain, que se identifica por
        // bundle ID y no vuelve a preguntar en futuras versiones.
        if let legacyValue = loadFromLegacy() {
            _ = saveToDataProtection(legacyValue)
            _ = deleteFromLegacy()
            return legacyValue
        }
        return nil
    }

    @discardableResult
    static func saveAPIKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }
        return saveToDataProtection(trimmed)
    }

    @discardableResult
    static func delete() -> Bool {
        let dpDeleted = deleteFromDataProtection()
        let legacyDeleted = deleteFromLegacy()
        return dpDeleted || legacyDeleted
    }

    // MARK: - Data Protection Keychain (vinculado al bundle ID)

    private static func loadFromDataProtection() -> String? {
        var query = baseQuery
        query[kSecUseDataProtectionKeychain as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return readString(query: query)
    }

    @discardableResult
    private static func saveToDataProtection(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        var query = baseQuery
        query[kSecUseDataProtectionKeychain as String] = true

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    @discardableResult
    private static func deleteFromDataProtection() -> Bool {
        var query = baseQuery
        query[kSecUseDataProtectionKeychain as String] = true
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Legacy Keychain (sólo para migración desde 1.0.0)

    private static func loadFromLegacy() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return readString(query: query)
    }

    @discardableResult
    private static func deleteFromLegacy() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Helpers

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func readString(query: [String: Any]) -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
