import Foundation

// MARK: - Cancellation token（线程安全，不依赖 Atomics 包）

final class ScanCancellationToken: @unchecked Sendable {
    private var _cancelled = false
    private let lock = NSLock()

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _cancelled
    }

    func cancel() {
        lock.lock(); _cancelled = true; lock.unlock()
    }
}

enum ScanEngine {
    static func scanDirectory(
        root: URL,
        thresholdBytes: Int64,
        token: ScanCancellationToken = ScanCancellationToken(),
        progress: (@Sendable (String) -> Void)? = nil
    ) async -> ScanResult {
        await Task.detached(priority: .userInitiated) {
            performScan(root: root, thresholdBytes: thresholdBytes, token: token, progress: progress)
        }.value
    }

    private static func performScan(
        root: URL,
        thresholdBytes: Int64,
        token: ScanCancellationToken,
        progress: (@Sendable (String) -> Void)?
    ) -> ScanResult {
        let fm = FileManager.default
        var largeFiles: [LargeFileEntry] = []
        var smallCount = 0
        var smallBytes: Int64 = 0
        var parentAgg: [String: (bytes: Int64, count: Int)] = [:]
        var scannedCount = 0
        var errors: [String] = []
        var lastProgress = Date()

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
        ]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else {
            return ScanResult(
                rootURL: root,
                thresholdBytes: thresholdBytes,
                largeFiles: [],
                smallFiles: SmallFilesAggregate(
                    count: 0,
                    totalBytes: 0,
                    topParents: [],
                    appGroups: []
                ),
                scannedFileCount: 0,
                errors: ["无法枚举目录：\(root.path)"]
            )
        }

        let scoped = root.startAccessingSecurityScopedResource()
        defer {
            if scoped { root.stopAccessingSecurityScopedResource() }
        }
        scanLoop(
            enumerator: enumerator,
            thresholdBytes: thresholdBytes,
            token: token,
            largeFiles: &largeFiles,
            smallCount: &smallCount,
            smallBytes: &smallBytes,
            parentAgg: &parentAgg,
            scannedCount: &scannedCount,
            errors: &errors,
            lastProgress: &lastProgress,
            progress: progress
        )

        largeFiles.sort { $0.size > $1.size }
         // 展示统计前20个父目录，方便用户快速定位小文件密集区域
        let topParents = pickTopParents(from: parentAgg, count: 100)
        let appGroups = buildAppGroups(from: parentAgg)

        let aggregate = SmallFilesAggregate(
            count: smallCount,
            totalBytes: smallBytes,
            topParents: topParents,
            appGroups: appGroups
        )

        return ScanResult(
            rootURL: root,
            thresholdBytes: thresholdBytes,
            largeFiles: largeFiles,
            smallFiles: aggregate,
            scannedFileCount: scannedCount,
            errors: errors
        )
    }

    private static func pickTopParents(from agg: [String: (bytes: Int64, count: Int)], count: Int) -> [ParentDirSummary] {
        guard !agg.isEmpty else { return [] }
        return agg
            .map { ParentDirSummary(path: $0.key, totalBytes: $0.value.bytes, fileCount: $0.value.count, groupKey: extractGroupKey(from: $0.key)) }
            .sorted { ($0.totalBytes, $0.fileCount) > ($1.totalBytes, $1.fileCount) }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - App Grouping

    private static func buildAppGroups(from parentAgg: [String: (bytes: Int64, count: Int)]) -> [AppGroup] {
        var grouped: [String: (bytes: Int64, fileCount: Int, dirCount: Int)] = [:]
        for (path, v) in parentAgg {
            let key = extractGroupKey(from: path)
            let cur = grouped[key] ?? (0, 0, 0)
            grouped[key] = (cur.bytes + v.bytes, cur.fileCount + v.count, cur.dirCount + 1)
        }
        return grouped
            .map { AppGroup(name: $0.key, totalBytes: $0.value.bytes, fileCount: $0.value.fileCount, dirCount: $0.value.dirCount) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    private static let domainPrefixes = ["com.", "org.", "io.", "net.", "me.", "dev.", "app.", "co."]
    private static let libraryKnownSections: Set<String> = [
        "Caches", "Application Support", "Containers", "Group Containers",
        "Preferences", "Logs", "Saved Application State", "HTTPStorages",
        "WebKit", "Cookies",
    ]

    private static func extractGroupKey(from path: String) -> String {
        let components = path.split(separator: "/").map(String.init)

        for comp in components {
            let lower = comp.lowercased()
            if domainPrefixes.contains(where: { lower.hasPrefix($0) }) {
                return comp
            }
        }

        if let libIdx = components.firstIndex(of: "Library") {
            if libIdx + 1 < components.count {
                let section = components[libIdx + 1]
                if libraryKnownSections.contains(section), libIdx + 2 < components.count {
                    return components[libIdx + 2]
                }
                if section == "Developer", libIdx + 2 < components.count {
                    return components[libIdx + 2]
                }
                return section
            }
        }

        if let usersIdx = components.firstIndex(of: "Users"),
           usersIdx + 2 < components.count
        {
            let afterHome = components[usersIdx + 2]
            if afterHome.hasPrefix(".") && afterHome.count > 1 {
                return afterHome
            }
            return afterHome
        }

        if components.count > 2 {
            return components[2]
        }
        return path
    }

    private static func scanLoop(
        enumerator: FileManager.DirectoryEnumerator,
        thresholdBytes: Int64,
        token: ScanCancellationToken,
        largeFiles: inout [LargeFileEntry],
        smallCount: inout Int,
        smallBytes: inout Int64,
        parentAgg: inout [String: (bytes: Int64, count: Int)],
        scannedCount: inout Int,
        errors: inout [String],
        lastProgress: inout Date,
        progress: (@Sendable (String) -> Void)?
    ) {
        while let url = enumerator.nextObject() as? URL {
            if token.isCancelled { break }
            do {
                let rv = try url.resourceValues(forKeys: [
                    .isRegularFileKey,
                    .isDirectoryKey,
                    .fileSizeKey,
                    .totalFileAllocatedSizeKey,
                    .contentModificationDateKey,
                ])

                if rv.isDirectory == true {
                    continue
                }
                guard rv.isRegularFile == true else { continue }

                let size: Int64
                if let alloc = rv.totalFileAllocatedSize {
                    size = Int64(alloc)
                } else if let fs = rv.fileSize {
                    size = Int64(fs)
                } else {
                    size = 0
                }

                scannedCount += 1

                if size >= thresholdBytes {
                    largeFiles.append(
                        LargeFileEntry(
                            id: UUID(),
                            url: url,
                            size: size,
                            modificationDate: rv.contentModificationDate
                        )
                    )
                } else {
                    smallCount += 1
                    smallBytes += size
                    let parentPath = url.deletingLastPathComponent().path
                    let cur = parentAgg[parentPath] ?? (0, 0)
                    parentAgg[parentPath] = (cur.bytes + size, cur.count + 1)
                }

                if let progress, Date().timeIntervalSince(lastProgress) > 0.25 {
                    lastProgress = Date()
                    progress(url.path)
                }
            } catch {
                errors.append("\(url.path): \(error.localizedDescription)")
                if errors.count > 200 {
                    errors.append("… 错误过多，已截断")
                    break
                }
            }
        }
    }

    /// Size of file or directory tree (best effort).
    static func directorySize(at url: URL) -> (bytes: Int64, count: Int, error: String?) {
        let fm = FileManager.default
        var total: Int64 = 0
        var count = 0

        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access { url.stopAccessingSecurityScopedResource() }
        }

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return (0, 0, "路径不存在")
        }

        if !isDir.boolValue {
            do {
                let rv = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                let s: Int64
                if let a = rv.totalFileAllocatedSize {
                    s = Int64(a)
                } else if let f = rv.fileSize {
                    s = Int64(f)
                } else {
                    s = 0
                }
                return (s, 1, nil)
            } catch {
                return (0, 0, error.localizedDescription)
            }
        }

        guard let en = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return (0, 0, "无法读取目录")
        }

        for case let u as URL in en {
            do {
                let rv = try u.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey])
                guard rv.isRegularFile == true else { continue }
                count += 1
                if let a = rv.totalFileAllocatedSize {
                    total += Int64(a)
                } else if let f = rv.fileSize {
                    total += Int64(f)
                }
            } catch {
                return (total, count, error.localizedDescription)
            }
        }
        return (total, count, nil)
    }

    static func expandPath(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    static func moveToTrash(url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}
