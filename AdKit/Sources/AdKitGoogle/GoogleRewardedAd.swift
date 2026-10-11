#if os(iOS)
import AdKit
import GoogleMobileAds
import UIKit

/// One loaded AdMob rewarded ad, turned into AdKit's "present and tell me
/// if it was earned" call.
///
/// AdMob reports the two things separately: the reward handler fires when
/// the viewer has watched enough, and the delegate hears when the ad
/// closes. `present()` waits for the close and returns whether the reward
/// came first, so the app grants it after the ad is gone, not underneath it.
@MainActor
final class GoogleRewardedAd: NSObject, LoadedRewardedAd, FullScreenContentDelegate {
    private let ad: RewardedAd
    private var earned = false
    private var continuation: CheckedContinuation<Bool, Never>?

    init(ad: RewardedAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present() async -> Bool {
        // AdKit shows each ad once; a second call has nothing to wait for.
        guard continuation == nil else { return false }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            // Nil: present over the top view controller, which is what a
            // SwiftUI app wants.
            ad.present(from: nil) { [weak self] in
                self?.earned = true
            }
        }
    }

    // MARK: - FullScreenContentDelegate

    // Google calls these on the main thread (guaranteed since SDK 13), but
    // its protocol isn't marked main-actor, so they're declared nonisolated
    // and step onto the main actor explicitly.

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated { finish(earned: earned) }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        MainActor.assumeIsolated { finish(earned: false) }
    }

    /// Resumes the waiting `present()` exactly once.
    private func finish(earned: Bool) {
        continuation?.resume(returning: earned)
        continuation = nil
    }
}
#endif
