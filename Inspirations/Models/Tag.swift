import Foundation
import SwiftData

@Model
final class Tag {
    /// 完整路径，如 "产品/想法"
    @Attribute(.unique) var path: String
    var colorIndex: Int
    var createdAt: Date
    var memos: [Memo] = []

    /// 末段名称，如 "想法"
    var name: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    /// 父路径，如 "产品"；根标签为 nil
    var parentPath: String? {
        let parts = path.split(separator: "/")
        return parts.count > 1 ? parts.dropLast().joined(separator: "/") : nil
    }

    init(path: String, colorIndex: Int = 0, createdAt: Date = .now) {
        self.path = path
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }
}
