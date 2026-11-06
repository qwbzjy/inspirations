import Foundation
import Observation
import SwiftData

/// 所有写操作的唯一入口，维护「内容 ↔ 标签实体」同步不变量
@MainActor
@Observable
final class MemoStore {
    let imageStore: ImageStore
    private let modelContext: ModelContext

    init(modelContext: ModelContext, imageStore: ImageStore) {
        self.modelContext = modelContext
        self.imageStore = imageStore
    }

    // MARK: - 查询助手

    func allMemos() -> [Memo] {
        let descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func allTags() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.path)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save() {
        try? modelContext.save()
    }

    // MARK: - 灵感 CRUD

    @discardableResult
    func create(content: String, imageDatas: [Data]) -> Memo {
        let memo = Memo(content: content)
        modelContext.insert(memo)
        appendImages(to: memo, datas: imageDatas, startOrder: 0)
        resyncTags(for: memo)
        try? modelContext.save()
        return memo
    }

    /// 编辑：替换文本、追加新图、移除指定图片
    func update(_ memo: Memo, content: String, newImageDatas: [Data] = [], removeAssets: [ImageAsset] = []) {
        for asset in removeAssets {
            imageStore.delete(asset: asset)
            memo.images.removeAll { $0 === asset }
            modelContext.delete(asset)
        }
        let startOrder = (memo.images.map(\.order).max() ?? -1) + 1
        appendImages(to: memo, datas: newImageDatas, startOrder: startOrder)
        memo.content = content
        memo.updatedAt = .now
        resyncTags(for: memo)
        try? modelContext.save()
    }

    func delete(_ memo: Memo) {
        for asset in memo.images {
            imageStore.delete(asset: asset)
        }
        modelContext.delete(memo)
        deleteOrphanTags()
        try? modelContext.save()
    }

    /// 清空全部灵感与标签（导入-替换模式使用）
    func deleteAll() {
        for memo in allMemos() {
            for asset in memo.images {
                imageStore.delete(asset: asset)
            }
            modelContext.delete(memo)
        }
        for tag in allTags() {
            modelContext.delete(tag)
        }
        try? modelContext.save()
    }

    private func appendImages(to memo: Memo, datas: [Data], startOrder: Int) {
        for (offset, data) in datas.enumerated() {
            guard let stored = try? imageStore.write(data: data) else { continue }
            let asset = ImageAsset(
                filename: stored.filename,
                thumbFilename: stored.thumbFilename,
                order: startOrder + offset
            )
            modelContext.insert(asset)
            asset.memo = memo
            memo.images.append(asset)
        }
    }

    // MARK: - 标签

    /// 依据内容重建 memo.tags，并清理孤儿标签
    private func resyncTags(for memo: Memo) {
        let paths = TagParser.extractTags(from: memo.content)
        let existing = allTags()
        var newTags: [Tag] = []
        for path in paths {
            if let tag = existing.first(where: { $0.path == path }) {
                newTags.append(tag)
            } else {
                let tag = Tag(path: path, colorIndex: Theme.colorIndex(for: path))
                modelContext.insert(tag)
                newTags.append(tag)
            }
        }
        memo.tags = newTags
        deleteOrphanTags()
    }

    private func deleteOrphanTags() {
        for tag in allTags() where tag.memos.isEmpty {
            modelContext.delete(tag)
        }
    }

    /// 重命名标签节点（子树）：重写所有相关内容与标签实体
    func renameTag(oldPath: String, newBase: String) {
        let newBase = newBase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !newBase.isEmpty, newBase != oldPath else { return }

        let tags = allTags()
        let affected = tags.filter { $0.path == oldPath || $0.path.hasPrefix(oldPath + "/") }
        guard !affected.isEmpty else { return }

        let affectedIDs = Set(affected.flatMap { $0.memos }.map(\.persistentModelID))
        let affectedMemos = allMemos().filter { affectedIDs.contains($0.persistentModelID) }

        // 1. 重写内容（一次前缀替换覆盖 #old 与 #old/child）
        for memo in affectedMemos {
            memo.content = TagParser.replacingTag(oldPath, with: newBase, in: memo.content)
            memo.updatedAt = .now
        }
        // 2. 重命名实体；目标路径已存在时并入
        for tag in affected {
            let suffix = String(tag.path.dropFirst(oldPath.count))
            let newPath = newBase + suffix
            if let existing = tags.first(where: { $0 !== tag && $0.path == newPath }), !existing.isDeleted {
                modelContext.delete(tag)
            } else {
                tag.path = newPath
            }
        }
        // 3. 依内容重建关系，保持不变量
        for memo in affectedMemos {
            resyncTags(for: memo)
        }
        try? modelContext.save()
    }

    /// 删除精确标签：从内容中移除 #path（子标签不受影响）
    func deleteTag(path: String) {
        guard let tag = allTags().first(where: { $0.path == path }) else { return }
        let memos = tag.memos
        for memo in memos {
            memo.content = TagParser.removingTag(path, in: memo.content)
            memo.updatedAt = .now
        }
        modelContext.delete(tag)
        for memo in memos {
            resyncTags(for: memo)
        }
        deleteOrphanTags()
        try? modelContext.save()
    }

    func setColor(_ index: Int, for tag: Tag) {
        tag.colorIndex = index
        try? modelContext.save()
    }

    // MARK: - 导入

    /// 导入使用：按给定 id 插入 memo，写图片文件、按路径关联标签（不自动保存，批量导入后统一 save）
    func insertImported(_ memo: Memo, images: [(id: UUID, data: Data)], tagPaths: [String]) {
        modelContext.insert(memo)
        for (offset, image) in images.enumerated() {
            guard let stored = try? imageStore.write(data: image.data) else { continue }
            let asset = ImageAsset(id: image.id, filename: stored.filename, thumbFilename: stored.thumbFilename, order: offset)
            modelContext.insert(asset)
            asset.memo = memo
            memo.images.append(asset)
        }
        var tags: [Tag] = []
        let existing = allTags()
        for path in tagPaths {
            if let tag = existing.first(where: { $0.path == path }) {
                tags.append(tag)
            } else {
                let tag = Tag(path: path, colorIndex: Theme.colorIndex(for: path))
                modelContext.insert(tag)
                tags.append(tag)
            }
        }
        memo.tags = tags
    }
}
