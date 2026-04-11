import Foundation
import SwiftUI

enum UserSettings {
    private static let minSizeMBKey = "minDisplaySizeMB"
    private static let lastScanRootBookmarkKey = "lastScanRootBookmark"

    static var minDisplaySizeMB: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: minSizeMBKey)
            return v > 0 ? v : 100
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: minSizeMBKey)
        }
    }

    static var minDisplaySizeBytes: Int64 {
        Int64(minDisplaySizeMB) * 1_048_576
    }

    /// Persisted security-scoped bookmark for last chosen scan root (optional).
    static func saveScanRootBookmark(_ data: Data) {
        UserDefaults.standard.set(data, forKey: lastScanRootBookmarkKey)
    }

    static func loadScanRootBookmark() -> Data? {
        UserDefaults.standard.data(forKey: lastScanRootBookmarkKey)
    }

    private static let agreedDisclaimerKey = "agreedDisclaimer_v1"
    static var hasAgreedDisclaimer: Bool {
        get { UserDefaults.standard.bool(forKey: agreedDisclaimerKey) }
        set { UserDefaults.standard.set(newValue, forKey: agreedDisclaimerKey) }
    }
}
