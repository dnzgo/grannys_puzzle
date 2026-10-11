import Observation
import SwiftUI

/// Timing for rewarded ads. Values are AdMob's guidance; other networks are
/// similar.
public struct RewardedAdPolicy: Sendable {
    /// Wait before retrying a failed load; doubles after each failure, so a
    /// player who is offline doesn't cause a request every few seconds.
    public var firstRetryDelay: Duration = .seconds(5)
    public var maxRetryDelay: Duration = .seconds(300)
    /// A loaded ad expires after an hour; it's replaced a little before.
    public var maxAge: Duration = .seconds(55 * 60)

    public init() {}

    public static let standard = RewardedAdPolicy()
}

/// The app's one ads object: gathers consent, asks the tracking question,
/// starts the network, keeps a rewarded ad ready, and hands out banners.
///
/// Apps observe it (`status`, `isRewardedReady`, `isPrivacyOptionsRequired`)
/// and call it; they never touch the network's SDK. The order of the start
/// steps is the part that matters legally and is easy to get wrong, which
/// is why it lives here, written once and tested.
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
    /// Whether a rewarded ad can be shown right now.
    public private(set) var isRewardedReady = false
    /// Whether Settings must offer "Privacy choices" (see `presentPrivacyOptions`).
    public private(set) var isPrivacyOptionsRequired = false

    private let network: any AdNetwork
    private let tracking: any TrackingPermission
    private let policy: RewardedAdPolicy
    /// Injected so tests can control time instead of waiting for it.
    private let sleep: @Sendable (Duration) async throws -> Void

    @ObservationIgnored private var rewardedAd: (any LoadedRewardedAd)?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Counts loads started, to tell the current one from a cancelled one.
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var hasStartedNetwork = false
    @ObservationIgnored private var isPresenting = false

    public init(
        network: any AdNetwork,
        tracking: any TrackingPermission = SystemTrackingPermission(),
        policy: RewardedAdPolicy = .standard,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.network = network
        self.tracking = tracking
        self.policy = policy
        self.sleep = sleep
    }

    // MARK: - Starting

    /// Consent, then the tracking question, then the SDK, then the first
    /// rewarded ad. In that order because ads may not be requested (and the
    /// SDK shouldn't collect anything) before consent, and Apple and Google
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
        loadRewardedIfNeeded()
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
    /// reward, so the caller grants it exactly then. The next ad starts
    /// loading as soon as this one closes.
    public func showRewarded() async -> Bool {
        guard status == .ready, !isPresenting, let ad = rewardedAd else { return false }
        // Taken out before presenting: an ad is shown at most once, and a
        // second tap while it's on screen finds nothing to show.
        rewardedAd = nil
        isRewardedReady = false
        expiryTask?.cancel()
        isPresenting = true
        let earned = await ad.present()
        isPresenting = false
        loadRewardedIfNeeded()
        return earned
    }

    /// Keeps trying until an ad loads, waiting longer after each failure.
    private func loadRewardedIfNeeded() {
        guard status == .ready, rewardedAd == nil, loadTask == nil else { return }
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            await self?.loadRewardedWithRetries()
            // Only clear our own handle: if ads were stopped and restarted
            // meanwhile, a newer load owns `loadTask` now.
            if self?.loadGeneration == generation {
                self?.loadTask = nil
            }
        }
    }

    private func loadRewardedWithRetries() async {
        var delay = policy.firstRetryDelay
        while status == .ready, !Task.isCancelled {
            do {
                let ad = try await network.loadRewarded()
                // A network's load doesn't stop when its task is cancelled;
                // an ad arriving for a cancelled load is dropped.
                guard status == .ready, !Task.isCancelled else { return }
                rewardedAd = ad
                isRewardedReady = true
                scheduleExpiry()
                return
            } catch {
                // Expected now and then (no ad to fill, offline); the retry
                // handles it. Nothing for the player to see.
                do {
                    try await sleep(delay)
                } catch {
                    return  // cancelled
                }
                delay = min(delay * 2, policy.maxRetryDelay)
            }
        }
    }

    /// Drops the ad shortly before the network would consider it stale,
    /// and loads a fresh one, so `isRewardedReady` never promises an ad
    /// that can't play.
    private func scheduleExpiry() {
        expiryTask?.cancel()
        expiryTask = Task { [weak self, sleep, maxAge = policy.maxAge] in
            do {
                try await sleep(maxAge)
            } catch {
                return  // cancelled: the ad was shown or ads stopped
            }
            guard let self else { return }
            self.rewardedAd = nil
            self.isRewardedReady = false
            self.loadRewardedIfNeeded()
        }
    }

    private func stopAds() {
        status = .unavailable
        loadTask?.cancel()
        loadTask = nil
        expiryTask?.cancel()
        rewardedAd = nil
        isRewardedReady = false
    }

    // MARK: - Testing

    /// Waits for the rewarded load in progress, if any.
    func waitForRewardedLoad() async {
        await loadTask?.value
    }
}
