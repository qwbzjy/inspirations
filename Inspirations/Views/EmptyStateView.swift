import SwiftUI

/// 列表空态引导

@MainActor
struct EmptyStateView: View {
    let filter: MemoFilter
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if filter == .all && !hasSearch {
                Text("随手记下每一个灵感\n用 #标签 归类，用 🎤 语音速记")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var title: String {
        if hasSearch { return "没有匹配的灵感" }
        switch filter {
        case .all: return "还没有灵感"
        case .untagged: return "没有无标签的灵感"
        case .tag(let path): return "#\(path) 下暂无灵感"
        }
    }
}
