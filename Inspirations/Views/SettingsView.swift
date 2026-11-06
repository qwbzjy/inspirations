import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 设置：统计、导出备份、导入备份

@MainActor
struct SettingsView: View {
    @Environment(MemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Memo.createdAt, order: .reverse) private var memos: [Memo]
    @Query(sort: \Tag.path) private var tags: [Tag]

    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @State private var pendingImportURL: URL?
    @State private var showImportMode = false
    @State private var importResult: ImportResult?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("统计") {
                statRow("灵感", memos.count)
                statRow("标签", tags.count)
                statRow("图片", memos.reduce(0) { $0 + $1.images.count })
            }
            Section("备份") {
                Button {
                    do {
                        exportURL = try BackupService.exportJSON(store: store)
                        showShare = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Label("导出备份 (JSON)", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                }
            }
            Section {
                Text("导出为单个 JSON 文件，包含全部灵感、标签与图片；导入时可选合并或替换现有数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ActivityView(items: [exportURL])
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showImportMode = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .confirmationDialog("选择导入方式", isPresented: $showImportMode, titleVisibility: .visible) {
            Button("合并（保留现有数据）") { runImport(mode: .merge) }
            Button("替换（清空后导入）", role: .destructive) { runImport(mode: .replace) }
            Button("取消", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("相同内容自动跳过；内容不同则以新灵感复制，不覆盖本地修改")
        }
        .alert(
            "导入完成",
            isPresented: Binding(
                get: { importResult != nil },
                set: { if !$0 { importResult = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            if let result = importResult {
                Text("新增 \(result.inserted) 条，复制重复 \(result.duplicated) 条，跳过相同 \(result.skipped) 条")
            }
        }
        .alert(
            "出错了",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func runImport(mode: BackupService.Mode) {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        do {
            importResult = try BackupService.importJSON(from: url, mode: mode, store: store)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statRow(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// 系统分享面板（iPad 上包在 sheet 中无需 popover 锚点）

@MainActor
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
