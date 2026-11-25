import SwiftUI

struct TransferView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PageHeader(caption: "转存台", title: "批量转存") {
                    HStack(spacing: 8) {
                        Button {
                            store.isHistoryPresented = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        OnlinePill()
                    }
                }

                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        LabelText(text: "粘贴文案 · 自动识别")
                        TextEditor(text: $store.sourceText)
                            .focused($inputFocused)
                            .font(AppFont.mono(size: 10.5))
                            .foregroundColor(Color(hex: "C9D0D6"))
                            .frame(minHeight: 132)
                            .tint(AppTheme.accent)
                    }
                    .padding(14)
                    .background(AppTheme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    ScanLine(active: !reduceMotion)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("识别到 ")
                        .font(AppFont.sans(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                    Text("3")
                        .font(AppFont.mono(size: 12))
                        .foregroundColor(AppTheme.text)
                    Text(" 条链接")
                        .font(AppFont.sans(size: 12))
                        .foregroundColor(AppTheme.secondaryText)
                    Spacer()
                    PermanentBadge()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                LazyVStack(spacing: 8) {
                    ForEach(store.links) { link in
                        TransferLinkCard(link: link)
                    }
                }
                .padding(.horizontal, 16)

                AccentButton(
                    title: store.transferFinished ? "完成 · 去二创" : "一键转存并生成我的链接",
                    isBusy: store.isTransferring
                ) {
                    store.startTransfer(reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text(transferSummary)
                    .font(AppFont.mono(size: 11))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
    }

    private var transferSummary: String {
        let completed = store.links.filter(\.isComplete).count
        return store.transferFinished ? "\(completed) / \(store.links.count) 完成 · 全部永久有效" : "\(completed) / \(store.links.count) 完成"
    }
}

private struct OnlinePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(AppTheme.accent).frame(width: 6, height: 6)
            Text("5 盘在线")
                .font(AppFont.sans(size: 11))
        }
        .foregroundColor(AppTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
    }
}

private struct ScanLine: View {
    let active: Bool
    @State private var offset: CGFloat = -40

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, AppTheme.accent.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)
            .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.accent.opacity(0.5)).frame(height: 1) }
            .offset(y: offset)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false)) {
                    offset = proxy.size.height
                }
            }
        }
        .clipped()
    }
}

struct TransferLinkCard: View {
    let link: TransferLink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PlatformTag(platform: link.platform, completed: link.isComplete)
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.platform.rawValue)
                        .font(AppFont.sans(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.text)
                    Text(link.displayURL)
                        .font(AppFont.mono(size: 10))
                        .foregroundColor(link.isComplete ? AppTheme.accent : AppTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                ForEach(Array(TransferStage.allCases.enumerated()), id: \.offset) { index, stage in
                    let state = link.stages[index]
                    VStack(spacing: 5) {
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.mutedPanel).frame(height: 3)
                            Capsule()
                                .fill(AppTheme.accent)
                                .frame(width: state == .completed ? nil : (state == .running ? 22.0 : 0.0), height: 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(state == .pending ? 0 : 1)
                                .animation(.easeOut(duration: 0.45), value: state)
                        }
                        Text(stage.rawValue)
                            .font(AppFont.sans(size: 9.5))
                            .foregroundColor(state == .pending ? Color(hex: "4D5661") : AppTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(link.isComplete ? AppTheme.accent.opacity(0.35) : AppTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    TransferView().environmentObject(AppStore())
}
