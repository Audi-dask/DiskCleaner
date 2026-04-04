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
}
