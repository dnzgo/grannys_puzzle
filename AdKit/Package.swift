// swift-tools-version: 5.9
import PackageDescription

// Ads for any of our apps, in two layers:
// - AdKit: the rules every app wants (consent first, then the tracking
//   question, preloading and retrying rewarded ads, refreshing stale ones)
//   behind a small `AdNetwork` protocol. No ad SDK in it, so it builds and
//   tests on a Mac with `swift test`.
// - AdKitGoogle: the AdMob + Google consent (UMP) implementation of that
//   protocol. iOS only, because Google's SDKs are.
// An app links both and only talks to AdKit's types, except for the one
// line that creates the Google network. Swapping networks later means a new
// adapter target, not changes in every app.
let package = Package(
    name: "AdKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),  // so AdKit's tests run with `swift test` on a Mac
    ],
    products: [
        .library(name: "AdKit", targets: ["AdKit"]),
        .library(name: "AdKitGoogle", targets: ["AdKitGoogle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.0.0"),
    ],
    targets: [
        .target(name: "AdKit"),
        .target(
            name: "AdKitGoogle",
            dependencies: [
                "AdKit",
                // iOS only: Google ships no macOS build, and `swift test` on a
                // Mac compiles every target (AdKitGoogle's sources are wrapped
                // in `#if os(iOS)` for the same reason).
                .product(
                    name: "GoogleMobileAds",
                    package: "swift-package-manager-google-mobile-ads",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "GoogleUserMessagingPlatform",
                    package: "swift-package-manager-google-user-messaging-platform",
                    condition: .when(platforms: [.iOS])
                ),
            ]
        ),
        .testTarget(name: "AdKitTests", dependencies: ["AdKit"]),
    ]
)
