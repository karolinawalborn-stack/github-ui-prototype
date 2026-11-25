import Foundation

struct DiagnosticEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let method: String
    let url: String
    let parameters: String
    let statusCode: Int?
    let responsePrefix: String
    let error: String?
}

final class DiagnosticLogger: ObservableObject {
    static let shared = DiagnosticLogger()
    @Published private(set) var entries: [NetdiskPlatform: [DiagnosticEntry]] = [:]
    private let queue = DispatchQueue(label: "panrelay.diagnostics")

    func record(platform: NetdiskPlatform, method: String, url: String, parameters: Any?, statusCode: Int?, body: String?, error: Error?) {
        let parameterText = redact(String(describing: parameters ?? ""))
        let bodyText = String(redact(body ?? "").prefix(2000))
        let entry = DiagnosticEntry(id: UUID(), date: Date(), method: method, url: redact(url), parameters: parameterText, statusCode: statusCode, responsePrefix: bodyText, error: error.map { redact(String(describing: $0)) })
        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.entries[platform, default: []].insert(entry, at: 0)
                self?.entries[platform] = Array(self?.entries[platform, default: []].prefix(50) ?? [])
            }
        }
    }

    func latestText(for platform: NetdiskPlatform) -> String? {
        guard let entry = entries[platform]?.first else { return nil }
        let status = entry.statusCode.map(String.init) ?? "-"
        return "[\(entry.date)] \(entry.method) \(entry.url)\nparams: \(entry.parameters)\nstatus: \(status)\nbody: \(entry.responsePrefix)\nerror: \(entry.error ?? "-")"
    }

    private func redact(_ value: String) -> String {
        var result = value
        let patterns = [
            #"(?i)(cookie|authorization|token|bdstoken|captcha_token|api[-_]?key|sign|phone|mobile)\s*[:=]\s*[^,\s;]+"#,
            #"(?i)(sk-[A-Za-z0-9_-]{8,})"#,
            #"(?i)(pwd|password|提取码)\s*[:=：]\s*[^,\s;]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "$1=[REDACTED]")
            }
        }
        return result
    }
}
