import Foundation

extension Bundle {
    /// 安全地获取资源 URL，避免 Bundle.module 触发 fatalError 闪退。
    /// 逻辑：
    /// 1. 尝试在主包中寻找。
    /// 2. 尝试在 SPM 自动生成的资源包中寻找。
    /// 3. 如果找不到，返回 nil 而不是崩溃。
    static func safeURL(forResource name: String, withExtension ext: String?) -> URL? {
        // 1. 优先从主包中寻找 (对于已平铺资源的常规 App 包有效)
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        
        // 2. 尝试寻找 SPM 特有的资源包
        // 注意：模块名固定为 DiskCleanerApp
        let bundleName = "DiskCleanerApp_DiskCleanerApp"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL
        ]
        
        for candidate in candidates {
            if let bundleURL = candidate, let b = Bundle(url: bundleURL) {
                if let url = b.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        
        return nil
    }
}
