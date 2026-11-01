// swift-tools-version: 6.0
// The Engine: every Hybrid 12 program rule as pure, UI-free Swift.
// The iOS app (milestone 2) adds this package as a local dependency.
import PackageDescription

let package = Package(
    name: "Hybrid12Engine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Hybrid12Engine", targets: ["Hybrid12Engine"]),
    ],
    targets: [
        .target(
            name: "Hybrid12Engine",
            path: "Engine",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "EngineTests",
            dependencies: ["Hybrid12Engine"],
            path: "Tests/EngineTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
