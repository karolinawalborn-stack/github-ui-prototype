import Foundation

enum RelayJobState: String, Codable {
    case queued
    case running
    case paused
    case completed
    case failed
    case cancelled
}

struct RelayJob: Identifiable, Codable {
    let id: UUID
    let sourceText: String
    var state: RelayJobState
    var matches: [LinkMatch]
    var replacements: [LinkReplacement]
    var errorMessage: String?
    var createdAt: Date

    init(id: UUID = UUID(), sourceText: String, state: RelayJobState = .queued, matches: [LinkMatch] = [], replacements: [LinkReplacement] = [], errorMessage: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.sourceText = sourceText
        self.state = state
        self.matches = matches
        self.replacements = replacements
        self.errorMessage = errorMessage
        self.createdAt = createdAt
    }
}
