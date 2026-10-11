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
        // TODO: Before release, put the real ad unit IDs here (AdMob console →
        // Apps → Granny's Puzzle → Ad units), and the real app ID in
        // Config/grannys_puzzle-Info.plist (GADApplicationIdentifier).
        // Until then release builds also use the test units.
        return GoogleAdsConfiguration.googleTestUnits
        #endif
    }
}
