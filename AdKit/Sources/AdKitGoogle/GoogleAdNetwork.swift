#if os(iOS)
import AdKit
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform
import os

/// AdMob for ads and Google's User Messaging Platform (UMP) for consent,
/// behind AdKit's `AdNetwork`.
///
/// UMP is Google's consent tool: it decides from the device's region whether
/// a form is needed (EU, UK, some US states) and shows the one configured in
/// the AdMob console under Privacy & messaging. If an "IDFA explainer"
/// message is set up there too, UMP shows it before iOS's tracking prompt.
@MainActor
public final class GoogleAdNetwork: AdNetwork {
    private let configuration: GoogleAdsConfiguration
    private let logger = Logger(subsystem: "AdKit", category: "google")

    public init(configuration: GoogleAdsConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Consent

    public func gatherConsent() async -> Bool {
        let parameters = RequestParameters()
        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.testDeviceIdentifiers = configuration.consentTestDeviceIDs
        if configuration.simulatesEEAForConsent {
            debugSettings.geography = .EEA
        }
        parameters.debugSettings = debugSettings
        #endif

        do {
            // Google asks for this on every launch, so a changed requirement
            // (new law, new region) is picked up.
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            // Shows nothing unless a choice is required and missing. Nil
            // means "present over whatever is on screen", fine in SwiftUI.
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // Offline or a form error. Not fatal: consent from an earlier
            // launch may still allow ads, which `canRequestAds` reflects.
            logger.notice("Consent check failed: \(error.localizedDescription, privacy: .public)")
        }
        return canRequestAds
    }

    public var canRequestAds: Bool {
        ConsentInformation.shared.canRequestAds
    }

    public var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    public func presentPrivacyOptions() async -> Bool {
        // UMP loads the form in the background after the launch's consent
        // check; a tap before that's done fails with "a privacy options form
        // is being loaded". So a failed try waits and tries again, briefly:
        // long enough for a load in progress, short enough that a real
        // failure (offline) is reported while the player still waits.
        for attempt in 1...Self.privacyFormAttempts {
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: nil)
                return true
            } catch {
                logger.error("Privacy options form failed (try \(attempt, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                if attempt < Self.privacyFormAttempts {
                    try? await Task.sleep(for: Self.privacyFormRetryDelay)
                }
            }
        }
        return false
    }

    private static let privacyFormAttempts = 3
    private static let privacyFormRetryDelay = Duration.seconds(1)

    // MARK: - Ads

    public func start() async {
        _ = await MobileAds.shared.start()
    }

    public func loadRewarded() async throws -> any LoadedRewardedAd {
        let ad = try await RewardedAd.load(with: configuration.rewardedAdUnitID, request: Request())
        return GoogleRewardedAd(ad: ad)
    }

    public func loadInterstitial() async throws -> any LoadedInterstitialAd {
        let ad = try await InterstitialAd.load(with: configuration.interstitialAdUnitID, request: Request())
        return GoogleInterstitialAd(ad: ad)
    }

    public func makeBannerView(size: AdBannerSize) -> AnyView {
        AnyView(
            GoogleBannerView(adUnitID: configuration.bannerAdUnitID)
                .frame(width: size.size.width, height: size.size.height)
        )
    }
}
#endif
