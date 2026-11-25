import Foundation

struct TemplateValidation: Codable {
    let stripPrefixes: [String]
    let forbiddenRegex: [String]
    let bannedPhrases: [String]
    let maxCharacters: Int
    let softCharacterRatio: Double
    let hardCharacterRatio: Double
    let emojiMin: Int
    let emojiMax: Int

    enum CodingKeys: String, CodingKey {
        case stripPrefixes = "strip_prefixes"
        case forbiddenRegex = "forbidden_regex"
        case bannedPhrases = "banned_phrases"
        case maxCharacters = "max_characters"
        case softCharacterRatio = "soft_character_ratio"
        case hardCharacterRatio = "hard_character_ratio"
        case emojiMin = "emoji_min"
        case emojiMax = "emoji_max"
    }
}

struct RewriteTemplate: Codable {
    let defaultTemperature: Double
    let system: [String]
    let user: [String]
    let retry: [String]
    let validation: TemplateValidation

    enum CodingKeys: String, CodingKey {
        case defaultTemperature = "default_temperature"
        case system
        case user
        case retry
        case validation
    }
}

struct RewriteTemplateFile: Codable {
    let styles: [String: RewriteTemplate]
}

final class PromptTemplateStore {
    static let shared = PromptTemplateStore()
    private var file: RewriteTemplateFile?

    func template(for style: String) throws -> RewriteTemplate {
        if file == nil {
            guard let url = Bundle.main.url(forResource: "rewrite_templates", withExtension: "json", subdirectory: "Prompts") else { throw AIServiceError.templateMissing }
            file = try JSONDecoder().decode(RewriteTemplateFile.self, from: Data(contentsOf: url))
        }
        guard let template = file?.styles[style] ?? file?.styles["种草"] else { throw AIServiceError.templateMissing }
        return template
    }
}

struct PlaceholderDocument {
    let source: String
    let mappings: [String: String]

    func restore(_ text: String) -> String {
        mappings.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }
}

enum ValidationSeverity { case soft, hard }

struct ValidationIssue {
    let message: String
    let severity: ValidationSeverity
}

struct ValidationResult {
    let cleanedText: String
    let issues: [ValidationIssue]
    var isValid: Bool { !issues.contains { $0.severity == .hard } }
}

enum AIServiceError: LocalizedError {
    case templateMissing
    case invalidBaseURL
    case invalidResponse
    case validationFailed([String])

    var errorDescription: String? {
        switch self {
        case .templateMissing: return "缺少二创模板资源"
        case .invalidBaseURL: return "中转站 Base URL 无效"
        case .invalidResponse: return "模型响应格式无法识别"
        case .validationFailed(let errors): return errors.joined(separator: "、")
        }
    }
}

final class RewriteTemplateEngine {
    private let store: PromptTemplateStore
    init(store: PromptTemplateStore = .shared) { self.store = store }

    func build(style: String, intensity: String, channel: String, customRequirements: String, changedSource: String, placeholders: PlaceholderDocument) throws -> (system: String, user: String, retry: RewriteTemplate, temperature: Double) {
        let template = try store.template(for: style)
        let values = ["style": style, "intensity": intensity, "channel": channel, "custom_requirements": customRequirements, "source": placeholders.source]
        return (render(template.system, values), render(template.user, values), template, template.defaultTemperature)
    }

    func retryPrompt(template: RewriteTemplate, source: String, errors: [String]) -> String {
        render(template.retry, ["errors": errors.joined(separator: "；"), "source": source])
    }

    func placeholders(for changedSource: String, replacements: [LinkReplacement]) -> PlaceholderDocument {
        var source = changedSource
        var mappings: [String: String] = [:]
        for (index, replacement) in replacements.enumerated() {
            let token = "[[LINK_\(index + 1)]]"
            let value = replacement.replacementText
            if source.contains(value) {
                source = source.replacingOccurrences(of: value, with: token, options: [], range: source.range(of: value))
                mappings[token] = value
            }
        }
        return PlaceholderDocument(source: source, mappings: mappings)
    }

    func validate(_ text: String, template: RewriteTemplate, placeholders: PlaceholderDocument, sourceCharacterCount: Int) -> ValidationResult {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in template.validation.stripPrefixes where cleaned.hasPrefix(prefix) { cleaned.removeFirst(prefix.count) }
        var issues: [ValidationIssue] = []
        for (token, _) in placeholders.mappings {
            let count = cleaned.components(separatedBy: token).count - 1
            if count != 1 { issues.append(ValidationIssue(message: "\(token) 出现 \(count) 次", severity: .hard)) }
        }
        if cleaned.contains("[[LINK_") {
            issues.append(ValidationIssue(message: "存在未定义的链接占位符", severity: .hard))
        }
        for pattern in template.validation.forbiddenRegex where (try? NSRegularExpression(pattern: pattern))?.firstMatch(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length)) != nil {
            issues.append(ValidationIssue(message: "命中禁止表达式", severity: .hard))
        }
        for phrase in template.validation.bannedPhrases where cleaned.localizedCaseInsensitiveContains(phrase) {
            issues.append(ValidationIssue(message: "命中禁用短语：\(phrase)", severity: .hard))
        }
        let count = normalizedCharacterCount(cleaned)
        let ratio = sourceCharacterCount == 0 ? 0 : Double(count) / Double(sourceCharacterCount)
        if count > Int(Double(template.validation.maxCharacters) * template.validation.hardCharacterRatio) { issues.append(ValidationIssue(message: "正文超出长度上限", severity: .hard)) }
        else if ratio > template.validation.softCharacterRatio { issues.append(ValidationIssue(message: "正文偏长", severity: .soft)) }
        let emojiCount = cleaned.unicodeScalars.filter { $0.properties.isEmoji && $0.value > 127 }.count
        if emojiCount < template.validation.emojiMin || emojiCount > template.validation.emojiMax { issues.append(ValidationIssue(message: "emoji 数量不在建议范围", severity: .soft)) }
        return ValidationResult(cleanedText: cleaned, issues: issues)
    }

    private func render(_ lines: [String], _ values: [String: String]) -> String {
        lines.map { line in values.reduce(line) { $0.replacingOccurrences(of: "{{\($1.key)}}", with: $1.value) } }.joined(separator: "\n")
    }

    private func normalizedCharacterCount(_ text: String) -> Int {
        text.unicodeScalars.filter { !$0.properties.isWhitespace && !$0.properties.isEmoji }.count
    }
}

protocol AIService {
    func rewrite(source: String, replacements: [LinkReplacement], style: String, intensity: String, channel: String, customRequirements: String, model: AIModel, baseURL: String, apiKey: String, temperature: Double?) -> AsyncThrowingStream<String, Error>
}

final class OpenAICompatibleService: AIService {
    private let engine: RewriteTemplateEngine

    init(engine: RewriteTemplateEngine = RewriteTemplateEngine()) { self.engine = engine }

    func fetchModels(baseURL: String, apiKey: String) async throws -> [AIModel] {
        guard let url = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/models") else { throw AIServiceError.invalidBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let values = object["data"] as? [[String: Any]] else { throw AIServiceError.invalidResponse }
        return values.compactMap { value in
            guard let id = value["id"] as? String else { return nil }
            return AIModel(id: id, provider: value["owned_by"] as? String ?? "")
        }
    }

    func rewrite(source: String, replacements: [LinkReplacement], style: String, intensity: String, channel: String, customRequirements: String, model: AIModel, baseURL: String, apiKey: String, temperature: Double?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let changed = LinkParser().replace(in: source, replacements: replacements)
                    let placeholders = engine.placeholders(for: changed.text, replacements: replacements)
                    let built = try engine.build(style: style, intensity: intensity, channel: channel, customRequirements: customRequirements, changedSource: changed.text, placeholders: placeholders)
                    let first = try await streamRequest(system: built.system, user: built.user, model: model, baseURL: baseURL, apiKey: apiKey, temperature: temperature ?? built.temperature)
                    var validation = engine.validate(first, template: built.retry, placeholders: placeholders, sourceCharacterCount: source.count)
                    if !validation.isValid {
                        let retry = engine.retryPrompt(template: built.retry, source: placeholders.source, errors: validation.issues.map(\.message))
                        let second = try await streamRequest(system: built.system, user: retry, model: model, baseURL: baseURL, apiKey: apiKey, temperature: temperature ?? built.temperature)
                        validation = engine.validate(second, template: built.retry, placeholders: placeholders, sourceCharacterCount: source.count)
                    }
                    guard validation.isValid else { throw AIServiceError.validationFailed(validation.issues.map(\.message)) }
                    let restored = placeholders.restore(validation.cleanedText)
                    for chunk in restored.map(String.init) { continuation.yield(chunk) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    private func streamRequest(system: String, user: String, model: AIModel, baseURL: String, apiKey: String, temperature: Double) async throws -> String {
        guard let base = URL(string: baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions") else { throw AIServiceError.invalidBaseURL }
        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = ["model": model.id, "messages": [["role": "system", "content": system], ["role": "user", "content": user]], "temperature": temperature, "stream": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw AIServiceError.invalidResponse }
        var result = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = object["choices"] as? [[String: Any]], let delta = choices.first?["delta"] as? [String: Any], let content = delta["content"] as? String else { continue }
            result.append(content)
        }
        return result
    }
}
