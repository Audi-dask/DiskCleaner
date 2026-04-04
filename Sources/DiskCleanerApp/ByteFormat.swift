import Foundation

enum ByteFormat {
    static func string(fromBytes bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
