import Foundation

struct LargeFileEntry: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let size: Int64
    let modificationDate: Date?

    var pathDisplay: String {
        url.path
    }
}

struct ParentDirSummary: Hashable, Identifiable {
    let path: String
    let totalBytes: Int64
    let fileCount: Int
    let groupKey: String
    var id: String { path }
}

struct AppGroup: Hashable, Identifiable {
    let name: String
    let totalBytes: Int64
    let fileCount: Int
    let dirCount: Int
    var id: String { name }
}

struct SmallFilesAggregate: Hashable {
    var count: Int
    var totalBytes: Int64
    /// 按合计字节降序排列的 top 父目录列表。
    var topParents: [ParentDirSummary]
    /// 按应用/标识聚合的分组，按字节降序。
    var appGroups: [AppGroup]
}

struct ScanResult: Sendable {
    var rootURL: URL
    var thresholdBytes: Int64
    var largeFiles: [LargeFileEntry]
    var smallFiles: SmallFilesAggregate
    var scannedFileCount: Int
    var errors: [String]
}

enum DevCacheCategory: String, Codable, CaseIterable, Sendable {
    case safeToDelete
    case useWithCaution
    case doNotDelete

    var displayName: String {
        switch self {
        case .safeToDelete: return "可清理"
        case .useWithCaution: return "谨慎"
        case .doNotDelete: return "禁止清理"
        }
    }
}

struct DevCacheRule: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let path: String
    let category: DevCacheCategory
    let title: String
    let description: String
}

struct DevCacheRulesDocument: Codable, Sendable {
    let version: Int
    let rules: [DevCacheRule]
}

struct DevCacheRuleScan: Identifiable, Hashable {
    var id: String { rule.id }
    var rule: DevCacheRule
    var resolvedURL: URL?
    var exists: Bool
    var totalBytes: Int64
    var itemCount: Int
    var errorMessage: String?
}
