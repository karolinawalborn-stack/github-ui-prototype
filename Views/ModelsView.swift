import SwiftUI

struct ModelsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var apiKeyInput = ""
    @State private var temperatureInput = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PageHeader(caption: "中转站", title: "模型接入") { EmptyView() }

                VStack(alignment: .leading, spacing: 6) {
                    LabelText(text: "Base URL")
                    TextField("https://api.my-relay.com/v1", text: $store.baseURL)
                        .font(AppFont.mono(size: 12))
                        .foregroundColor(AppTheme.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { store.saveSettings() }
                }
                .fieldCardStyle()
                VStack(alignment: .leading, spacing: 6) {
                    LabelText(text: "API Key")
                    HStack {
                        SecureField(store.apiKeyMasked, text: $apiKeyInput)
                            .font(AppFont.mono(size: 12))
                            .foregroundColor(AppTheme.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("保存") { if !apiKeyInput.isEmpty { store.saveAPIKey(apiKeyInput); apiKeyInput = "" } }
                            .font(AppFont.sans(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .fieldCardStyle()

                AccentButton(title: store.isDetectingModels ? "请求 /v1/models …" : (store.availableModels.isEmpty ? "自动识别模型" : "重新识别"), isBusy: store.isDetectingModels) {
                    store.detectModels(reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                HStack(spacing: 10) {
                    LabelText(text: "Temperature")
                    TextField("自动", text: $temperatureInput)
                        .font(AppFont.mono(size: 12))
                        .foregroundColor(AppTheme.text)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            store.temperature = Double(temperatureInput)
                            store.saveSettings()
                        }
                        .frame(width: 72)
                    Button("清空") { temperatureInput = ""; store.temperature = nil; store.saveSettings() }
                        .font(AppFont.sans(size: 11))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                HStack {
                    LabelText(text: "可用模型")
                    if !store.availableModels.isEmpty {
                        Text("· \(store.availableModels.count)")
                            .font(AppFont.mono(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                LazyVStack(spacing: 6) {
                    ForEach(store.availableModels) { model in
                        ModelRow(model: model, selected: model == store.selectedModel) {
                            store.selectModel(model)
                        }
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

private extension View {
    func fieldCardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }
}

private struct FieldCard: View {
    let label: String
    let value: String
    let monospaced: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabelText(text: label)
            Text(value)
                .font(monospaced ? AppFont.mono(size: 12) : AppFont.sans(size: 12))
                .foregroundColor(AppTheme.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct ModelRow: View {
    let model: AIModel
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.id)
                        .font(AppFont.mono(size: 12))
                        .foregroundColor(AppTheme.text)
                    Text(model.provider)
                        .font(AppFont.sans(size: 10))
                        .foregroundColor(AppTheme.secondaryText)
                }
                Spacer()
                Circle()
                    .stroke(selected ? AppTheme.accent : Color(hex: "3A434E"), lineWidth: selected ? 5 : 1.5)
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? AppTheme.accent.opacity(0.45) : AppTheme.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ModelsView().environmentObject(AppStore())
}
