import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showShareSheet = false

    private var records: [HistoryRecord] { store.storage.loadHistory() + [HistoryRecord(id: UUID(), originalText: store.sourceText, rewrittenText: store.fullMockRewrite, links: store.links, createdAt: Date())] }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                List(filteredRecords) { record in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(record.createdAt, style: .date)
                                .font(AppFont.mono(size: 10))
                                .foregroundColor(AppTheme.secondaryText)
                            Spacer()
                            Text("永久")
                                .font(AppFont.mono(size: 10))
                                .foregroundColor(AppTheme.amber)
                        }
                        Text(record.originalText)
                            .font(AppFont.sans(size: 12))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(2)
                        ForEach(record.links) { link in
                            HStack(spacing: 6) {
                                Text(link.platform.rawValue)
                                    .font(AppFont.sans(size: 11))
                                    .foregroundColor(AppTheme.text)
                                Text("→")
                                    .foregroundColor(AppTheme.accent)
                                Text(link.displayURL)
                                    .font(AppFont.mono(size: 10))
                                    .foregroundColor(AppTheme.accent)
                                    .lineLimit(1)
                            }
                        }
                        HStack(spacing: 10) {
                            Button("复制文案") { UIPasteboard.general.string = record.rewrittenText }
                            Button("复制换链") { UIPasteboard.general.string = record.links.map { "\($0.originalURL) → \($0.displayURL)" }.joined(separator: "\n") }
                        }
                        .font(AppFont.sans(size: 11))
                        .foregroundColor(AppTheme.accent)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.panel)
                }
                .searchable(text: $query, prompt: "搜索历史")
            }
            .navigationTitle("历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(items: [csvText])
            }
        }
        .preferredColorScheme(.dark)
    }

    private var filteredRecords: [HistoryRecord] {
        guard !query.isEmpty else { return records }
        return records.filter { $0.originalText.localizedCaseInsensitiveContains(query) }
    }

    private var csvText: String {
        var rows = ["原链接,新链接,平台,提取码,时间"]
        for link in store.links {
            rows.append("\(link.originalURL),\(link.displayURL),\(link.platform.rawValue),\(link.newPassword ?? ""),\(ISO8601DateFormatter().string(from: Date()))")
        }
        return rows.joined(separator: "\n")
    }
}

#Preview {
    HistoryView().environmentObject(AppStore())
}
