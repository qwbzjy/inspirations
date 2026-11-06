import SwiftUI

/// 列表过滤状态
enum MemoFilter: Equatable {
    case all
    case untagged
    case tag(String)

    var title: String {
        switch self {
        case .all: return "全部灵感"
        case .untagged: return "无标签"
        case .tag(let path): return "#\(path)"
        }
    }
}

/// iPhone：单列 + 侧栏 sheet；iPad：NavigationSplitView

@MainActor
struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var filter: MemoFilter = .all
    @State private var showSidebar = false

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                SidebarView(filter: $filter)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                NavigationStack {
                    MemoListView(filter: filter)
                }
            }
        } else {
            NavigationStack {
                MemoListView(filter: filter, onOpenSidebar: { showSidebar = true })
            }
            .sheet(isPresented: $showSidebar) {
                NavigationStack {
                    SidebarView(filter: $filter, onClose: { showSidebar = false })
                        .navigationTitle("标签")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
