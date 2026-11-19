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
            path: "tests/SerenixCoreTests",
            resources: [.copy("Fixtures")]
        ),
        // The sleep accuracy harness (spec 019): developer-only, never linked into the app.
        // Foundation and SerenixCore only.
        .target(
            name: "SleepAccuracy",
            dependencies: ["SerenixCore"],
            path: "src/SleepAccuracy"
        ),
        .executableTarget(
            name: "sleep-accuracy",
            dependencies: ["SleepAccuracy"],
            path: "src/sleep-accuracy"
        ),
        .testTarget(
            name: "SleepAccuracyTests",
            dependencies: ["SleepAccuracy", "SerenixCore"],
            path: "tests/SleepAccuracyTests"
        ),
    ]
)
