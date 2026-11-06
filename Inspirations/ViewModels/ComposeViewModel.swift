import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// 速记图片的暂存状态（保存时才写入磁盘）
struct StagedImage: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage?

    init?(data: Data) {
        guard let preview = UIImage.thumbnail(from: data, maxSide: 240) else { return nil }
        self.data = data
        self.preview = preview
    }
}

/// 顶部速记卡片的草稿状态
@MainActor
@Observable
final class ComposeViewModel {
    static let maxImages = 9

    var content = ""
    var stagedImages: [StagedImage] = []
    private(set) var isDictating = false

    /// 听写开始时的文本基线
    private(set) var dictationBase = ""

    var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !stagedImages.isEmpty
    }

    var canAddImages: Bool {
        stagedImages.count < Self.maxImages
    }

    /// 开始听写：快照当前文本作为基线
    func beginDictation() {
        var base = content
        if !base.isEmpty && !base.hasSuffix(" ") && !base.hasSuffix("\n") {
            base += " "
        }
        dictationBase = base
        isDictating = true
    }

    /// 实时合成：基线 + 当前转写
    func applyTranscript(_ transcript: String) {
        guard isDictating else { return }
        content = dictationBase + transcript
    }

    func addImages(from items: [PhotosPickerItem]) async {
        let room = max(0, Self.maxImages - stagedImages.count)
        for item in items.prefix(room) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let staged = StagedImage(data: data) {
                stagedImages.append(staged)
            }
        }
    }

    func removeStaged(_ staged: StagedImage) {
        stagedImages.removeAll { $0.id == staged.id }
    }

    @discardableResult
    func save(store: MemoStore) -> Bool {
        guard canSave else { return false }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        store.create(content: text, imageDatas: stagedImages.map(\.data))
        reset()
        return true
    }

    func reset() {
        content = ""
        stagedImages = []
        dictationBase = ""
        isDictating = false
    }
}
