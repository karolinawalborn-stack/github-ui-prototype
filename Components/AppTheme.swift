import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(hex: "090B0E")
    static let panel = Color(hex: "141920")
    static let text = Color(hex: "E8ECEF")
    static let secondaryText = Color(hex: "7D8792")
    static let accent = Color(hex: "3CF0B0")
    static let amber = Color(hex: "FFB23F")
    static let line = Color.white.opacity(0.08)
    static let mutedPanel = Color(hex: "1E242C")
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum AppFont {
    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Space Grotesk", size: size).weight(weight)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("JetBrains Mono", size: size).weight(weight)
    }
}

struct GridBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.background
                Canvas { context, size in
                    let step: CGFloat = 28
                    var path = Path()
                    stride(from: 0, through: size.width, by: step).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    stride(from: 0, through: size.height, by: step).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(AppTheme.line), lineWidth: 1)
                }
                RadialGradient(
                    colors: [.clear, AppTheme.background.opacity(0.88)],
                    center: .top,
                    startRadius: 10,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.82
                )
            }
            .ignoresSafeArea()
        }
    }
}

struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AccentButton: View {
    let title: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView().tint(AppTheme.accent)
                }
                Text(title)
                    .font(AppFont.sans(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(isBusy ? AppTheme.accent : Color(hex: "06120D"))
            .background(isBusy ? AppTheme.mutedPanel : AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct LabelText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.sans(size: 11))
            .foregroundColor(AppTheme.secondaryText)
    }
}

struct PermanentBadge: View {
    var body: some View {
        Text("有效期 · 永久")
            .font(AppFont.mono(size: 11))
            .foregroundColor(AppTheme.amber)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.amber.opacity(0.4), lineWidth: 1))
    }
}

struct PlatformTag: View {
    let platform: NetdiskPlatform
    let completed: Bool

    var body: some View {
        Text(platform.shortName)
            .font(AppFont.sans(size: 12, weight: .bold))
            .foregroundColor(completed ? Color(hex: "06120D") : AppTheme.text)
            .frame(width: 30, height: 30)
            .background(completed ? AppTheme.accent : AppTheme.mutedPanel)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct PageHeader<Trailing: View>: View {
    let caption: String
    let title: String
    let trailing: Trailing

    init(caption: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.caption = caption
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(AppFont.sans(size: 11))
                    .tracking(1.1)
                    .foregroundColor(AppTheme.secondaryText)
                Text(title)
                    .font(AppFont.sans(size: 26, weight: .bold))
                    .foregroundColor(AppTheme.text)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 16)
    }
}

struct BottomTabBar: View {
    @Binding var selection: AppTab
    let reduceMotion: Bool
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    if reduceMotion {
                        selection = tab
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) { selection = tab }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .regular))
                        Text(tab.title)
                            .font(AppFont.sans(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selection == tab ? AppTheme.accent : Color(hex: "5A6470"))
                    .overlay(alignment: .top) {
                        if selection == tab {
                            Capsule()
                                .fill(AppTheme.accent)
                                .frame(width: 28, height: 2)
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                                .offset(y: -9)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 11)
        .padding(.bottom, 20)
        .background(AppTheme.background.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }
}

struct CardContainer<Content: View>: View {
    let content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .background(AppTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
