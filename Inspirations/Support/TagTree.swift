import Foundation
import SwiftData

/// 侧栏标签树的节点（缺失的父节点为合成节点）
struct TagNode: Identifiable {
    let path: String
    let name: String
    let colorIndex: Int
    let isSynthesized: Bool
    let memoCount: Int
    var children: [TagNode]

    var id: String { path }
}

enum TagTree {
    /// 从标签实体构建树：合成缺失的祖先节点，计数向下汇总
    static func build(from tags: [Tag]) -> [TagNode] {
        var counts: [String: Int] = [:]
        var colors: [String: Int] = [:]
        var synthesized: Set<String> = []

        for tag in tags {
            counts[tag.path, default: 0] += tag.memos.count
            if colors[tag.path] == nil { colors[tag.path] = tag.colorIndex }
        }

        // 补齐祖先节点
        for tag in tags {
            var path = tag.path
            while let parent = parentPath(of: path) {
                if counts[parent] == nil {
                    counts[parent] = 0
                    synthesized.insert(parent)
                }
                if colors[parent] == nil { colors[parent] = tag.colorIndex }
                path = parent
            }
        }

        func directChildren(of path: String) -> [String] {
            let prefix = path + "/"
            return counts.keys.filter { key in
                guard key.hasPrefix(prefix) else { return false }
                return !key.dropFirst(prefix.count).contains("/")
            }
        }

        func makeNode(path: String) -> TagNode {
            let childNodes = directChildren(of: path)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map(makeNode)
            let own = counts[path] ?? 0
            let total = own + childNodes.reduce(0) { $0 + $1.memoCount }
            let name = path.split(separator: "/").last.map(String.init) ?? path
            return TagNode(
                path: path,
                name: name,
                colorIndex: colors[path] ?? 0,
                isSynthesized: synthesized.contains(path),
                memoCount: total,
                children: childNodes
            )
        }

        let roots = counts.keys
            .filter { !$0.contains("/") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return roots.map(makeNode)
    }

    private static func parentPath(of path: String) -> String? {
        guard let index = path.lastIndex(of: "/") else { return nil }
        return String(path[..<index])
    }
}
