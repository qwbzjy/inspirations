import Foundation

/// flomo 式 #标签 解析与内容重写
enum TagParser {
    /// 匹配 #标签：标签内容不含空白、# 与换行，允许 / 层级
    static let pattern = "#([^\\s#\\n]+)"

    /// 标签尾部需要剔除的中英文标点（如 #想法。 → 想法）
    private static let trailingPunctuation: Set<Character> = [
        "。", "．", ".", "，", ",", "、", ";", "；", "!", "！", "?", "？",
        ":", "：", ")", "）", "]", "】", "}", "」", "』", "\"", "'",
        "‘", "’", "“", "”", "…", "~", "～",
    ]

    /// 标签结束边界：空白、#、标点或结尾。注意不含 / —— 保护子标签
    private static let boundary = "(?=[\\s#。，．,、;；:：!！?？)）]】}」』\"'‘’“”…~～.]|$)"

    /// 重命名边界：额外允许 / 结尾，使子树整体改名
    private static let boundaryWithSlash = "(?=[/\\s#。，．,、;；:：!！?？)）]】}」』\"'‘’“”…~～.]|$)"

    /// 从内容中提取标签路径（去重、保序）
    static func extractTags(from content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            var raw = ns.substring(with: match.range(at: 1))
            while let last = raw.last, trailingPunctuation.contains(last) {
                raw.removeLast()
            }
            while raw.hasSuffix("/") { raw.removeLast() }
            if raw.isEmpty { continue }
            if seen.insert(raw).inserted {
                result.append(raw)
            }
        }
        return result
    }

    /// 将内容中的 #old 前缀重写为 #new（含子标签：#old/child → #new/child）
    static func replacingTag(_ old: String, with new: String, in content: String) -> String {
        guard !old.isEmpty else { return content }
        let escaped = NSRegularExpression.escapedPattern(for: old)
        let pattern = "#\(escaped)\(boundaryWithSlash)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return content }
        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(
            in: content, range: range,
            withTemplate: "#\(templateEscape(new))"
        )
    }

    /// 从内容中移除精确标签（子标签 #path/child 不受影响），并吞掉尾随的一个空格
    static func removingTag(_ path: String, in content: String) -> String {
        guard !path.isEmpty else { return content }
        let escaped = NSRegularExpression.escapedPattern(for: path)
        let pattern = "#\(escaped) ?\(boundary)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return content }
        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "")
    }

    /// 替换模板转义（$ 与 \ 在 ICU 模板中有特殊含义）
    private static func templateEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
    }
}
