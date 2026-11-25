import Foundation

struct AppSettings: Codable {
    var selectedModelID: String?
    var baseURL: String
    var rewriteStyle: RewriteStyle
    var intensity: String
    var channel: String
    var customRequirements: String
    var temperature: Double?
    var concurrency: Int
    var directories: [NetdiskPlatform: String]

    static let defaultValue = AppSettings(selectedModelID: nil, baseURL: "https://api.my-relay.com/v1", rewriteStyle: .recommendation, intensity: "中改", channel: "通用", customRequirements: "", temperature: nil, concurrency: 2, directories: Dictionary(uniqueKeysWithValues: NetdiskPlatform.allCases.map { ($0, "/拉新资源/2026-11") }))
}

protocol AppStorageProtocol {
    func loadSelectedModel() -> String?
    func saveSelectedModel(_ modelID: String)
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
    func loadHistory() -> [HistoryRecord]
    func appendHistory(_ record: HistoryRecord)
}

class JSONAppStorage: AppStorageProtocol {
    private let directory: URL
    private let settingsURL: URL
    private let historyURL: URL
    private let lock = NSLock()

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PanRelay", isDirectory: true)
        settingsURL = directory.appendingPathComponent("settings.json")
        historyURL = directory.appendingPathComponent("history.json")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadSelectedModel() -> String? { loadSettings().selectedModelID }

    func saveSelectedModel(_ modelID: String) {
        var settings = loadSettings()
        settings.selectedModelID = modelID
        saveSettings(settings)
    }

    func loadSettings() -> AppSettings {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: settingsURL), let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return .defaultValue }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(settings) else { return }
        let temporary = settingsURL.appendingPathExtension("tmp")
        try? data.write(to: temporary, options: .atomic)
        try? FileManager.default.replaceItemAt(settingsURL, withItemAt: temporary)
    }

    func loadHistory() -> [HistoryRecord] {
        guard let data = try? Data(contentsOf: historyURL), let records = try? JSONDecoder().decode([HistoryRecord].self, from: data) else { return [] }
        return records
    }

    func appendHistory(_ record: HistoryRecord) {
        var records = loadHistory()
        records.insert(record, at: 0)
        if records.count > 200 { records = Array(records.prefix(200)) }
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}

final class MockAppStorage: JSONAppStorage {}

@available(iOS 17.0, *)
final class SwiftDataAppStorage: AppStorageProtocol {
    private let fallback = JSONAppStorage()
    func loadSelectedModel() -> String? { fallback.loadSelectedModel() }
    func saveSelectedModel(_ modelID: String) { fallback.saveSelectedModel(modelID) }
    func loadSettings() -> AppSettings { fallback.loadSettings() }
    func saveSettings(_ settings: AppSettings) { fallback.saveSettings(settings) }
    func loadHistory() -> [HistoryRecord] { fallback.loadHistory() }
    func appendHistory(_ record: HistoryRecord) { fallback.appendHistory(record) }
}

enum AppStorageFactory {
    static func make() -> AppStorageProtocol {
        if #available(iOS 17.0, *) { return SwiftDataAppStorage() }
        return JSONAppStorage()
    }
}
