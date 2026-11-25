import Foundation

struct LinkParser {
    func parse(_ text: String) -> [LinkMatch] {
        var candidates: [LinkMatch] = []
        for pattern in LinkPatterns.all {
            guard let regex = try? NSRegularExpression(pattern: pattern.expression) else { continue }
            let range = NSRange(location: 0, length: (text as NSString).length)
            for match in regex.matches(in: text, range: range) {
                let rawURL = (text as NSString).substring(with: match.range)
                let normalizedURL = rawURL.hasPrefix("http") ? rawURL : "https://\(rawURL)"
                let queryPassword = passwordFromQuery(normalizedURL)
                let nearby = nearbyPasswordInText(text, after: match.range)
                let password = queryPassword ?? nearby?.value
                let passwordRange = nearby?.range
                let fullRange = passwordRange.map { NSRange(location: match.range.location, length: NSMaxRange($0) - match.range.location) } ?? match.range
                candidates.append(LinkMatch(platform: pattern.platform, url: normalizedURL, password: password, urlRange: match.range, fullRange: fullRange, passwordRange: passwordRange))
            }
        }
        return deduplicated(candidates).sorted { $0.urlRange.location < $1.urlRange.location }
    }

    func replace(in text: String, replacements: [LinkReplacement]) -> RewrittenSource {
        let sorted = replacements.sorted { $0.match.fullRange.location > $1.match.fullRange.location }
        var output = text
        for replacement in sorted {
            guard let swiftRange = Range(replacement.match.fullRange, in: output) else { continue }
            output.replaceSubrange(swiftRange, with: replacement.replacementText)
        }
        return RewrittenSource(text: output, replacements: replacements)
    }

    private func passwordFromQuery(_ url: String) -> String? {
        let ns = url as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = LinkPatterns.queryPassword.firstMatch(in: url, range: range), match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private func nearbyPasswordInText(_ text: String, after matchRange: NSRange) -> (value: String, range: NSRange)? {
        let ns = text as NSString
        let start = matchRange.location
        let end = min(ns.length, NSMaxRange(matchRange) + 80)
        guard end > start else { return nil }
        let nearbyRange = NSRange(location: start, length: end - start)
        guard let match = LinkPatterns.nearbyPassword.firstMatch(in: text, range: nearbyRange), match.numberOfRanges > 1 else { return nil }
        let value = ns.substring(with: match.range(at: 1))
        return (value, match.range(at: 1))
    }

    private func deduplicated(_ values: [LinkMatch]) -> [LinkMatch] {
        var seen = Set<String>()
        return values.filter { value in
            let key = "\(value.urlRange.location):\(value.url)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}
