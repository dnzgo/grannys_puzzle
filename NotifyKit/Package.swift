// swift-tools-version: 5.9
import PackageDescription

// Local reminders for any of our games ("your jar is ready, dear"):
// asking permission at a good moment, keeping lines from repeating, and
// rules that stop a game from nagging (a delivery window, one a day, quiet
// after a long absence).
//
// One target: Apple's notification framework exists on macOS too, so the
// whole package builds and tests there with `swift test`. The tests never
// touch the real notification centre; they use a fake scheduler.
//
// Push notifications (sent from a server) aren't here yet. When they're
// needed they'll come as a second target, the way AdKitGoogle sits beside
// AdKit, so apps that only want local reminders don't pull in Firebase.
let package = Package(
    name: "NotifyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NotifyKit", targets: ["NotifyKit"]),
    ],
    targets: [
        .target(name: "NotifyKit"),
        .testTarget(name: "NotifyKitTests", dependencies: ["NotifyKit"]),
    ]
)
