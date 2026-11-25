import Foundation

actor PlatformThrottle {
    private var lastRequest: [NetdiskPlatform: Date] = [:]

    func wait(for platform: NetdiskPlatform, interval: TimeInterval) async {
        if let last = lastRequest[platform] {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < interval {
                let delay = UInt64((interval - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        lastRequest[platform] = Date()
    }
}

@MainActor
final class TransferQueue: ObservableObject {
    @Published private(set) var jobs: [RelayJob] = []
    @Published private(set) var isPaused = false
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private let parser = LinkParser()
    private let storage: AppStorageProtocol
    private let throttle = PlatformThrottle()
    private var worker: Task<Void, Never>?
    private var cancelRequested = false
    private var concurrency = 2
    private let snapshotURL: URL

    init(storage: AppStorageProtocol = AppStorageFactory.make()) {
        self.storage = storage
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("PanRelay", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        snapshotURL = directory.appendingPathComponent("queue.json")
        if let data = try? Data(contentsOf: snapshotURL), let saved = try? JSONDecoder().decode([RelayJob].self, from: data) { jobs = saved }
    }

    func enqueue(_ sourceText: String) {
        jobs.append(RelayJob(sourceText: sourceText))
        persist()
    }

    func start(concurrency: Int = 2) {
        guard !isRunning else { return }
        self.concurrency = max(1, min(5, concurrency))
        cancelRequested = false
        isPaused = false
        isRunning = true
        worker = Task { [weak self] in await self?.runLoop() }
    }

    func pause() { isPaused = true; updateActiveState(.paused); persist() }
    func resume() { isPaused = false; updateActiveState(.running); if !isRunning { start(concurrency: concurrency) } }
    func cancel() { cancelRequested = true; isPaused = false; worker?.cancel(); updateActiveState(.cancelled); isRunning = false; persist() }

    private func runLoop() async {
        for index in jobs.indices where jobs[index].state == .queued || jobs[index].state == .paused {
            if cancelRequested { break }
            while isPaused && !cancelRequested { try? await Task.sleep(nanoseconds: 150_000_000) }
            if cancelRequested { break }
            jobs[index].state = .running
            let matches = parser.parse(jobs[index].sourceText)
            jobs[index].matches = matches
            do {
                let replacements = try await process(matches: matches)
                jobs[index].replacements = replacements
                jobs[index].state = .completed
                jobs[index].errorMessage = nil
                if !replacements.isEmpty {
                    let rewritten = parser.replace(in: jobs[index].sourceText, replacements: replacements)
                    let record = HistoryRecord(id: UUID(), originalText: jobs[index].sourceText, rewrittenText: rewritten.text, links: replacements.map { TransferLink(platform: $0.match.platform, originalURL: $0.match.url, password: $0.match.password, newURL: $0.newURL, newPassword: $0.newPassword, stages: Array(repeating: .completed, count: TransferStage.allCases.count)) }, createdAt: Date())
                    storage.appendHistory(record)
                }
            } catch {
                jobs[index].state = .failed
                jobs[index].errorMessage = error.localizedDescription
                lastError = error.localizedDescription
            }
            persist()
        }
        isRunning = false
    }

    private func process(matches: [LinkMatch]) async throws -> [LinkReplacement] {
        guard !matches.isEmpty else { return [] }
        var results: [LinkReplacement] = []
        for batch in matches.chunked(into: concurrency) {
            if cancelRequested { throw CancellationError() }
            while isPaused && !cancelRequested { try? await Task.sleep(nanoseconds: 150_000_000) }
            let batchResults = await withTaskGroup(of: Result<LinkReplacement, Error>.self, returning: [Result<LinkReplacement, Error>].self) { group in
                for match in batch {
                    group.addTask { await self.process(match: match) }
                }
                var values: [Result<LinkReplacement, Error>] = []
                for await value in group { values.append(value) }
                return values
            }
            for result in batchResults { results.append(try result.get()) }
        }
        return results.sorted { $0.match.urlRange.location < $1.match.urlRange.location }
    }

    private func process(match: LinkMatch) async -> Result<LinkReplacement, Error> {
        let adapter = NetdiskAdapterFactory.make(match.platform)
        do {
            for attempt in 0...2 {
                do {
                    await throttle.wait(for: match.platform, interval: 1.5)
                    guard try await adapter.validateSession() else { throw NetdiskAdapterError.unauthorized }
                    guard let url = URL(string: match.url) else { throw NetdiskAdapterError.invalidResponse }
                    let share = try await adapter.parseShare(url: url, password: match.password)
                    let files = try await adapter.listShareFiles(dir: share.token ?? "/")
                    let folder = try await resolveTargetFolder(adapter: adapter, platform: match.platform)
                    try await adapter.saveToMyDrive(shareFiles: files, targetFolder: folder)
                    let output = try await adapter.createShare(fileIds: files.map(\.id), permanent: true)
                    return .success(LinkReplacement(match: match, newURL: output.url, newPassword: output.password))
                } catch {
                    if attempt == 2 || Self.isTerminal(error) { return .failure(error) }
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 500_000_000))
                }
            }
            return .failure(NetdiskAdapterError.requestFailed("重试次数已用尽"))
        } catch {
            return .failure(error)
        }
    }

    private func updateActiveState(_ state: RelayJobState) {
        for index in jobs.indices where jobs[index].state == .running || jobs[index].state == .paused { jobs[index].state = state }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(jobs) { try? data.write(to: snapshotURL, options: .atomic) }
    }

    private static func dateFolder() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func resolveTargetFolder(adapter: NetdiskAdapter, platform: NetdiskPlatform) async throws -> String {
        let configured = storage.loadSettings().directories[platform] ?? "/云转"
        let components = configured.split(separator: "/").map(String.init) + [Self.dateFolder()]
        var parent = "0"
        for component in components where !component.isEmpty {
            let folders = try await adapter.listMyFolders(dir: parent)
            if let existing = folders.first(where: { $0.name == component }) {
                parent = existing.id
            } else {
                parent = try await adapter.createFolder(name: component, parent: parent)
            }
        }
        return parent
    }

    private static func isTerminal(_ error: Error) -> Bool {
        guard let adapterError = error as? NetdiskAdapterError else { return false }
        switch adapterError {
        case .unauthorized, .captchaRequired, .permanentUnsupported: return true
        case .invalidResponse, .requestFailed: return false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}
