// swift-tools-version: 5.9
import PackageDescription

// The game rules live in their own package, separate from the iOS app:
// - they have no UI or SDK dependencies, so they're fast to unit-test;
// - `swift test` runs them on a Mac without a simulator;
// - the app target simply depends on this library.
let package = Package(
    name: "ArrowwordCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),  // so the tests also run with `swift test` on a Mac
    ],
    products: [
        .library(name: "ArrowwordCore", targets: ["ArrowwordCore"]),
    ],
    targets: [
        .target(name: "ArrowwordCore"),
        .testTarget(
            name: "ArrowwordCoreTests",
            dependencies: ["ArrowwordCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
