// swift-tools-version: 5.9
import PackageDescription

// Analytics and remotely tuned values for any of our games, in two layers
// (the same shape as AdKit):
// - GameServices: the app-facing types (an analytics event checked against
//   Google Analytics' naming rules, an event logger, a source of remote
//   values) with no SDK inside, so it builds and tests on a Mac.
// - GameServicesFirebase: Firebase's implementation (Analytics, Remote
//   Config, and Crashlytics, which reports crashes once it's started). iOS
//   only, matching how the app uses it.
// An app talks to GameServices' types everywhere except the one setup file
// that picks Firebase.
let package = Package(
    name: "GameServices",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),  // so GameServices' tests run with `swift test` on a Mac
    ],
    products: [
        .library(name: "GameServices", targets: ["GameServices"]),
        .library(name: "GameServicesFirebase", targets: ["GameServicesFirebase"]),
    ],
    dependencies: [
        // 12.19.2 (Sept 2026); 13.0 was days old when this was set up.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.19.2"),
    ],
    targets: [
        .target(name: "GameServices"),
        .target(
            name: "GameServicesFirebase",
            dependencies: [
                "GameServices",
                // iOS only, like AdKitGoogle: `swift test` on a Mac compiles
                // every target, and this one's sources are `#if os(iOS)`.
                .product(name: "FirebaseCore", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk", condition: .when(platforms: [.iOS])),
            ]
        ),
        .testTarget(name: "GameServicesTests", dependencies: ["GameServices"]),
    ]
)
