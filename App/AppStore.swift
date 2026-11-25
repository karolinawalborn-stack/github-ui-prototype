import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .transfer
    @Published var sourceText: String
    @Published var links: [TransferLink] = []
    @Published var isTransferring = false
    @Published var transferFinished = false
    @Published var transferError: String?
    @Published var rewriteStyle: RewriteStyle
    @Published var rewriteIntensity: String
    @Published var rewriteChannel: String
    @Published var customRequirements: String
    @Published var rewriteOutput = ""
    @Published var rewriteIsStreaming = false
    @Published var selectedModel: AIModel = AIModel.mockModels[0]
    @Published var availableModels: [AIModel] = []
    @Published var isDetectingModels = false
    @Published var baseURL: String
    @Published var apiKeyMasked = ""
    @Published var temperature: Double?
    @Published var concurrency: Int
    @Published var isHistoryPresented = false
    @Published var showShareSheet = false

    let accounts = NetdiskAccount.mockAccounts
    let aiService: OpenAICompatibleService
    let storage: AppStorageProtocol
    let queue: TransferQueue
    private let parser = LinkParser()
    private var rewriteTask: Task<Void, Never>?
    private var currentJobID: UUID?

    init(aiService: OpenAICompatibleService = OpenAICompatibleService(), storage: AppStorageProtocol = AppStorageFactory.make()) {
        self.aiService = aiService
        self.storage = storage
        let settings = storage.loadSettings()
        sourceText = "考研英语真题全套 2005-2026，带逐句精讲\n夸克 https://pan.quark.cn/s/8f2a1c9e7b41\n百度 https://pan.baidu.com/s/1Qx7Lm2pZk 提取码: 8k2d\n迅雷 https://pan.xunlei.com/s/VNs82kLq 提取码: t7wq"
        rewriteStyle = settings.rewriteStyle
        rewriteIntensity = settings.intensity
        rewriteChannel = settings.channel
        customRequirements = settings.customRequirements
        baseURL = settings.baseURL
        temperature = settings.temperature
        concurrency = settings.concurrency
        availableModels = []
        queue = TransferQueue(storage: storage)
        links = LinkParser().parse(sourceText).map { TransferLink(platform: $0.platform, originalURL: $0.url, password: $0.password) }
        if let saved = settings.selectedModelID, let model = AIModel.mockModels.first(where: { $0.id == saved }) { selectedModel = model }
        apiKeyMasked = maskedAPIKey
    }

    var fullMockRewrite: String {
        let replacements = links.compactMap { link -> LinkReplacement? in
            guard let newURL = link.newURL, let match = parser.parse(sourceText).first(where: { $0.url == link.originalURL }) else { return nil }
            return LinkReplacement(match: match, newURL: newURL, newPassword: link.newPassword)
        }
        let changed = parser.replace(in: sourceText, replacements: replacements)
        return changed.text
    }

    var maskedAPIKey: String {
        guard let value = CredentialStore.shared.loadAPIKey(), value.count > 8 else { return "sk-••••••••••••3f9a" }
        return String(value.prefix(3)) + "••••••••••••" + String(value.suffix(4))
    }

    func refreshLinksFromSource() {
        let parsed = parser.parse(sourceText)
        links = parsed.map { TransferLink(platform: $0.platform, originalURL: $0.url, password: $0.password) }
        transferFinished = false
        transferError = nil
        saveSettings()
    }

    func importClipboard() {
        if let value = UIPasteboard.general.string, !value.isEmpty {
            sourceText = value
            refreshLinksFromSource()
        }
    }

    func startTransfer(reduceMotion: Bool) {
        guard !isTransferring else { return }
        if transferFinished { selectedTab = .rewrite; return }
        refreshLinksFromSource()
        guard !links.isEmpty else { transferError = "没有识别到可转存链接"; return }
        isTransferring = true
        transferError = nil
        queue.enqueue(sourceText)
        currentJobID = queue.jobs.last?.id
        queue.start(concurrency: concurrency)
        Task { @MainActor in
            while isTransferring {
                try? await Task.sleep(nanoseconds: reduceMotion ? 100_000_000 : 350_000_000)
                guard let id = currentJobID, let job = queue.jobs.first(where: { $0.id == id }) else { continue }
                if job.state == .completed {
                    let replacements = job.replacements
                    for replacement in replacements {
                        if let index = links.firstIndex(where: { $0.originalURL == replacement.match.url }) {
                            links[index].newURL = replacement.newURL
                            links[index].newPassword = replacement.newPassword
                            links[index].stages = Array(repeating: .completed, count: TransferStage.allCases.count)
                        }
                    }
                    transferFinished = true
                    isTransferring = false
                } else if job.state == .failed || job.state == .cancelled {
                    transferError = job.errorMessage ?? "转存失败"
                    isTransferring = false
                }
            }
        }
    }

    func pauseTransfer() { queue.pause() }
    func resumeTransfer() { queue.resume() }
    func cancelTransfer() { queue.cancel(); isTransferring = false }

    func startRewriteIfNeeded(reduceMotion: Bool) {
        guard rewriteOutput.isEmpty, !rewriteIsStreaming else { return }
        generateRewrite(reduceMotion: reduceMotion)
    }

    func generateRewrite(reduceMotion: Bool) {
        rewriteTask?.cancel()
        rewriteOutput = ""
        rewriteIsStreaming = true
        let matches = parser.parse(sourceText)
        let replacements = links.compactMap { link -> LinkReplacement? in
            guard let match = matches.first(where: { $0.url == link.originalURL }), let newURL = link.newURL else { return nil }
            return LinkReplacement(match: match, newURL: newURL, newPassword: link.newPassword)
        }
        guard !replacements.isEmpty else {
            rewriteOutput = parser.replace(in: sourceText, replacements: []).text
            rewriteIsStreaming = false
            return
        }
        guard let apiKey = CredentialStore.shared.loadAPIKey(), !apiKey.isEmpty else {
            rewriteOutput = parser.replace(in: sourceText, replacements: replacements).text
            rewriteIsStreaming = false
            return
        }
        if reduceMotion {
            rewriteTask = Task { @MainActor in
                do {
                    for try await chunk in aiService.rewrite(source: sourceText, replacements: replacements, style: rewriteStyle.rawValue, intensity: rewriteIntensity, channel: rewriteChannel, customRequirements: customRequirements, model: selectedModel, baseURL: baseURL, apiKey: apiKey, temperature: temperature) { rewriteOutput.append(chunk) }
                } catch { rewriteOutput = parser.replace(in: sourceText, replacements: replacements).text }
                rewriteIsStreaming = false
            }
            return
        }
        rewriteTask = Task { @MainActor in
            do {
                for try await chunk in aiService.rewrite(source: sourceText, replacements: replacements, style: rewriteStyle.rawValue, intensity: rewriteIntensity, channel: rewriteChannel, customRequirements: customRequirements, model: selectedModel, baseURL: baseURL, apiKey: apiKey, temperature: temperature) { rewriteOutput.append(chunk) }
            } catch { rewriteOutput = parser.replace(in: sourceText, replacements: replacements).text }
            rewriteIsStreaming = false
        }
    }

    func detectModels(reduceMotion: Bool) {
        guard !isDetectingModels else { return }
        guard let key = CredentialStore.shared.loadAPIKey(), !key.isEmpty else { availableModels = AIModel.mockModels; return }
        isDetectingModels = true
        availableModels = []
        Task { @MainActor in
            do {
                let models = try await aiService.fetchModels(baseURL: baseURL, apiKey: key)
                for model in models {
                    availableModels.append(model)
                    if !reduceMotion { try? await Task.sleep(nanoseconds: 80_000_000) }
                }
            } catch { availableModels = AIModel.mockModels }
            isDetectingModels = false
        }
    }

    func selectModel(_ model: AIModel) { selectedModel = model; saveSettings() }
    func saveAPIKey(_ value: String) { try? CredentialStore.shared.saveAPIKey(value); apiKeyMasked = maskedAPIKey }
    func saveSettings() {
        storage.saveSettings(AppSettings(selectedModelID: selectedModel.id, baseURL: baseURL, rewriteStyle: rewriteStyle, intensity: rewriteIntensity, channel: rewriteChannel, customRequirements: customRequirements, temperature: temperature, concurrency: concurrency, directories: AppSettings.defaultValue.directories))
    }
}
