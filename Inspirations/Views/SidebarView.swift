import SwiftData
import SwiftUI

/// 侧栏：全部 / 无标签 / 标签树 + 标签管理 + 设置

@MainActor
struct SidebarView: View {
    @Binding var filter: MemoFilter
    var onClose: (() -> Void)?

    @Query(sort: \Tag.path) private var tags: [Tag]
    @State private var showTagManagement = false
    @State private var showSettings = false

    var body: some View {
        List {
            Section {
                filterRow(.all, icon: "tray.full", label: "全部灵感")
                filterRow(.untagged, icon: "tag.slash", label: "无标签")
            }
            Section("标签") {
                if tags.isEmpty {
                    Text("在灵感中输入 #标签 即可自动归类")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(TagTree.build(from: tags)) { node in
                        TagTreeRow(node: node, filter: $filter, depth: 0, onSelect: select)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTagManagement = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showTagManagement) {
            NavigationStack { TagManagementView() }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }

    private func filterRow(_ target: MemoFilter, icon: String, label: String) -> some View {
        Button {
            select(target)
        } label: {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                if filter == target {
                    Image(systemName: "checkmark")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func select(_ target: MemoFilter) {
        filter = target
        onClose?()
    }
}

/// 标签树行（递归展开子标签）
@MainActor
struct TagTreeRow: View {
    let node: TagNode
    @Binding var filter: MemoFilter
    let depth: Int
    let onSelect: @MainActor (MemoFilter) -> Void

    @State private var expanded = true

    var body: some View {
        if node.children.isEmpty {
            row
        } else {
            DisclosureGroup(isExpanded: $expanded) {
                ForEach(node.children) { child in
                    TagTreeRow(node: child, filter: $filter, depth: depth + 1, onSelect: onSelect)
                }
            } label: {
                row
            }
        }
    }

    private var row: some View {
        Button {
            onSelect(.tag(node.path))
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.tagColor(node.colorIndex))
                    .frame(width: 8, height: 8)
                Text(node.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(node.memoCount)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                if filter == .tag(node.path) {
                    Image(systemName: "checkmark")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.leading, CGFloat(depth) * 14)
        }
    }
}
