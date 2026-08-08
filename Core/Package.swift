// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IPAAuditCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "IPAAuditCore", targets: ["IPAAuditCore"])],
    targets: [
        .target(name: "IPAAuditCore"),
        .testTarget(name: "IPAAuditCoreTests", dependencies: ["IPAAuditCore"]),
    ]
)
