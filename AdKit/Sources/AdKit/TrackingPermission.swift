import AppTrackingTransparency
#if canImport(UIKit)
import UIKit
#endif

/// iOS's "Allow this app to track your activity?" question (App Tracking
/// Transparency). A protocol so tests can check *when* it's asked without
/// a real prompt.
@MainActor
public protocol TrackingPermission {
    /// Asks, if the player hasn't answered before. Their answer only changes
    /// whether ads may be personalised; ads show either way.
    func requestIfNeeded() async
}

/// The real question, through Apple's framework.
///
/// The app's Info.plist needs `NSUserTrackingUsageDescription` (the text in
/// the prompt), or iOS stops the app when this is called.
public struct SystemTrackingPermission: TrackingPermission {
    // Nonisolated so it can be a default argument (AdsController's init):
    // default arguments are evaluated outside the main actor, and this
    // type is main-actor only because its protocol is. Creating it touches
    // no state, so that's safe.
    nonisolated public init() {}

    public func requestIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        #if canImport(UIKit)
        // iOS silently ignores the request (no prompt, the answer stays "not
        // determined") unless the app is active, and right after a consent
        // form closes it can be inactive for a moment. Wait up to 2 seconds.
        var waited = 0
        while UIApplication.shared.applicationState != .active, waited < 20 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        #endif
        // The answer is recorded by iOS and read by the ad SDK; AdKit doesn't
        // need it.
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
