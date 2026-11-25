import Foundation

enum LinkPatterns {
    struct Pattern {
        let platform: NetdiskPlatform
        let expression: String
    }

    static let all: [Pattern] = [
        Pattern(platform: .quark, expression: #"(?:https?://)?pan\.quark\.cn/s/[A-Za-z0-9_-]+(?:\?[^\s]+)?"#),
        Pattern(platform: .uc, expression: #"(?:https?://)?drive\.uc\.cn/s/[A-Za-z0-9_-]+(?:\?[^\s]+)?"#),
        Pattern(platform: .xunlei, expression: #"(?:https?://)?pan\.xunlei\.com/s/[A-Za-z0-9_-]+(?:\?[^\s]+)?"#),
        Pattern(platform: .baidu, expression: #"(?:https?://)?pan\.baidu\.com/(?:s/[A-Za-z0-9_-]+|share/init\?surl=[A-Za-z0-9_-]+)(?:\?[^\s]+)?"#),
        Pattern(platform: .guangya, expression: #"(?:https?://)?(?:www\.)?guangyapan\.com/[^\s]+"#)
    ]

    static let nearbyPassword = try! NSRegularExpression(pattern: #"(?i)(?:提取码|密码|访问码|pwd|code)\s*[:：=]?\s*([A-Za-z0-9]{4,16})"#)
    static let queryPassword = try! NSRegularExpression(pattern: #"(?i)(?:[?&]pwd=)([A-Za-z0-9]{4,16})"#)
}
