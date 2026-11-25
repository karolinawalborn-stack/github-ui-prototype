import SwiftUI

struct NetdiskView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PageHeader(caption: "账号", title: "我的网盘") { EmptyView() }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("分享有效期")
                            .font(AppFont.sans(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.text)
                        Text("所有新建分享强制永久，平台不支持时标红提示，不会自动降级")
                            .font(AppFont.sans(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineSpacing(3)
                    }
                    Spacer()
                    Text("永久")
                        .font(AppFont.mono(size: 11))
                        .foregroundColor(AppTheme.amber)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.amber.opacity(0.4), lineWidth: 1))
                }
                .padding(14)
                .background(AppTheme.amber.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.amber.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                LazyVStack(spacing: 8) {
                    ForEach(store.accounts) { account in
                        AccountCard(account: account)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct AccountCard: View {
    let account: NetdiskAccount
    @State private var directory: String
    @State private var showLogin = false
    @State private var showDiagnostics = false

    init(account: NetdiskAccount) {
        self.account = account
        _directory = State(initialValue: account.directory)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PlatformTag(platform: account.platform, completed: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.platform.rawValue)
                        .font(AppFont.sans(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.text)
                    HStack(spacing: 4) {
                        TextField("默认目录", text: $directory)
                            .font(AppFont.sans(size: 10))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                Spacer()
                Text(account.state == .online ? "ONLINE" : "RELOGIN")
                    .font(AppFont.mono(size: 10))
                    .foregroundColor(account.state == .online ? AppTheme.accent : AppTheme.amber)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.mutedPanel)
                    Capsule().fill(account.state == .online ? Color(hex: "5A6470") : AppTheme.amber).frame(width: proxy.size.width * account.quotaUsed)
                }
            }
            .frame(height: 3)
            HStack {
                Text(account.status)
                Spacer()
                Text(account.quotaLabel)
            }
            .font(AppFont.mono(size: 10))
            .foregroundColor(AppTheme.secondaryText)
            HStack(spacing: 8) {
                Button(account.state == .online ? "重新登录" : "登录") { showLogin = true }
                Button("退出") { CredentialStore.shared.deleteCookie(platform: account.platform) }
                Button("诊断") { showDiagnostics = true }
            }
            .font(AppFont.sans(size: 10))
            .foregroundColor(AppTheme.secondaryText)
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(isPresented: $showLogin) {
            NavigationView {
                WebLoginView(platform: account.platform) { showLogin = false }
                    .navigationTitle("登录 · \(account.platform.rawValue)")
                    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { showLogin = false } } }
            }
        }
        .sheet(isPresented: $showDiagnostics) { DiagnosticView(platform: account.platform) }
    }
}

private struct DiagnosticView: View {
    let platform: NetdiskPlatform
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logger = DiagnosticLogger.shared

    var body: some View {
        NavigationView {
            ScrollView {
                Text(logger.latestText(for: platform) ?? "暂无失败诊断记录")
                    .font(AppFont.mono(size: 11))
                    .foregroundColor(AppTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("诊断")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { UIPasteboard.general.string = logger.latestText(for: platform) ?? "" } label: { Image(systemName: "doc.on.doc") }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NetdiskView().environmentObject(AppStore())
}
