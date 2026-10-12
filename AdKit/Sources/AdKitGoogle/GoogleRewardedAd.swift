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
final class GoogleRewardedAd: LoadedRewardedAd {
    private let ad: RewardedAd
    /// Kept here because AdMob holds its delegate weakly.
    private let waiter = FullScreenAdWaiter()
    private var earned = false

    init(ad: RewardedAd) {
        self.ad = ad
        ad.fullScreenContentDelegate = waiter
    }

    func present() async -> Bool {
        let shown = await waiter.presentAndWait {
            // Nil: present over the top view controller, which is what a
            // SwiftUI app wants.
            ad.present(from: nil) { [weak self] in
                self?.earned = true
            }
        }
        return shown && earned
    }
}
#endif
