import Foundation

struct EndpointConfig {
    let baseURL: URL
    let referer: String
    let userAgent: String
    let paths: [String: String]
}

enum Endpoints {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1"

    static let quark = EndpointConfig(baseURL: URL(string: "https://drive.quark.cn")!, referer: "https://pan.quark.cn/", userAgent: userAgent, paths: [
        "session": "/1/clouddrive/account/info",
        "parse": "/1/clouddrive/share/sharepage/token",
        "files": "/1/clouddrive/share/sharepage/detail",
        "folders": "/1/clouddrive/file/sort",
        "save": "/1/clouddrive/share/sharepage/save",
        "folder": "/1/clouddrive/file",
        "share": "/1/clouddrive/share"
    ])
    static let uc = EndpointConfig(baseURL: URL(string: "https://drive.uc.cn")!, referer: "https://drive.uc.cn/", userAgent: userAgent, paths: [
        "session": "/1/clouddrive/account/info",
        "parse": "/1/clouddrive/share/sharepage/token",
        "files": "/1/clouddrive/share/sharepage/detail",
        "folders": "/1/clouddrive/file/sort",
        "save": "/1/clouddrive/share/sharepage/save",
        "folder": "/1/clouddrive/file",
        "share": "/1/clouddrive/share"
    ])
    static let xunlei = EndpointConfig(baseURL: URL(string: "https://pan.xunlei.com")!, referer: "https://pan.xunlei.com/", userAgent: userAgent, paths: [
        "session": "/api/user/info",
        "parse": "/api/share/detail",
        "files": "/api/share/files",
        "folders": "/api/drive/folders",
        "save": "/api/share/save",
        "folder": "/api/drive/folder",
        "share": "/api/share/create"
    ])
    static let baidu = EndpointConfig(baseURL: URL(string: "https://pan.baidu.com")!, referer: "https://pan.baidu.com/", userAgent: userAgent, paths: [
        "session": "/api/user/getinfo",
        "parse": "/share/wxlist",
        "files": "/share/list",
        "folders": "/api/list",
        "save": "/share/transfer",
        "folder": "/api/create",
        "share": "/share/set"
    ])
    static let guangya = EndpointConfig(baseURL: URL(string: "https://guangyapan.com")!, referer: "https://guangyapan.com/", userAgent: userAgent, paths: [
        "session": "/api/user/info",
        "parse": "/api/share/detail",
        "files": "/api/share/files",
        "folders": "/api/drive/folders",
        "save": "/api/share/save",
        "folder": "/api/drive/folder",
        "share": "/api/share/create"
    ])

    static func config(for platform: NetdiskPlatform) -> EndpointConfig {
        switch platform {
        case .quark: return quark
        case .uc: return uc
        case .xunlei: return xunlei
        case .baidu: return baidu
        case .guangya: return guangya
        }
    }
}
