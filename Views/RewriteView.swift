import SwiftUI

struct RewriteView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showShareSheet = false
    @State private var showCustomRequirements = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PageHeader(caption: "文案二创", title: "改写 · 换链") {
                    Button {
                        store.selectedTab = .models
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(AppTheme.accent).frame(width: 6, height: 6)
                            Text(store.selectedModel.id)
                                .font(AppFont.mono(size: 11))
                        }
                        .foregroundColor(AppTheme.text)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(AppTheme.panel)
                        .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 3) {
                    ForEach(RewriteStyle.allCases) { style in
                        Button {
                            store.rewriteStyle = style
                            store.saveSettings()
                            if style == .custom { showCustomRequirements = true }
                            store.generateRewrite(reduceMotion: reduceMotion)
                        } label: {
                            Text(style.rawValue)
                                .font(AppFont.sans(size: 12))
                                .foregroundColor(store.rewriteStyle == style ? AppTheme.text : AppTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(store.rewriteStyle == style ? Color(hex: "232A33") : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(AppTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                CompactSegmentedRow(title: "改写程度", values: ["轻改", "中改", "重写"], selection: $store.rewriteIntensity) {
                    store.saveSettings()
                    store.generateRewrite(reduceMotion: reduceMotion)
                }
                CompactSegmentedRow(title: "发布渠道", values: ["通用", "社群", "小红书"], selection: $store.rewriteChannel) {
                    store.saveSettings()
                    store.generateRewrite(reduceMotion: reduceMotion)
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        LabelText(text: "原文")
                        Text("考研英语真题全套 2005-2026，带逐句精讲 …… 3 条他人链接")
                            .font(AppFont.sans(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                            .strikethrough(color: Color.white.opacity(0.15))
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            LabelText(text: "二创结果")
                            Spacer()
                            Text(store.rewriteIsStreaming ? "生成中" : "完成 · 3 处链接已替换")
                                .font(AppFont.sans(size: 11))
                                .foregroundColor(AppTheme.accent)
                        }
                        highlightedText(store.rewriteOutput)
                            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                            .overlay(alignment: .bottomTrailing) {
                                if store.rewriteIsStreaming {
                                    Rectangle()
                                        .fill(AppTheme.accent)
                                        .frame(width: 7, height: 14)
                                        .opacity(0.9)
                                        .modifier(BlinkingModifier())
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                HStack(spacing: 8) {
                    Button("重新生成") {
                        store.generateRewrite(reduceMotion: reduceMotion)
                    }
                    .buttonStyle(GhostButtonStyle())
                    AccentButton(title: "复制全文") {
                        UIPasteboard.general.string = store.rewriteOutput
                    }
                    .frame(maxWidth: .infinity)
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.text)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear { store.startRewriteIfNeeded(reduceMotion: reduceMotion) }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(items: [store.rewriteOutput])
        }
        .sheet(isPresented: $showCustomRequirements) {
            CustomRequirementsView(text: $store.customRequirements) {
                store.saveSettings()
                store.generateRewrite(reduceMotion: reduceMotion)
            }
        }
    }

    private func highlightedText(_ text: String) -> Text {
        let pattern = #"(pan\.[a-z]+\.[^\s]+|drive\.uc\.cn/[^\s]+|guangya\.com/[^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(text).font(AppFont.sans(size: 13)).foregroundColor(AppTheme.text)
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var result = Text("")
        var cursor = 0
        for match in matches {
            let before = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            if !before.isEmpty { result = result + Text(before).font(AppFont.sans(size: 13)).foregroundColor(AppTheme.text) }
            let link = nsText.substring(with: match.range)
            result = result + Text(link)
                .font(AppFont.mono(size: 10.5))
                .foregroundColor(AppTheme.accent)
            cursor = match.range.location + match.range.length
        }
        let tail = nsText.substring(from: cursor)
        if !tail.isEmpty { result = result + Text(tail).font(AppFont.sans(size: 13)).foregroundColor(AppTheme.text) }
        return result
    }
}

private struct CompactSegmentedRow: View {
    let title: String
    let values: [String]
    @Binding var selection: String
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(AppFont.sans(size: 11)).foregroundColor(AppTheme.secondaryText).frame(width: 52, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(values, id: \.self) { value in
                    Button(value) { selection = value; onChange() }
                        .font(AppFont.sans(size: 11))
                        .foregroundColor(selection == value ? AppTheme.text : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selection == value ? Color(hex: "232A33") : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(AppTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct CustomRequirementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let save: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                TextEditor(text: $text)
                    .font(AppFont.sans(size: 14))
                    .foregroundColor(AppTheme.text)
                    .padding(12)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(16)
            }
            .navigationTitle("自定义要求")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { save(); dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.sans(size: 14))
            .foregroundColor(AppTheme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct BlinkingModifier: ViewModifier {
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { visible.toggle() }
            }
    }
}

#Preview {
    RewriteView().environmentObject(AppStore())
}
