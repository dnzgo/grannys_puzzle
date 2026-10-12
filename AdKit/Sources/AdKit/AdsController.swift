import Observation
import SwiftUI

/// Timing rules for full-screen ads. Load and expiry values are AdMob's
/// guidance; other networks are similar.
public struct AdPolicy: Sendable {
    /// Wait before retrying a failed load; doubles after each failure, so a
    /// player who is offline doesn't cause a request every few seconds.
    public var firstRetryDelay: Duration = .seconds(5)
    public var maxRetryDelay: Duration = .seconds(300)
    /// A loaded ad expires after an hour; it's replaced a little before.
    public var maxAge: Duration = .seconds(55 * 60)

    /// Least time from one interstitial closing to the next one showing,
    /// however often the app asks. Ad networks penalise apps that show them
    /// too often, and players leave.
    public var interstitialMinimumGap: Duration = .seconds(180)
    /// No interstitial this soon after a rewarded video: the player just
    /// chose to watch one, and a second, unasked-for ad would punish that.
    public var interstitialGapAfterRewarded: Duration = .seconds(120)

    public init() {}

    public static let standard = AdPolicy()
}

/// The app's one ads object: gathers consent, asks the tracking question,
/// starts the network, keeps full-screen ads ready, and hands out banners.
///
/// Apps observe it (`status`, `isRewardedReady`, `isPrivacyOptionsRequired`)
/// and call it; they never touch the network's SDK. The order of the start
/// steps is the part that matters legally and is easy to get wrong, which
/// is why it lives here, written once and tested.
///
/// It holds the rules every app shares (time between interstitials, none
/// right after a rewarded video). *When* in the app an interstitial fits
/// (after which level, how many levels apart) is the app's call: it asks
/// `showInterstitial()` at those moments, and this may still say no.
@MainActor
@Observable
public final class AdsController {
    public enum Status: Equatable, Sendable {
        /// `start()` hasn't been called.
        case idle
        /// Consent, tracking question and SDK start are in progress.
        case starting
        /// Ads may be shown.
        case ready
        /// No ads for now: consent not given, or it couldn't be checked
        /// (e.g. offline). `start()` may be called again later.
        case unavailable
    }

    public private(set) var status: Status = .idle
    /// Whether Settings must offer "Privacy choices" (see `presentPrivacyOptions`).
    public private(set) var isPrivacyOptionsRequired = false

    /// Whether a rewarded ad can be shown right now.
    public var isRewardedReady: Bool { rewarded.isReady }

    private let network: any AdNetwork
    private let tracking: any TrackingPermission
    private let policy: AdPolicy
    /// Injected so tests can move time forward instead of waiting.
    private let now: () -> ContinuousClock.Instant

    // Observable themselves, so reading `isReady` through them is tracked.
    private let rewarded: PreloadedAd<any LoadedRewardedAd>
    private let interstitial: PreloadedAd<any LoadedInterstitialAd>

    @ObservationIgnored private var hasStartedNetwork = false
    @ObservationIgnored private var isPresenting = false
    /// Off until the app first asks for interstitials, so an app (or a new
    /// player) that isn't showing them yet doesn't request ads it won't use.
    @ObservationIgnored private var wantsInterstitials = false
    @ObservationIgnored private var lastInterstitialClosed: ContinuousClock.Instant?
    @ObservationIgnored private var lastRewardedClosed: ContinuousClock.Instant?

    public init(
        network: any AdNetwork,
        tracking: any TrackingPermission = SystemTrackingPermission(),
        policy: AdPolicy = .standard,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.network = network
        self.tracking = tracking
        self.policy = policy
        self.now = now
        rewarded = PreloadedAd(policy: policy, sleep: sleep) { try await network.loadRewarded() }
        interstitial = PreloadedAd(policy: policy, sleep: sleep) { try await network.loadInterstitial() }
    }

    // MARK: - Starting

    /// Consent, then the tracking question, then the SDK, then the first
    /// ads. In that order because ads may not be requested (and the SDK
    /// shouldn't collect anything) before consent, and Apple and Google
    /// both want the consent message before the tracking prompt.
    ///
    /// Call it when the app is ready for a form to appear, e.g. when the
    /// main screen shows. Repeated calls are harmless: it only runs from
    /// `idle` or `unavailable` (to retry after being offline).
    public func start() async {
        guard status == .idle || status == .unavailable else { return }
        status = .starting

        let mayRequestAds = await network.gatherConsent()
        isPrivacyOptionsRequired = network.isPrivacyOptionsRequired
        guard mayRequestAds else {
            status = .unavailable
            return
        }

        await tracking.requestIfNeeded()
        if !hasStartedNetwork {
            await network.start()
            hasStartedNetwork = true
        }
        status = .ready
        rewarded.activate()
        if wantsInterstitials { interstitial.activate() }
    }

    /// Lets the player change their consent choice (Settings → Privacy
    /// choices). If they withdraw it, ads stop until it's given again.
    public func presentPrivacyOptions() async {
        await network.presentPrivacyOptions()
        isPrivacyOptionsRequired = network.isPrivacyOptionsRequired
        if network.canRequestAds {
            if status == .unavailable { await start() }
        } else {
            stopAds()
        }
    }

    // MARK: - Banners

    /// A banner to place in the app, or nil while ads can't be shown. The
    /// caller should reserve `size.size` either way so the layout is stable.
    public func bannerView(size: AdBannerSize = .standard) -> AnyView? {
        status == .ready ? network.makeBannerView(size: size) : nil
    }

    // MARK: - Rewarded

    /// Shows the rewarded ad. Returns true only if the viewer earned the
    /// reward, so the caller grants it exactly then. The next one starts
    /// loading straight away.
    public func showRewarded() async -> Bool {
        guard status == .ready, !isPresenting, let ad = rewarded.take() else { return false }
        isPresenting = true
        let earned = await ad.present()
        isPresenting = false
        lastRewardedClosed = now()
        return earned
    }

    // MARK: - Interstitials

    /// Starts keeping an interstitial loaded. Call it a little before the
    /// first moment the app would show one (e.g. once a player is close to
    /// the level where they start), so it's ready in time. Calling it again
    /// is harmless.
    public func prepareInterstitials() {
        wantsInterstitials = true
        if status == .ready { interstitial.activate() }
    }

    /// Shows an interstitial if one is loaded and the timing rules allow it.
    /// Returns once it's closed: true if one was shown. False is normal (too
    /// soon, nothing loaded, no consent); the app just carries on.
    public func showInterstitial() async -> Bool {
        guard status == .ready, !isPresenting, interstitialTimingAllows(), let ad = interstitial.take() else {
            return false
        }
        isPresenting = true
        await ad.present()
        isPresenting = false
        lastInterstitialClosed = now()
        return true
    }

    private func interstitialTimingAllows() -> Bool {
        let time = now()
        if let last = lastInterstitialClosed, time - last < policy.interstitialMinimumGap { return false }
        if let last = lastRewardedClosed, time - last < policy.interstitialGapAfterRewarded { return false }
        return true
    }

    // MARK: - Stopping

    private func stopAds() {
        status = .unavailable
        rewarded.deactivate()
        interstitial.deactivate()
    }

    // MARK: - Testing

    /// Waits for the rewarded load in progress, if any.
    func waitForRewardedLoad() async {
        await rewarded.waitForLoad()
    }

    /// Waits for the interstitial load in progress, if any.
    func waitForInterstitialLoad() async {
        await interstitial.waitForLoad()
    }

    var isInterstitialReady: Bool { interstitial.isReady }
}
