import Foundation

final class RealQuarkNetdiskAdapter: RESTNetdiskAdapter {
    private var lastPwdID: String?
    private var lastStoken: String?

    init(client: HTTPClient = .shared, credentialStore: CredentialStore = .shared) {
        super.init(platform: .quark, endpoint: Endpoints.quark, client: client, credentialStore: credentialStore)
    }

    override func parseShare(url: URL, password: String?) async throws -> ShareInfo {
        guard let pwdID = url.pathComponents.last, !pwdID.isEmpty else { throw NetdiskAdapterError.invalidResponse }
        let body = try JSONSerialization.data(withJSONObject: ["pwd_id": pwdID, "passcode": password ?? ""])
        let data = try await quarkRequest(path: "/1/clouddrive/share/sharepage/token", method: "POST", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc")], body: body)
        let object = try object(data)
        let nested = (object["data"] as? [String: Any]) ?? object
        guard let stoken = string(nested, keys: ["stoken", "share_token"]), let shareID = string(nested, keys: ["share_id", "shareId"]) else { throw NetdiskAdapterError.invalidResponse }
        lastPwdID = pwdID
        lastStoken = stoken
        return ShareInfo(url: url.absoluteString, password: password, token: stoken, shareID: shareID)
    }

    override func listShareFiles(dir: String) async throws -> [ShareFile] {
        guard let pwdID = lastPwdID, let stoken = lastStoken else { throw NetdiskAdapterError.invalidResponse }
        let data = try await quarkRequest(path: "/1/clouddrive/share/sharepage/detail", method: "GET", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc"), URLQueryItem(name: "pwd_id", value: pwdID), URLQueryItem(name: "stoken", value: stoken), URLQueryItem(name: "pdir_fid", value: "0"), URLQueryItem(name: "_page", value: "1"), URLQueryItem(name: "_size", value: "100")], body: nil)
        let object = try object(data)
        let dataObject = (object["data"] as? [String: Any]) ?? object
        let values = (dataObject["list"] as? [[String: Any]]) ?? []
        return values.compactMap { item in
            guard let fid = string(item, keys: ["fid", "file_id"]) else { return nil }
            return ShareFile(id: fid, name: string(item, keys: ["file_name", "name"]) ?? "未命名文件", isDirectory: (item["dir"] as? Bool) ?? ((item["file_type"] as? Int) == 0), token: string(item, keys: ["share_fid_token", "fid_token"]))
        }
    }

    override func listMyFolders(dir: String) async throws -> [ShareFile] {
        let data = try await quarkRequest(path: "/1/clouddrive/file/sort", method: "GET", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc"), URLQueryItem(name: "pdir_fid", value: dir), URLQueryItem(name: "_page", value: "1"), URLQueryItem(name: "_size", value: "100")], body: nil)
        let object = try object(data)
        let dataObject = (object["data"] as? [String: Any]) ?? object
        let values = (dataObject["list"] as? [[String: Any]]) ?? []
        return values.compactMap { item in
            guard let fid = string(item, keys: ["fid", "file_id"]) else { return nil }
            return ShareFile(id: fid, name: string(item, keys: ["file_name", "name"]) ?? "", isDirectory: true, token: nil)
        }
    }

    override func createFolder(name: String, parent: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["pdir_fid": parent, "file_name": name, "dir": 1])
        let data = try await quarkRequest(path: "/1/clouddrive/file", method: "POST", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc")], body: body)
        let object = try object(data)
        guard let fid = string((object["data"] as? [String: Any]) ?? object, keys: ["fid", "file_id"]) else { throw NetdiskAdapterError.invalidResponse }
        return fid
    }

    override func saveToMyDrive(shareFiles: [ShareFile], targetFolder: String) async throws {
        guard let pwdID = lastPwdID, let stoken = lastStoken else { throw NetdiskAdapterError.invalidResponse }
        let body: [String: Any] = ["fid_list": shareFiles.map(\.id), "fid_token_list": shareFiles.compactMap(\.token), "to_pdir_fid": targetFolder, "pwd_id": pwdID, "stoken": stoken]
        let data = try await quarkRequest(path: "/1/clouddrive/share/sharepage/save", method: "POST", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc")], body: try JSONSerialization.data(withJSONObject: body))
        let object = try object(data)
        if let taskID = string((object["data"] as? [String: Any]) ?? object, keys: ["task_id", "taskId"]) { try await waitForTask(taskID) }
    }

    override func createShare(fileIds: [String], permanent: Bool) async throws -> ShareInfo {
        guard permanent else { throw NetdiskAdapterError.permanentUnsupported("夸克只允许创建永久分享") }
        let body: [String: Any] = ["fid_list": fileIds, "title": "云转分享", "url_type": 1, "expired_type": 1]
        let data = try await quarkRequest(path: "/1/clouddrive/share", method: "POST", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc")], body: try JSONSerialization.data(withJSONObject: body))
        let object = try object(data)
        let nested = (object["data"] as? [String: Any]) ?? object
        if let expired = nested["expired_type"] as? Int, expired != 1 { throw NetdiskAdapterError.permanentUnsupported("该账号不支持永久分享") }
        guard let url = string(nested, keys: ["share_url", "url"]) else { throw NetdiskAdapterError.invalidResponse }
        return ShareInfo(url: url, password: string(nested, keys: ["passcode", "pwd", "password"]), token: string(nested, keys: ["stoken", "token"]), shareID: string(nested, keys: ["share_id", "shareId"]))
    }

    private func waitForTask(_ taskID: String) async throws {
        for _ in 0..<40 {
            let data = try await quarkRequest(path: "/1/clouddrive/task", method: "GET", query: [URLQueryItem(name: "pr", value: "ucpro"), URLQueryItem(name: "fr", value: "pc"), URLQueryItem(name: "task_id", value: taskID), URLQueryItem(name: "retry_index", value: "0")], body: nil)
            let object = try object(data)
            let nested = (object["data"] as? [String: Any]) ?? object
            let status = string(nested, keys: ["status", "task_status"])
            if status == "2" || status == "success" || status == "completed" { return }
            if status == "3" || status == "failed" { throw NetdiskAdapterError.requestFailed(string(nested, keys: ["message", "error_msg"]) ?? "夸克任务失败") }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        throw NetdiskAdapterError.requestFailed("夸克任务轮询超时")
    }

    private func quarkRequest(path: String, method: String, query: [URLQueryItem], body: Data?) async throws -> Data {
        guard let url = URL(string: path, relativeTo: endpoint.baseURL)?.absoluteURL else { throw NetdiskAdapterError.invalidResponse }
        var headers = ["User-Agent": endpoint.userAgent, "Referer": endpoint.referer, "Accept": "application/json"]
        if body != nil { headers["Content-Type"] = "application/json" }
        if let cookie = credentialStore.loadCookie(platform: .quark) { headers["Cookie"] = cookie }
        do { return try await client.data(for: HTTPRequest(method: method, url: url, headers: headers, query: query, body: body), platform: .quark).0 }
        catch HTTPClientError.status(let code, _) where code == 401 || code == 403 { throw NetdiskAdapterError.unauthorized }
    }

    private func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NetdiskAdapterError.invalidResponse }
        if let code = value["code"] as? Int, code != 0 && code != 200 { throw NetdiskAdapterError.requestFailed(string(value, keys: ["message", "error_msg"]) ?? "夸克接口返回错误") }
        return value
    }

    private func string(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys { if let value = object[key] as? String, !value.isEmpty { return value }; if let value = object[key] as? NSNumber { return value.stringValue } }
        return nil
    }
}
