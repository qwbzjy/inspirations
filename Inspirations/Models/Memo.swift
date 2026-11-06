import Foundation
import SwiftData

@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ImageAsset.memo)
    var images: [ImageAsset] = []

    @Relationship
    var tags: [Tag] = []

    init(id: UUID = UUID(), content: String, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 按录入顺序排列的图片
    var sortedImages: [ImageAsset] {
        images.sorted { $0.order < $1.order }
    }
}
