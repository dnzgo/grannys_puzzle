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

    public func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            logger.error("Privacy options form failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Ads

    public func start() async {
        _ = await MobileAds.shared.start()
    }

    public func loadRewarded() async throws -> any LoadedRewardedAd {
        let ad = try await RewardedAd.load(with: configuration.rewardedAdUnitID, request: Request())
        return GoogleRewardedAd(ad: ad)
    }

    public func makeBannerView(size: AdBannerSize) -> AnyView {
        AnyView(
            GoogleBannerView(adUnitID: configuration.bannerAdUnitID)
                .frame(width: size.size.width, height: size.size.height)
        )
    }
}
#endif
