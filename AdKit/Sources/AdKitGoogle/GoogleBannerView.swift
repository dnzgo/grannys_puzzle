#if os(iOS)
import GoogleMobileAds
import SwiftUI

/// AdMob's banner view in SwiftUI. It loads one ad when created; AdMob then
/// refreshes it on the interval set for the ad unit in the AdMob console.
struct GoogleBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
#endif
