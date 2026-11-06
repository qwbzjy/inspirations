import SwiftData
import SwiftUI

/// 标签管理：重命名（子树）、删除、换色

@MainActor
struct TagManagementView: View {
    @Environment(MemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.path) private var tags: [Tag]

    @State private var renameTarget: Tag?
    @State private var renameText = ""
    @State private var deleteTarget: Tag?

    var body: some View {
        List {
            if tags.isEmpty {
                Text("暂无标签")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.tagColor(tag.colorIndex))
                            .frame(width: 10, height: 10)
                        Text("#\(tag.path)")
                        Spacer()
                        Text("\(tag.memos.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button {
                            renameTarget = tag
                            renameText = tag.path
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Menu("更换颜色") {
                            ForEach(0..<Theme.tagColors.count, id: \.self) { index in
                                Button {
                                    store.setColor(index, for: tag)
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Theme.tagColor(index))
                                            .frame(width: 12, height: 12)
                                        Text("颜色 \(index + 1)")
                                        if tag.colorIndex == index {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        Button(role: .destructive) {
                            deleteTarget = tag
                        } label: {
                            Label("删除标签", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
        .alert(
            "重命名标签",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            ),
            presenting: renameTarget
        ) { tag in
            TextField("新名称", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                store.renameTag(oldPath: tag.path, newBase: renameText)
            }
        } message: { _ in
            Text("子标签会一并重命名")
        }
        .confirmationDialog(
            "删除 #\(deleteTarget?.path ?? "") ？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除标签", role: .destructive) {
                if let target = deleteTarget {
                    store.deleteTag(path: target.path)
                }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("将从相关灵感的文本中移除该标签；子标签不受影响")
        }
    }
}
