// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskCleanerApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DiskCleanerApp", targets: ["DiskCleanerApp"]),
    ],
    targets: [
        .executableTarget(
            name: "DiskCleanerApp",
            path: "Sources/DiskCleanerApp",
            resources: [.process("Resources")]
        ),
    ]
)
