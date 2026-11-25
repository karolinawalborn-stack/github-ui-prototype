import Foundation

struct ShareInfo {
    let url: String
    let password: String?
}

struct NetdiskQuota {
    let used: Double
    let label: String
}

protocol NetdiskAdapter {
    var platform: NetdiskPlatform { get }
    func login() async throws
    func validateSession() async throws -> Bool
    func parseShare(url: URL, password: String?) async throws -> ShareInfo
    func listShareFiles(from share: ShareInfo) async throws -> [String]
    func saveToMyDrive(fileIDs: [String], targetFolder: String) async throws
    func createShare(fileIDs: [String], permanent: Bool) async throws -> ShareInfo
    func quota() async throws -> NetdiskQuota
}

enum MockServiceError: Error {
    case unsupported
}

final class MockNetdiskAdapter: NetdiskAdapter {
    let platform: NetdiskPlatform

    init(platform: NetdiskPlatform) {
        self.platform = platform
    }

    func login() async throws {}

    func validateSession() async throws -> Bool { true }

    func parseShare(url: URL, password: String?) async throws -> ShareInfo {
        ShareInfo(url: url.absoluteString, password: password)
    }

    func listShareFiles(from share: ShareInfo) async throws -> [String] {
        ["mock-file-1", "mock-file-2"]
    }

    func saveToMyDrive(fileIDs: [String], targetFolder: String) async throws {}

    func createShare(fileIDs: [String], permanent: Bool) async throws -> ShareInfo {
        guard permanent else { throw MockServiceError.unsupported }
        return ShareInfo(url: "https://example.com/mock-share", password: "6x2m")
    }

    func quota() async throws -> NetdiskQuota {
        NetdiskQuota(used: 0.42, label: "2.1T / 5T")
    }
}
