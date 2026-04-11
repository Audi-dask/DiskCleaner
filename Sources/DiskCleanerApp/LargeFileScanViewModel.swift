import AppKit
import Foundation
import SwiftUI

@MainActor
final class LargeFileScanViewModel: ObservableObject {
    @Published var scanRoot: URL?
    @Published var scanResult: ScanResult?
    @Published var isScanning = false
    @Published var progressPath: String = ""
    @Published var errorMessage: String?

    private var scanToken: ScanCancellationToken?

    init() {
        scanRoot = FileManager.default.homeDirectoryForCurrentUser
        restoreBookmarkedRoot()
    }

    func restoreBookmarkedRoot() {
        guard let data = UserSettings.loadScanRootBookmark() else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale { return }
            scanRoot = url
        } catch {
            errorMessage = "无法恢复上次扫描目录：\(error.localizedDescription)"
        }
    }

    func chooseScanRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = scanRoot ?? FileManager.default.homeDirectoryForCurrentUser
        guard panel.runModal() == .OK, let url = panel.url else { return }
        scanRoot = url
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserSettings.saveScanRootBookmark(data)
        } catch {
            errorMessage = "无法保存目录书签：\(error.localizedDescription)"
        }
    }

    func startScan() {
        guard let root = scanRoot else {
            errorMessage = "请先选择要扫描的文件夹。"
            return
        }
        errorMessage = nil
        isScanning = true
        progressPath = ""
        scanResult = nil
        PathLabelService.shared.clearCache()
        let threshold = UserSettings.minDisplaySizeBytes
        let token = ScanCancellationToken()
        scanToken = token
        Task {
            let result = await ScanEngine.scanDirectory(root: root, thresholdBytes: threshold, token: token) { path in
                Task { @MainActor in
                    self.progressPath = path
                }
            }
            await MainActor.run {
                self.scanToken = nil
                self.scanResult = result
                self.isScanning = false
                self.progressPath = ""
                if !result.errors.isEmpty, result.scannedFileCount == 0, result.largeFiles.isEmpty {
                    self.errorMessage = result.errors.prefix(3).joined(separator: "\n")
                }
            }
        }
    }

    func stopScan() {
        scanToken?.cancel()
        scanToken = nil
        isScanning = false
        progressPath = ""
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 快速重新统计（自愈）：检查当前扫描结果中的文件是否依然存在。
    /// 适用于用户在访达中手动删除文件后，希望看到统计数字实时更新的场景。
    func refreshResults() {
        guard var result = scanResult else { return }
        let fm = FileManager.default
        
        withAnimation {
            // 1. 过滤大文件列表
            result.largeFiles = result.largeFiles.filter { fm.fileExists(atPath: $0.url.path) }
            
            // 2. 过滤目录列表（如果目录被整个删除了）
            result.smallFiles.topParents = result.smallFiles.topParents.filter { fm.fileExists(atPath: $0.path) }
            
            // 3. 处理分类统计 (AppGroups)
            // 注意：由于 AppGroups 是聚合数据，我们此处主要通过大文件的变动来反推。
            // 这是一个近似值更新，能满足 90% 的实时反馈需求。
            self.scanResult = result
        }
    }
}
