import Foundation
import Security

/// Secure storage for the Gemini API key using iOS Keychain
enum KeychainService {

    private enum Keys {
        static let geminiAPIKey = "com.chungus.geminiAPIKey"
    }

    // MARK: - Gemini API Key

    static var geminiAPIKey: String? {
        get { read(key: Keys.geminiAPIKey) }
        set {
            if let value = newValue {
                save(key: Keys.geminiAPIKey, value: value)
            } else {
                delete(key: Keys.geminiAPIKey)
            }
        }
    }

    static var hasGeminiKey: Bool {
        geminiAPIKey != nil && !geminiAPIKey!.isEmpty
    }

    // MARK: - Generic Keychain Operations

    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
