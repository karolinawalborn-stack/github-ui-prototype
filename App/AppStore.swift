import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab: AppTab = .transfer
    @Published var sourceText = "考研英语真题全套 2005-2026，带逐句精讲\n夸克 https://pan.quark.cn/s/8f2a1c9e7b41\n百度 https://pan.baidu.com/s/1Qx7Lm2pZk 提取码: 8k2d\n迅雷 https://pan.xunlei.com/s/VNs82kLq 提取码: t7wq"
    @Published var links = TransferLink.mockLinks
    @Published var isTransferring = false
    @Published var transferFinished = false
    @Published var rewriteStyle: RewriteStyle = .recommendation
    @Published var rewriteOutput = ""
    @Published var rewriteIsStreaming = false
    @Published var selectedModel: AIModel = AIModel.mockModels[0]
    @Published var availableModels: [AIModel] = []
    @Published var isDetectingModels = false
    @Published var isHistoryPresented = false
    @Published var showShareSheet = false

    let accounts = NetdiskAccount.mockAccounts
    let aiService: AIService
    let storage: AppStorageProtocol

    private var rewriteTask: Task<Void, Never>?

    init(aiService: AIService = MockAIService(), storage: AppStorageProtocol = MockAppStorage()) {
        self.aiService = aiService
        self.storage = storage
        if let saved = storage.loadSelectedModel(), let model = AIModel.mockModels.first(where: { $0.id == saved }) {
            selectedModel = model
        }
    }

    func startTransfer(reduceMotion: Bool) {
        guard !isTransferring else { return }
        if transferFinished {
            selectedTab = .rewrite
            return
        }
        isTransferring = true
        transferFinished = false
        links = links.map { link in
            var updated = link
            updated.stages = Array(repeating: .pending, count: TransferStage.allCases.count)
            updated.newURL = nil
            updated.newPassword = nil
            return updated
        }

        let delay: UInt64 = reduceMotion ? 0 : 500_000_000
        for index in links.indices {
            Task { @MainActor in
                if !reduceMotion {
                    try? await Task.sleep(nanoseconds: UInt64(index) * 260_000_000)
                }
                for stageIndex in TransferStage.allCases.indices {
                    links[index].stages[stageIndex] = .running
                    if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
                    links[index].stages[stageIndex] = .completed
                }
                links[index].newURL = mockDestination(for: links[index].platform)
                links[index].newPassword = links[index].platform == .quark ? nil : "6x2m"
                if links.allSatisfy(\.isComplete) {
                    isTransferring = false
                    transferFinished = true
                }
            }
        }
    }

    func startRewriteIfNeeded(reduceMotion: Bool) {
        guard rewriteOutput.isEmpty, !rewriteIsStreaming else { return }
        generateRewrite(reduceMotion: reduceMotion)
    }

    func generateRewrite(reduceMotion: Bool) {
        rewriteTask?.cancel()
        rewriteOutput = ""
        rewriteIsStreaming = true
        if reduceMotion {
            rewriteOutput = fullMockRewrite
            rewriteIsStreaming = false
            return
        }
        rewriteTask = Task { @MainActor in
            do {
                for try await chunk in aiService.streamRewrite(source: sourceText, style: rewriteStyle, model: selectedModel) {
                    rewriteOutput.append(chunk)
                }
            } catch {
                rewriteOutput = fullMockRewrite
            }
            rewriteIsStreaming = false
        }
    }

    func detectModels(reduceMotion: Bool) {
        guard !isDetectingModels else { return }
        isDetectingModels = true
        availableModels = []
        Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(nanoseconds: 900_000_000) }
            for model in AIModel.mockModels {
                availableModels.append(model)
                if !reduceMotion { try? await Task.sleep(nanoseconds: 140_000_000) }
            }
            isDetectingModels = false
        }
    }

    func selectModel(_ model: AIModel) {
        selectedModel = model
        storage.saveSelectedModel(model.id)
    }

    func mockDestination(for platform: NetdiskPlatform) -> String {
        switch platform {
        case .quark: return "pan.quark.cn/s/c41e0a77d2f9"
        case .baidu: return "pan.baidu.com/s/1Ka9Wm3rTq?pwd=6x2m"
        case .xunlei: return "pan.xunlei.com/s/VNa1Pq0zR8?pwd=h3k9"
        case .uc: return "drive.uc.cn/s/mock-relay"
        case .guangya: return "guangya.com/s/mock-relay"
        }
    }

    var fullMockRewrite: String {
        "整理了一份 2005—2026 年的考研英语真题，每篇都配逐句精讲，二刷查漏刚好用。\n\n夸克 → pan.quark.cn/s/c41e0a77d2f9\n百度 → pan.baidu.com/s/1Ka9Wm3rTq?pwd=6x2m\n迅雷 → pan.xunlei.com/s/VNa1Pq0zR8?pwd=h3k9\n\n链接永久有效，先存再看。"
    }
}
