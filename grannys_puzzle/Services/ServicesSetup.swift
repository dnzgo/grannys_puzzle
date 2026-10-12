import Foundation
import GameServices
import GameServicesFirebase

/// The game's analytics and remote values. Both nil when Firebase isn't
/// set up (no GoogleService-Info.plist), and in previews: the game works
/// the same without them, it just isn't measured or tuned.
struct AppServices {
    let events: EventLogger?
    let remoteValues: (any RemoteValueSource)?

    static let none = AppServices(events: nil, remoteValues: nil)
}

/// The one place that picks Firebase. Everything else in the app only
/// knows GameServices' types.
enum ServicesSetup {
    /// Starts Firebase. Must run before the ads controller's `start()`:
    /// Google's consent tool can only pass the player's choice on to
    /// Analytics once Firebase is running.
    static func start() -> AppServices {
        #if DEBUG
        // Your own testing would skew the numbers the game is tuned by, so
        // debug builds don't send events (they're still checked, so a bad
        // name stops the app here first). To watch events arrive in the
        // console's DebugView, set this to true and run with the launch
        // argument -FIRDebugEnabled.
        let collectsAnalytics = false
        // Fetch on every launch, so console changes show up at once.
        let fetchInterval: TimeInterval = 0
        #else
        let collectsAnalytics = true
        let fetchInterval: TimeInterval = 12 * 60 * 60
        #endif

        guard FirebaseServices.start(collectsAnalytics: collectsAnalytics) else { return .none }
        return AppServices(
            events: EventLogger(backend: FirebaseAnalyticsBackend()),
            remoteValues: FirebaseRemoteValues(minimumFetchInterval: fetchInterval)
        )
    }
}
