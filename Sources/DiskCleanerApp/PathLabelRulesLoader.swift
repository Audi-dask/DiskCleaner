import Foundation

struct PathLabelRulesDocument: Codable, Sendable {
    let version: Int
    let rules: [PathLabelRuleRow]
}

/// 单条路径说明规则（由 JSON 驱动，按数组顺序 **首个匹配生效**）。
struct PathLabelRuleRow: Codable, Sendable {
    let id: String
    let ifContains: String
    let ifAlsoContains: String?
    let label: String
    /// `container`：从 `/Library/Containers/<bundleId>/` 解析 `{appName}`。
    /// `groupResolved`：`group.xxx.yyy` 且可解析出 bundle 后缀时替换 `{appName}`，否则本条不匹配。
    /// `groupFallback`：替换 `{groupFolder}` 为 Group Containers 下文件夹名。
    let context: String?
}

enum PathLabelRulesLoader {
    static func loadFromBundle() -> PathLabelRulesDocument? {
        guard let url = Bundle.safeURL(forResource: "path_label_rules", withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PathLabelRulesDocument.self, from: data)
    }
}
