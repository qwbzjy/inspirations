import SwiftData
import SwiftUI

/// 列表中的灵感卡片：内容预览（#标签着色）+ 缩略图 + 时间

@MainActor
struct MemoRowView: View {
    let memo: Memo

    @Environment(MemoStore.self) private var store

    var body: some View {
        NavigationLink(value: memo) {
            card
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Haptics.delete()
                store.delete(memo)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(highlighted)
                .font(.subheadline)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            if !memo.sortedImages.isEmpty {
                thumbGrid
            }

            HStack(spacing: 8) {
                Text(DateGrouper.timeLabel(for: memo.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if memo.updatedAt.timeIntervalSince(memo.createdAt) > 60 {
                    Text("已编辑")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .cardStyle()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
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
            tag.font = .subheadline.weight(.medium)
            result.append(tag)
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let plain = ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            result.append(AttributedString(plain))
        }
        return result
    }

    // MARK: - 缩略图

    private var thumbGrid: some View {
        let images = memo.sortedImages
        return HStack(spacing: 6) {
            ForEach(images.prefix(3)) { asset in
                Group {
                    if let thumb = store.imageStore.thumbnail(for: asset) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.tertiarySystemFill)
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if images.count > 3 {
                Text("+\(images.count - 3)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 84, height: 84)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
        }
    }
}
