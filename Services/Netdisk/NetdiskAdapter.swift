import Foundation

struct ShareInfo: Codable {
    let url: String
    let password: String?
    let token: String?
    let shareID: String?
}

struct ShareFile: Codable, Identifiable {
    let id: String
    let name: String
    let isDirectory: Bool
    let token: String?
}

struct NetdiskQuota: Codable {
    let used: Double
    let label: String
}

struct NetdiskAccountInfo: Codable {
    let memberType: String
    let quota: NetdiskQuota
}

enum NetdiskAdapterError: LocalizedError {
    case unauthorized
    case permanentUnsupported(String)
    case captchaRequired
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Cookie 已失效，请重新登录"
        case .permanentUnsupported(let reason): return reason
        case .captchaRequired: return "平台要求验证码或风控验证"
        case .invalidResponse: return "平台响应格式无法识别"
        case .requestFailed(let reason): return reason
        }
    }
}

protocol NetdiskAdapter {
    var platform: NetdiskPlatform { get }
    func validateSession() async throws -> Bool
    func accountInfo() async throws -> NetdiskAccountInfo
    func parseShare(url: URL, password: String?) async throws -> ShareInfo
    func listShareFiles(dir: String) async throws -> [ShareFile]
    func listMyFolders(dir: String) async throws -> [ShareFile]
    func createFolder(name: String, parent: String) async throws -> String
    func saveToMyDrive(shareFiles: [ShareFile], targetFolder: String) async throws
    func createShare(fileIds: [String], permanent: Bool) async throws -> ShareInfo
}

class RESTNetdiskAdapter: NetdiskAdapter {
    let platform: NetdiskPlatform
    let endpoint: EndpointConfig
    let client: HTTPClient
    let credentialStore: CredentialStore

    init(platform: NetdiskPlatform, endpoint: EndpointConfig, client: HTTPClient = .shared, credentialStore: CredentialStore = .shared) {
        self.platform = platform
        self.endpoint = endpoint
        self.client = client
        self.credentialStore = credentialStore
    }

    func validateSession() async throws -> Bool {
        do {
            _ = try await request(path: "session", method: "GET", body: nil)
            return true
        } catch NetdiskAdapterError.unauthorized { return false }
    }

    func accountInfo() async throws -> NetdiskAccountInfo {
        let data = try await request(path: "session", method: "GET", body: nil)
        let object = try jsonObject(data)
        let member = string(object, keys: ["member_type", "memberType", "vip_name", "level"]) ?? "已登录"
        let used = number(object, keys: ["used", "used_space", "quota_used"]) ?? 0
        let total = number(object, keys: ["total", "total_space", "quota"]) ?? 1
        let quota = NetdiskQuota(used: total > 0 ? min(1, used / total) : 0, label: formatBytes(used, total: total))
        return NetdiskAccountInfo(memberType: member, quota: quota)
    }

    func parseShare(url: URL, password: String?) async throws -> ShareInfo {
        let body = try jsonData(["url": url.absoluteString, "pwd": password ?? ""])
        let data = try await request(path: "parse", method: "POST", body: body)
        let object = try jsonObject(data)
        let token = string(object, keys: ["share_token", "shareToken", "token", "share_id", "shareId"])
        return ShareInfo(url: url.absoluteString, password: password, token: token, shareID: nil)
    }

    func listShareFiles(dir: String) async throws -> [ShareFile] {
        let data = try await request(path: "files", method: "GET", body: nil, query: [URLQueryItem(name: "dir", value: dir)])
        return parseFiles(data)
    }

    func listMyFolders(dir: String) async throws -> [ShareFile] {
        let data = try await request(path: "folders", method: "GET", body: nil, query: [URLQueryItem(name: "dir", value: dir)])
        return parseFiles(data).filter(\.isDirectory)
    }

    func createFolder(name: String, parent: String) async throws -> String {
        let data = try await request(path: "folder", method: "POST", body: try jsonData(["name": name, "parent": parent]))
        let object = try jsonObject(data)
        return string(object, keys: ["id", "folder_id", "file_id"]) ?? parent + "/" + name
    }

    func saveToMyDrive(shareFiles: [ShareFile], targetFolder: String) async throws {
        let ids = shareFiles.map(\.id)
        _ = try await request(path: "save", method: "POST", body: try jsonData(["file_ids": ids, "target_folder": targetFolder, "permanent": true]))
    }

    func createShare(fileIds: [String], permanent: Bool) async throws -> ShareInfo {
        guard permanent else { throw NetdiskAdapterError.permanentUnsupported("云转只允许创建永久分享") }
        let data = try await request(path: "share", method: "POST", body: try jsonData(["file_ids": fileIds, "period": "permanent", "permanent": true]))
        let object = try jsonObject(data)
        if let unsupported = string(object, keys: ["error_msg", "message", "error"])?.lowercased(), unsupported.contains("expire") || unsupported.contains("permanent") {
            throw NetdiskAdapterError.permanentUnsupported(unsupported)
        }
        guard let url = string(object, keys: ["url", "share_url", "shareUrl"]) else { throw NetdiskAdapterError.invalidResponse }
        return ShareInfo(url: url, password: string(object, keys: ["pwd", "password", "access_code"]), token: string(object, keys: ["token", "share_id"]), shareID: string(object, keys: ["share_id", "shareId"]))
    }

    func request(path: String, method: String, body: Data?, query: [URLQueryItem] = []) async throws -> Data {
        guard let pathValue = endpoint.paths[path], let url = URL(string: pathValue, relativeTo: endpoint.baseURL)?.absoluteURL else { throw NetdiskAdapterError.invalidResponse }
        var headers = ["User-Agent": endpoint.userAgent, "Referer": endpoint.referer, "Accept": "application/json"]
        if body != nil { headers["Content-Type"] = "application/json" }
        if let cookie = credentialStore.loadCookie(platform: platform) { headers["Cookie"] = cookie }
        let request = HTTPRequest(method: method, url: url, headers: headers, query: query, body: body)
        do {
            let (data, _) = try await client.data(for: request, platform: platform)
            return data
        } catch HTTPClientError.status(let code, _) where code == 401 || code == 403 {
            throw NetdiskAdapterError.unauthorized
        } catch {
            throw NetdiskAdapterError.requestFailed(error.localizedDescription)
        }
    }

    private func jsonData(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: []) }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NetdiskAdapterError.invalidResponse }
        if let code = object["code"] as? Int, [401, 403, 419].contains(code) { throw NetdiskAdapterError.unauthorized }
        if let message = object["message"] as? String, message.localizedCaseInsensitiveContains("captcha") { throw NetdiskAdapterError.captchaRequired }
        return object
    }

    private func parseFiles(_ data: Data) -> [ShareFile] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let values = (object["data"] as? [[String: Any]]) ?? (object["list"] as? [[String: Any]]) ?? []
        return values.compactMap { item in
            guard let id = item["id"] as? String ?? item["fs_id"] as? String ?? (item["id"] as? NSNumber)?.stringValue else { return nil }
            let name = item["name"] as? String ?? "未命名文件"
            let isDirectory = (item["isdir"] as? Bool) ?? (item["is_dir"] as? Bool) ?? ((item["type"] as? String) == "folder")
            return ShareFile(id: id, name: name, isDirectory: isDirectory, token: item["share_fid_token"] as? String ?? item["fid_token"] as? String)
        }
    }

    private func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty { return value }
            if let value = object[key] as? NSNumber { return value.stringValue }
        }
        if let data = object["data"] as? [String: Any] { return string(data, keys: keys) }
        return nil
    }

    private func number(_ object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? Double { return value }
            if let value = object[key] as? NSNumber { return value.doubleValue }
        }
        if let data = object["data"] as? [String: Any] { return number(data, keys: keys) }
        return nil
    }

    private func formatBytes(_ used: Double, total: Double) -> String { "\(Int(used / 1_000_000_000))G / \(Int(total / 1_000_000_000))G" }
}

final class QuarkNetdiskAdapter: RESTNetdiskAdapter { init() { super.init(platform: .quark, endpoint: Endpoints.quark) } }
final class UCNetdiskAdapter: RESTNetdiskAdapter { init() { super.init(platform: .uc, endpoint: Endpoints.uc) } }
final class XunleiNetdiskAdapter: RESTNetdiskAdapter { init() { super.init(platform: .xunlei, endpoint: Endpoints.xunlei) } }
final class BaiduNetdiskAdapter: RESTNetdiskAdapter { init() { super.init(platform: .baidu, endpoint: Endpoints.baidu) } }
final class GuangyaNetdiskAdapter: RESTNetdiskAdapter { init() { super.init(platform: .guangya, endpoint: Endpoints.guangya) } }

enum NetdiskAdapterFactory {
    static func make(_ platform: NetdiskPlatform) -> NetdiskAdapter {
        switch platform {
        case .quark: return RealQuarkNetdiskAdapter()
        case .uc: return UCNetdiskAdapter()
        case .xunlei: return XunleiNetdiskAdapter()
        case .baidu: return BaiduNetdiskAdapter()
        case .guangya: return GuangyaNetdiskAdapter()
        }
    }
}
