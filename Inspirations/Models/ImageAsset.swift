import Foundation
import SwiftData

@Model
final class ImageAsset {
    @Attribute(.unique) var id: UUID
    /// 原图文件名，位于 MemoImages 目录
    var filename: String
    /// 缩略图文件名
    var thumbFilename: String
    var order: Int
    var memo: Memo?

    init(id: UUID = UUID(), filename: String, thumbFilename: String, order: Int) {
        self.id = id
        self.filename = filename
        self.thumbFilename = thumbFilename
        self.order = order
    }
}
