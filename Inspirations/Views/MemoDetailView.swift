import PhotosUI
import SwiftData
import SwiftUI

/// 灵感详情：全文、行内编辑、图片网格 → 全屏查看器
@MainActor
struct MemoDetailView: View {
    @Environment(MemoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let memo: Memo

    @State private var isEditing = false
    @State private var editText = ""
    @State private var removedAssetIDs: Set<UUID> = []
    @State private var newPreviews: [StagedImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showDeleteConfirm = false
    @State private var showViewer = false
    @State private var viewerStart = 0

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .navigationTitle(DateGrouper.sectionLabel(for: DateGrouper.startOfDay(for: memo.createdAt)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarMenu }
            .confirmationDialog("删除这条灵感？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    Haptics.delete()
                    store.delete(memo)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showViewer) {
                ImageViewerView(assets: visibleAssets, index: viewerStart)
            }
            .onChange(of: pickerItems, loadPickedOnChange)
    }

    // MARK: - 主体内容

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                editorSection
                imageGrid
                tagSection
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var editorSection: some View {
        editTools
        if isEditing {
            TextField("编辑灵感内容", text: $editText, axis: .vertical)
                .lineLimit(10...20)
                .frame(minHeight: 180)
        } else {
            Text(highlighted)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        if !isEditing && !memo.tags.isEmpty {
            tagChips
        }
    }

    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if isEditing {
                    Button("保存") { saveEdit() }
                        .disabled(!canSaveEdit)
                    Button("取消", role: .cancel) { cancelEdit() }
                } else {
                    Button {
                        startEdit()
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - 可见图片

    private var visibleAssets: [ImageAsset] {
        memo.sortedImages.filter { !removedAssetIDs.contains($0.id) }
    }

    private var canSaveEdit: Bool {
        let hasText = !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !visibleAssets.isEmpty || !newPreviews.isEmpty
    }

    // MARK: - 编辑工具条与暂存图

    @ViewBuilder
    private var editTools: some View {
        if isEditing {
            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: editPickerRoom,
                    matching: .images
                ) {
                    Label("添加图片", systemImage: "plus.viewfinder")
                        .font(.subheadline)
                }
                .disabled(editImageCount >= ComposeViewModel.maxImages)
                Spacer()
            }
            if !newPreviews.isEmpty {
                newPreviewsRow
            }
        }
    }

    private var editImageCount: Int {
        visibleAssets.count + newPreviews.count
    }

    private var editPickerRoom: Int {
        max(1, ComposeViewModel.maxImages - editImageCount)
    }

    private var newPreviewsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(newPreviews) { staged in
                    stagedPreviewCell(staged)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func stagedPreviewCell(_ staged: StagedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let preview = staged.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button {
                newPreviews.removeAll { $0.id == staged.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
        }
    }

    // MARK: - 图片网格

    private var imageGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(visibleAssets) { asset in
                imageCell(asset)
            }
        }
    }

    private func imageCell(_ asset: ImageAsset) -> some View {
        Button {
            viewerStart = visibleAssets.firstIndex(where: { $0.id == asset.id }) ?? 0
            showViewer = true
        } label: {
            Group {
                if let thumb = store.imageStore.thumbnail(for: asset) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.tertiarySystemFill)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    removeImageButton(asset)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isEditing)
    }

    private func removeImageButton(_ asset: ImageAsset) -> some View {
        Button {
            removedAssetIDs.insert(asset.id)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white, .red.opacity(0.85))
        }
        .offset(x: 6, y: -6)
    }

    // MARK: - 标签

    private var tagChips: some View {
        let columns = [GridItem(.adaptive(minimum: 96), alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(memo.tags) { tag in
                tagChip(tag)
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.tagColor(tag.colorIndex))
                .frame(width: 7, height: 7)
            Text("#\(tag.path)")
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private var metaLine: String {
        var text = DateGrouper.detailLabel(for: memo.createdAt)
        if memo.updatedAt.timeIntervalSince(memo.createdAt) > 60 {
            text += " · 已编辑"
        }
        return text
    }

    // MARK: - 编辑操作

    private func startEdit() {
        editText = memo.content
        removedAssetIDs = []
        newPreviews = []
        isEditing = true
    }

    private func cancelEdit() {
        removedAssetIDs = []
        newPreviews = []
        editText = ""
        isEditing = false
    }

    private func saveEdit() {
        guard canSaveEdit else { return }
        Haptics.success()
        let removed = memo.sortedImages.filter { removedAssetIDs.contains($0.id) }
        store.update(
            memo,
            content: editText.trimmingCharacters(in: .whitespacesAndNewlines),
            newImageDatas: newPreviews.map(\.data),
            removeAssets: removed
        )
        cancelEdit()
    }

    // MARK: - 图片选择

    private func loadPickedOnChange(_ old: [PhotosPickerItem], _ newItems: [PhotosPickerItem]) {
        guard !newItems.isEmpty else { return }
        Task {
            await loadPicked(newItems)
            pickerItems = []
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        let room = max(0, ComposeViewModel.maxImages - editImageCount)
        for item in items.prefix(room) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let staged = StagedImage(data: data) {
                newPreviews.append(staged)
            }
        }
    }

    // MARK: - #标签着色

    private var highlighted: AttributedString {
        let content = memo.content
        guard let regex = try? NSRegularExpression(pattern: TagParser.pattern) else {
            return AttributedString(content)
        }
        let ns = content as NSString
        var result = AttributedString()
        var cursor = 0
        for match in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result.append(AttributedString(plain))
            }
            var tag = AttributedString(ns.substring(with: match.range))
            tag.foregroundColor = .accentColor
            tag.font = .body.weight(.medium)
            result.append(tag)
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let plain = ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            result.append(AttributedString(plain))
        }
        return result
    }
}
