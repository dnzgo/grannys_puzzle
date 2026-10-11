import SwiftUI

/// What AdKit needs from an ad network (AdMob today). One adapter per
/// network implements this; `AdsController` holds the rules on top.
///
/// Main actor throughout: ad SDKs present full-screen ads and consent forms,
/// which is UI work, and their callbacks arrive on the main thread anyway.
@MainActor
public protocol AdNetwork: AnyObject {
    /// Asks for consent where the law requires it (EU, UK, some US states),
    /// showing the network's form if needed. Returns whether ads may be
    /// requested now. Safe to call on every launch: the form only appears
    /// when a choice is missing or out of date.
    func gatherConsent() async -> Bool

    /// Whether ads may be requested with the consent as it stands.
    var canRequestAds: Bool { get }

    /// Whether the app must offer a way to change the consent choice
    /// (a "Privacy choices" row in Settings). Required where consent was asked.
    var isPrivacyOptionsRequired: Bool { get }

    /// Shows the network's form for changing the consent choice.
    func presentPrivacyOptions() async

    /// Starts the ad SDK. Called once, after consent.
    func start() async

    /// Loads one rewarded ad, ready to show.
    func loadRewarded() async throws -> any LoadedRewardedAd

    /// A banner view of the given size, loading its own ads.
    func makeBannerView(size: AdBannerSize) -> AnyView
}

/// A rewarded ad that has loaded and can be shown once.
@MainActor
public protocol LoadedRewardedAd: AnyObject {
    /// Shows the ad and returns when it's closed: true if the viewer watched
    /// long enough to earn the reward, false if they closed it early or it
    /// couldn't be shown.
    func present() async -> Bool
}

/// Banner sizes AdKit supports. Only the standard one for now: its fixed
/// height lets an app reserve the exact space, so the screen never jumps
/// when an ad arrives. (Adaptive banners earn a little more but their
/// height varies by device.)
public enum AdBannerSize: Sendable {
    /// 320 × 50 points.
    case standard

    public var size: CGSize {
        switch self {
        case .standard: CGSize(width: 320, height: 50)
        }
    }
}
