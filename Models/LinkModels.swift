import Foundation

struct LinkMatch: Identifiable, Equatable, Codable {
    let id: UUID
    let platform: NetdiskPlatform
    let url: String
    let password: String?
    let urlRange: NSRange
    let fullRange: NSRange
    let passwordRange: NSRange?

    init(id: UUID = UUID(), platform: NetdiskPlatform, url: String, password: String?, urlRange: NSRange, fullRange: NSRange, passwordRange: NSRange? = nil) {
        self.id = id
        self.platform = platform
        self.url = url
        self.password = password
        self.urlRange = urlRange
        self.fullRange = fullRange
        self.passwordRange = passwordRange
    }
}

struct LinkReplacement: Codable {
    let match: LinkMatch
    let newURL: String
    let newPassword: String?

    var replacementText: String {
        if let newPassword, !newURL.contains("pwd=") {
            return "\(newURL) 提取码: \(newPassword)"
        }
        return newURL
    }
}

struct RewrittenSource {
    let text: String
    let replacements: [LinkReplacement]
}
