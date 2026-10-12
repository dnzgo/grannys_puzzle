#if os(iOS)
import AdKit
import GoogleMobileAds
import UIKit

/// One loaded AdMob interstitial, turned into AdKit's "present and wait
/// until it's closed" call.
@MainActor
final class GoogleInterstitialAd: LoadedInterstitialAd {
    private let ad: InterstitialAd
    /// Kept here because AdMob holds its delegate weakly.
    private let waiter = FullScreenAdWaiter()

    init(ad: InterstitialAd) {
        self.ad = ad
        ad.fullScreenContentDelegate = waiter
    }

    func present() async {
        // Whether it showed doesn't matter to the caller: either way the
        // app carries on to where it was going.
        _ = await waiter.presentAndWait {
            ad.present(from: nil)
        }
    }
}
#endif
