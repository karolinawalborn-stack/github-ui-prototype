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

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PlatformTag(platform: account.platform, completed: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.platform.rawValue)
                        .font(AppFont.sans(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.text)
                    Text("保存到 \(account.directory)")
                        .font(AppFont.sans(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
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
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NetdiskView().environmentObject(AppStore())
}
