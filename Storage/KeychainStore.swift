import Foundation
import Security

enum KeychainStoreError: Error {
    case invalidData
    case unexpectedStatus(OSStatus)
}

final class KeychainStore {
    static let shared = KeychainStore()
    private let service = "com.panrelay.app"

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainStoreError.invalidData }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    func load(for key: String) throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else { throw KeychainStoreError.invalidData }
        return value
    }

    func delete(_ key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStoreError.unexpectedStatus(status) }
    }
}
