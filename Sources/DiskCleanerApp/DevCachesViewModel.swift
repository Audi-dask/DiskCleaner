import AppKit
import Foundation
import SwiftUI

@MainActor
final class DevCachesViewModel: ObservableObject {
    @Published private(set) var rulesDocument: DevCacheRulesDocument?
    @Published private(set) var scans: [DevCacheRuleScan] = []
    @Published var loadError: String?
    @Published var isMeasuring = false
    @Published var trashTarget: DevCacheRuleScan?
    @Published var trashError: String?
    @Published var lastTrashSuccessPath: String?

    func loadRules() {
        loadError = nil
        do {
            rulesDocument = try DevCacheRulesLoader.loadFromBundle()
            refreshSizes()
        } catch {
            loadError = error.localizedDescription
            rulesDocument = nil
            scans = []
        }
    }

    func refreshSizes() {
        guard let doc = rulesDocument else { return }
        isMeasuring = true
        trashError = nil
        Task {
            var next: [DevCacheRuleScan] = []
            next.reserveCapacity(doc.rules.count)
            let skipRecursiveIds: Set<String> = ["application-support-generic"]
            for rule in doc.rules {
                let url = ScanEngine.expandPath(rule.path)
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if skipRecursiveIds.contains(rule.id) {
                    next.append(
                        DevCacheRuleScan(
                            rule: rule,
                            resolvedURL: url,
                            exists: exists,
                            totalBytes: 0,
                            itemCount: 0,
                            errorMessage: exists ? "未递归统计（目录范围过大）" : nil
                        )
                    )
                    continue
                }
                if !exists {
                    next.append(
                        DevCacheRuleScan(
                            rule: rule,
                            resolvedURL: url,
                            exists: false,
                            totalBytes: 0,
                            itemCount: 0,
                            errorMessage: nil
                        )
                    )
                    continue
                }
                let tuple = await Task.detached {
                    ScanEngine.directorySize(at: url)
                }.value
                next.append(
                    DevCacheRuleScan(
                        rule: rule,
                        resolvedURL: url,
                        exists: true,
                        totalBytes: tuple.bytes,
                        itemCount: tuple.count,
                        errorMessage: tuple.error
                    )
                )
            }
            await MainActor.run {
                self.scans = next
                self.isMeasuring = false
            }
        }
    }

    func reveal(_ scan: DevCacheRuleScan) {
        guard let u = scan.resolvedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([u])
    }

    func requestTrash(_ scan: DevCacheRuleScan) {
        trashError = nil
        lastTrashSuccessPath = nil
        guard scan.rule.category == .safeToDelete else { return }
        guard scan.exists, scan.resolvedURL != nil else { return }
        trashTarget = scan
    }

    func confirmTrash() {
        guard let scan = trashTarget, let url = scan.resolvedURL else {
            trashTarget = nil
            return
        }
        trashTarget = nil
        do {
            try ScanEngine.moveToTrash(url: url)
            lastTrashSuccessPath = url.path
            refreshSizes()
        } catch {
            trashError = error.localizedDescription
        }
    }

    func cancelTrash() {
        trashTarget = nil
    }
}
