import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GridBackground()
            VStack(spacing: 0) {
                Group {
                    switch store.selectedTab {
                    case .transfer:
                        TransferView()
                    case .rewrite:
                        RewriteView()
                    case .netdisk:
                        NetdiskView()
                    case .models:
                        ModelsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                BottomTabBar(selection: $store.selectedTab, reduceMotion: reduceMotion)
            }
        }
        .sheet(isPresented: $store.isHistoryPresented) {
            HistoryView()
                .environmentObject(store)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppStore())
}
