// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Serenix",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SerenixCore", targets: ["SerenixCore"])
    ],
    targets: [
        // Foundation only, so it builds and tests on Windows and Linux (docs/adr/0002).
        .target(name: "SerenixCore", path: "src/SerenixCore"),
        .testTarget(
            name: "SerenixCoreTests",
            dependencies: ["SerenixCore"],
            path: "tests/SerenixCoreTests"
        ),
    ]
)
