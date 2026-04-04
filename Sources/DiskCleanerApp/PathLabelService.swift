import AppKit
import Foundation

/// 将长路径解析为一行友好说明。规则主要来自 `path_label_rules.json`（按顺序首个匹配）；
/// 含 `{appName}`、`{groupFolder}` 的条目由本类结合系统已安装应用解析。
final class PathLabelService {
    static let shared = PathLabelService()

    private var bundleDisplayNameCache: [String: String] = [:]
    private let lock = NSLock()

    private lazy var rulesDocument: PathLabelRulesDocument = {
        if let doc = PathLabelRulesLoader.loadFromBundle() {
            return doc
        }
        if let doc = Self.decodeEmbeddedFallback() {
            return doc
        }
        return PathLabelRulesDocument(version: 0, rules: [])
    }()

    func clearCache() {
        lock.lock()
        bundleDisplayNameCache.removeAll()
        lock.unlock()
    }

    /// 表格「说明」列用的一行文案。
    func line(forPath path: String) -> String {
        for rule in rulesDocument.rules {
            if let s = apply(rule: rule, path: path) {
                return s
            }
        }
        return "—"
    }

    private func apply(rule: PathLabelRuleRow, path: String) -> String? {
        guard path.contains(rule.ifContains) else { return nil }
        if let also = rule.ifAlsoContains, !path.contains(also) {
            return nil
        }
        switch rule.context ?? "" {
        case "":
            return rule.label
        case "container":
            guard let bid = Self.extractContainerBundleId(path: path) else { return nil }
            let name = displayName(forBundleIdentifier: bid)
            return rule.label.replacingOccurrences(of: "{appName}", with: name)
        case "groupResolved":
            guard let suffix = Self.extractGroupBundleSuffix(path: path) else { return nil }
            let name = displayName(forBundleIdentifier: suffix)
            return rule.label.replacingOccurrences(of: "{appName}", with: name)
        case "groupFallback":
            guard let folder = Self.extractGroupFolderName(path: path) else { return nil }
            return rule.label.replacingOccurrences(of: "{groupFolder}", with: folder)
        default:
            return rule.label
        }
    }

    // MARK: - 路径解析（与 JSON 规则配合）

    private static func extractContainerBundleId(path: String) -> String? {
        let marker = "/Library/Containers/"
        guard let range = path.range(of: marker) else { return nil }
        let rest = path[range.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let bundleId = String(rest[..<slash])
        guard !bundleId.isEmpty, bundleId.contains(".") else { return nil }
        return bundleId
    }

    private static func extractGroupFolderName(path: String) -> String? {
        let marker = "/Library/Group Containers/"
        guard let range = path.range(of: marker) else { return nil }
        let rest = path[range.upperBound...]
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        let folder = String(rest[..<slash])
        return folder.isEmpty ? nil : folder
    }

    /// `group.com.example.app` → `com.example.app`；无法解析则 nil（交给下一条规则）。
    private static func extractGroupBundleSuffix(path: String) -> String? {
        guard let folder = extractGroupFolderName(path: path) else { return nil }
        guard folder.hasPrefix("group."), folder.count > 6 else { return nil }
        let suffix = String(folder.dropFirst(6))
        guard suffix.contains(".") else { return nil }
        return suffix
    }

    private func displayName(forBundleIdentifier bundleId: String) -> String {
        lock.lock()
        if let cached = bundleDisplayNameCache[bundleId] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let resolved: String
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appURL)
        {
            let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            if let d = display, !d.isEmpty {
                resolved = d
            } else if let n = name, !n.isEmpty {
                resolved = n
            } else {
                resolved = bundleId
            }
        } else {
            resolved = bundleId
        }

        lock.lock()
        bundleDisplayNameCache[bundleId] = resolved
        lock.unlock()
        return resolved
    }

    /// Bundle 内 JSON 缺失或损坏时的兜底（与 `path_label_rules.json` 内容保持一致）。
    private static func decodeEmbeddedFallback() -> PathLabelRulesDocument? {
        let data = Data(embeddedFallbackJSON.utf8)
        return try? JSONDecoder().decode(PathLabelRulesDocument.self, from: data)
    }

    private static let embeddedFallbackJSON = """
    {"version":1,"rules":[
    {"id":"ollama-blob","ifContains":"/.ollama/models/","ifAlsoContains":"/blobs/sha256-","label":"Ollama 模型数据"},
    {"id":"ollama-models-root","ifContains":"/.ollama/models/","label":"Ollama 数据目录"},
    {"id":"container-wechat-xwechat","ifContains":"/Library/Containers/","ifAlsoContains":"xwechat_files","label":"{appName} · 用户数据（含聊天记录等，勿随意删除）","context":"container"},
    {"id":"container-sandbox-caches","ifContains":"/Library/Containers/","ifAlsoContains":"/Data/Library/Caches/","label":"{appName} · 沙盒缓存","context":"container"},
    {"id":"container-default","ifContains":"/Library/Containers/","label":"{appName} · 沙盒数据","context":"container"},
    {"id":"group-container-with-bundle","ifContains":"/Library/Group Containers/","label":"{appName} · 共享容器（Group Container）","context":"groupResolved"},
    {"id":"group-container-fallback","ifContains":"/Library/Group Containers/","label":"共享容器 · {groupFolder}","context":"groupFallback"}
    ]}
    """
}

extension LargeFileEntry {
    var friendlyPathLabel: String {
        PathLabelService.shared.line(forPath: url.path)
    }
}
