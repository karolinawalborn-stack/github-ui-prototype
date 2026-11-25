import Foundation

final class CredentialStore {
    static let shared = CredentialStore()
    private let keychain = KeychainStore.shared

    func saveAPIKey(_ value: String) throws { try keychain.save(value, for: "api-key") }
    func loadAPIKey() -> String? { try? keychain.load(for: "api-key") }
    func saveCookie(_ value: String, platform: NetdiskPlatform) throws { try keychain.save(value, for: "cookie-\(platform.rawValue)") }
    func loadCookie(platform: NetdiskPlatform) -> String? { try? keychain.load(for: "cookie-\(platform.rawValue)") }
    func deleteCookie(platform: NetdiskPlatform) { try? keychain.delete("cookie-\(platform.rawValue)") }
}
