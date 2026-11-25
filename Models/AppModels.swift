import Foundation

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case transfer, rewrite, netdisk, models
    var id: String { rawValue }
    var title: String {
        switch self { case .transfer: return "转存"; case .rewrite: return "二创"; case .netdisk: return "网盘"; case .models: return "模型" }
    }
    var symbol: String {
        switch self { case .transfer: return "arrow.down.to.line"; case .rewrite: return "pencil.line"; case .netdisk: return "externaldrive"; case .models: return "cpu" }
    }
}

enum NetdiskPlatform: String, CaseIterable, Identifiable, Codable {
    case quark = "夸克网盘", baidu = "百度网盘", xunlei = "迅雷网盘", uc = "UC网盘", guangya = "光鸭网盘"
    var id: String { rawValue }
    var shortName: String {
        switch self { case .quark: return "夸"; case .baidu: return "百"; case .xunlei: return "迅"; case .uc: return "U"; case .guangya: return "光" }
    }
}

enum TransferStage: String, CaseIterable, Identifiable, Codable {
    case parsing = "解析", saving = "转存", sharing = "建分享", replacing = "替换"
    var id: String { rawValue }
}

enum TransferStageState: Equatable, Codable { case pending, running, completed }

struct TransferLink: Identifiable, Equatable, Codable {
    let id: UUID
    let platform: NetdiskPlatform
    let originalURL: String
    let password: String?
    var newURL: String?
    var newPassword: String?
    var stages: [TransferStageState]

    init(id: UUID = UUID(), platform: NetdiskPlatform, originalURL: String, password: String? = nil, newURL: String? = nil, newPassword: String? = nil, stages: [TransferStageState] = Array(repeating: .pending, count: TransferStage.allCases.count)) {
        self.id = id; self.platform = platform; self.originalURL = originalURL; self.password = password; self.newURL = newURL; self.newPassword = newPassword; self.stages = stages
    }
    var displayURL: String { newURL ?? originalURL }
    var isComplete: Bool { stages.allSatisfy { $0 == .completed } }
}

struct NetdiskAccount: Identifiable {
    let id: UUID
    let platform: NetdiskPlatform
    let status: String
    let state: AccountState
    let quotaUsed: Double
    let quotaLabel: String
    let directory: String
    enum AccountState: Equatable { case online, relogin }
    init(id: UUID = UUID(), platform: NetdiskPlatform, status: String, state: AccountState, quotaUsed: Double, quotaLabel: String, directory: String) {
        self.id = id; self.platform = platform; self.status = status; self.state = state; self.quotaUsed = quotaUsed; self.quotaLabel = quotaLabel; self.directory = directory
    }
}

struct AIModel: Identifiable, Equatable, Codable {
    let id: String
    let provider: String
}

enum RewriteStyle: String, CaseIterable, Identifiable, Codable {
    case recommendation = "种草", practical = "干货", suspense = "悬念", concise = "简洁", custom = "自定义"
    var id: String { rawValue }
}

struct HistoryRecord: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let rewrittenText: String
    let links: [TransferLink]
    let createdAt: Date
}

extension TransferLink {
    static let mockLinks: [TransferLink] = [
        TransferLink(platform: .quark, originalURL: "pan.quark.cn/s/8f2a1c9e7b41"),
        TransferLink(platform: .baidu, originalURL: "pan.baidu.com/s/1Qx7Lm2pZk", password: "8k2d"),
        TransferLink(platform: .xunlei, originalURL: "pan.xunlei.com/s/VNs82kLq", password: "t7wq")
    ]
}

extension NetdiskAccount {
    static let mockAccounts: [NetdiskAccount] = [
        NetdiskAccount(platform: .quark, status: "已登录 · 88VIP", state: .online, quotaUsed: 0.62, quotaLabel: "1.8T / 6T", directory: "/拉新资源/2026-11"),
        NetdiskAccount(platform: .uc, status: "已登录", state: .online, quotaUsed: 0.23, quotaLabel: "0.4T / 2T", directory: "/拉新资源/2026-11"),
        NetdiskAccount(platform: .xunlei, status: "已登录 · 超会", state: .online, quotaUsed: 0.41, quotaLabel: "4.1T / 10T", directory: "/拉新资源/2026-11"),
        NetdiskAccount(platform: .baidu, status: "已登录 · SVIP", state: .online, quotaUsed: 0.78, quotaLabel: "3.9T / 5T", directory: "/拉新资源/2026-11"),
        NetdiskAccount(platform: .guangya, status: "Cookie 将过期，需重新登录", state: .relogin, quotaUsed: 0.12, quotaLabel: "0.2T / 2T", directory: "/拉新资源/2026-11")
    ]
}

extension AIModel {
    static let mockModels: [AIModel] = [AIModel(id: "deepseek-chat", provider: "DeepSeek"), AIModel(id: "gpt-4o-mini", provider: "OpenAI"), AIModel(id: "claude-sonnet-4", provider: "Anthropic"), AIModel(id: "qwen-plus", provider: "通义"), AIModel(id: "gemini-2.5-flash", provider: "Google"), AIModel(id: "glm-4-plus", provider: "智谱")]
}
