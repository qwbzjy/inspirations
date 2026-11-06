import SwiftUI

/// 主题常量：标签调色板与卡片样式
enum Theme {
    /// 8 色标签调色板
    static let tagColors: [Color] = [
        .red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple,
    ]

    static func tagColor(_ index: Int) -> Color {
        tagColors[abs(index) % tagColors.count]
    }

    /// 由标签路径确定性分配颜色（创建时持久化到 colorIndex）
    static func colorIndex(for path: String) -> Int {
        var hash: Int = 5381
        for scalar in path.unicodeScalars {
            hash = ((hash &<< 5) &+ hash) &+ Int(truncatingIfNeeded: scalar.value)
        }
        return Int(UInt(bitPattern: hash) % UInt(tagColors.count))
    }

    static let cardCorner: CGFloat = 14
    static let spacing: CGFloat = 12
    /// iPad 宽屏下的内容列宽
    static let contentMaxWidth: CGFloat = 720
}

extension View {
    /// 灵感卡片样式
    func cardStyle() -> some View {
        self
            .padding(Theme.spacing)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
            )
    }
}
