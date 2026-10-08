// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileFlyfer",
    defaultLocalization: "tr",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FileFlyfer", targets: ["FileFlyfer"])
    ],
    targets: [
        .executableTarget(
            name: "FileFlyfer",
            path: "Sources/FileFlyfer",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FileFlyferTests",
            dependencies: ["FileFlyfer"],
            path: "Tests/FileFlyferTests"
        )
    ]
)
