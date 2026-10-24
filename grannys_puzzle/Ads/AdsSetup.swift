import AdKit
import AdKitGoogle

/// This game's ads: which AdMob ad units, and the one place that picks
/// Google as the network. Everything else in the app only knows AdKit.
enum AdsSetup {
    static func makeController() -> AdsController {
        AdsController(network: GoogleAdNetwork(configuration: configuration))
    }

    private static var configuration: GoogleAdsConfiguration {
        #if DEBUG
        // Google's test ads while developing: tapping your own real ads can
        // get an AdMob account suspended. Turn on `simulatesEEAForConsent`
        // to see the EU consent form from anywhere.
        var configuration = GoogleAdsConfiguration.googleTestUnits
        configuration.simulatesEEAForConsent = false
        return configuration
        #else
        return realUnits
        #endif
    }

    /// The real ad units (AdMob → Apps → Granny's Puzzle → Ad units), for
    /// release builds only, which includes TestFlight: testers see real ads
    /// there, so they should never tap them on purpose. The app ID that
    /// goes with them is GADApplicationIdentifier in
    /// Config/grannys_puzzle-Info.plist.
    private static let realUnits = GoogleAdsConfiguration(
        rewardedAdUnitID: "ca-app-pub-9097467595663045/2871355620",
        interstitialAdUnitID: "ca-app-pub-9097467595663045/1218528459",
        bannerAdUnitID: "ca-app-pub-9097467595663045/7137903695"
    )
}
