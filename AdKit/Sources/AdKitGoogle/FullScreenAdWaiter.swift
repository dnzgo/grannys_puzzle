#if os(iOS)
import GoogleMobileAds
import UIKit

/// Turns AdMob's "the ad closed" delegate callback into an `await`, for any
/// full-screen ad (rewarded or interstitial).
///
/// AdMob holds its delegate weakly, so whoever owns the ad must keep this
/// object alive (a stored property) for as long as the ad is on screen.
@MainActor
final class FullScreenAdWaiter: NSObject, FullScreenContentDelegate {
    private var continuation: CheckedContinuation<Bool, Never>?

    /// Runs `present` and waits until the ad is closed. Returns true if it
    /// was shown and closed, false if it couldn't be shown.
    func presentAndWait(_ present: () -> Void) async -> Bool {
        // Each ad is shown once; a second call has nothing to wait for.
        guard continuation == nil else { return false }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    // MARK: - FullScreenContentDelegate

    // Google calls these on the main thread (guaranteed since SDK 13), but
    // its protocol isn't marked main-actor, so they're declared nonisolated
    // and step onto the main actor explicitly.

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated { finish(shown: true) }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        MainActor.assumeIsolated { finish(shown: false) }
    }

    /// Resumes the waiting call exactly once.
    private func finish(shown: Bool) {
        continuation?.resume(returning: shown)
        continuation = nil
    }
}
#endif
