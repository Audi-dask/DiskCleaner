import Foundation

// MARK: - File Logger

struct FileLogger {
    static let logPath = "/tmp/diskcleaner.log"
    
    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if !FileManager.default.fileExists(atPath: logPath) {
                FileManager.default.createFile(atPath: logPath, contents: data)
            } else if let handle = FileHandle(forWritingAtPath: logPath) {
                try? handle.seekToEnd()
                handle.write(data)
                try? handle.close()
            }
        }
    }
}

// MARK: - Cancellation token

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

    private static func isSensitivePath(_ path: String) -> Bool {
        let p = path.lowercased()
        
        // 关键路径关键词排除（只要路径包含以下关键词，立即跳过）
        let sensitiveKeywords = [
            "/library/mobile documents", "/library/cloudstorage", ".photoslibrary",
            "/library/messages", "/library/mail", "/library/safari", "/library/calendars",
            "/library/homekit", "/library/sharing", "/library/suggestions", "/library/weather",
            "/library/shortcuts", "/library/personalizationportrait", "/library/metadata/corespotlight",
            "/library/trial", "/library/biome", "/library/accounts", "/library/intelligenceplatform",
            "/library/applemediaservices", "/library/duetexpertcenter", "/library/assistant",
            "/library/daemon containers", "/library/autosave information", "/library/identityservices",
            "/library/intents", "/library/caches/profiles/web_shel1", "/code cache/js",
            "mobilesync", "com.apple.tcc", "addressbook", "callhistory", "clouddocs", "knowledge",
            "com.apple.sharedfilelist", "fileprovider", "facetime", "differentialprivacy",
            "com.apple.avfoundation", "com.apple.aiml.instrumentation", "com.apple.mailpersonastorage",
            "com.apple.music", "com.apple.photo", "com.apple.itunes", "com.apple.assets",
            "com.apple.homed", "com.apple.media", "com.apple.quicklook", "com.apple.reminders",
            "/containers/com.apple.", "/group containers/group.com.apple.", "/music/music", "/.trash"
        ]
        
        for kw in sensitiveKeywords {
            if p.contains(kw) { return true }
        }
        return false
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

        // FileLogger.log(">>> 开始扫描: \(root.path) (阈值: \(ByteFormat.string(fromBytes: thresholdBytes)))")

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                // 再次加固：如果路径包含任何敏感词，绝对不打印日志
                if !isSensitivePath(url.path) {
                    FileLogger.log("[DENIED/ERROR] 目录访问被拒: \(url.path) - \(error.localizedDescription)")
                }
                return true // 继续扫描其他目录
            }
        ) else {
            FileLogger.log("[FATAL] 无法启动枚举器，根目录可能无权限: \(root.path)")
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
         // 统计所有父目录，由视图决定展示范围
        let topParents = pickTopParents(from: parentAgg)
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

    private static func pickTopParents(from agg: [String: (bytes: Int64, count: Int)]) -> [ParentDirSummary] {
        guard !agg.isEmpty else { return [] }
        return agg
            .map { ParentDirSummary(path: $0.key, totalBytes: $0.value.bytes, fileCount: $0.value.count, groupKey: extractGroupKey(from: $0.key)) }
            .sorted { ($0.totalBytes, $0.fileCount) > ($1.totalBytes, $1.fileCount) }
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

            // --- 排除逻辑：iCloud, 照片库, 云存储, 以及系统隐私限制目录 ---
            if isSensitivePath(url.path) {
                // FileLogger.log("[EXCLUDE] 跳过系统隐私限制目录: \(url.path)")
                enumerator.skipDescendants()
                continue
            }

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
                
                // 额外的文件名过滤 (可选：排除临时下载或正在同步的文件)
                if url.lastPathComponent.hasPrefix(".icloud") {
                    continue
                }

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
                FileLogger.log("[ERROR] 访问错误: \(url.path) - \(error.localizedDescription)")
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
            includingPropertiesForKeys: nil, // 同样不预取
            options: [.skipsPackageDescendants],
            errorHandler: { (u, error) -> Bool in
                if !isSensitivePath(u.path) {
                    FileLogger.log("[DENIED/SIZE] 测算中目录访问被拒: \(u.path) - \(error.localizedDescription)")
                }
                return true
            }
        ) else {
            return (0, 0, "无法读取目录")
        }

        for case let u as URL in en {
            // 路径排除
            if isSensitivePath(u.path) {
                // FileLogger.log("[EXCLUDE/SIZE] 测算中静默跳过敏感目录: \(u.path)")
                en.skipDescendants()
                continue
            }

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
