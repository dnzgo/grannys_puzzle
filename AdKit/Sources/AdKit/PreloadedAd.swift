import Observation

/// Keeps one full-screen ad (rewarded or interstitial) loaded and fresh, so
/// it can be shown the moment the app asks, with no loading wait.
///
/// Both formats need the same care: retry a failed load with growing waits,
/// replace an ad before the network considers it stale, and ignore an ad
/// that arrives after loading was stopped. Written once here, so the two
/// formats can't drift apart; `AdsController` holds one per format and
/// decides *when* each may be shown.
@MainActor
@Observable
final class PreloadedAd<Ad> {
    /// Whether an ad is loaded and can be taken now.
    private(set) var isReady = false

    private let load: @MainActor () async throws -> Ad
    private let policy: AdPolicy
    private let sleep: @Sendable (Duration) async throws -> Void

    @ObservationIgnored private var ad: Ad?
    /// Loading only happens while active (ads started and allowed).
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Counts loads started, to tell the current one from a cancelled one.
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    init(
        policy: AdPolicy,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        load: @escaping @MainActor () async throws -> Ad
    ) {
        self.policy = policy
        self.sleep = sleep
        self.load = load
    }

    /// Starts keeping an ad loaded.
    func activate() {
        isActive = true
        loadIfNeeded()
    }

    /// Stops loading and drops any loaded ad (e.g. consent was withdrawn).
    func deactivate() {
        isActive = false
        loadTask?.cancel()
        loadTask = nil
        expiryTask?.cancel()
        ad = nil
        isReady = false
    }

    /// Hands over the loaded ad, if any, and starts loading the next one.
    /// An ad is shown at most once, so it's taken out before it's shown: a
    /// second request while it's on screen finds nothing.
    func take() -> Ad? {
        guard let taken = ad else { return nil }
        ad = nil
        isReady = false
        expiryTask?.cancel()
        loadIfNeeded()
        return taken
    }

    /// Waits for the load in progress, if any. For tests.
    func waitForLoad() async {
        await loadTask?.value
    }

    // MARK: - Private

    /// Keeps trying until an ad loads, waiting longer after each failure.
    private func loadIfNeeded() {
        guard isActive, ad == nil, loadTask == nil else { return }
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            await self?.loadWithRetries()
            // Only clear our own handle: if loading was stopped and restarted
            // meanwhile, a newer load owns `loadTask` now.
            if self?.loadGeneration == generation {
                self?.loadTask = nil
            }
        }
    }

    private func loadWithRetries() async {
        var delay = policy.firstRetryDelay
        while isActive, !Task.isCancelled {
            do {
                let loaded = try await load()
                // A network's load doesn't stop when its task is cancelled;
                // an ad arriving for a cancelled load is dropped.
                guard isActive, !Task.isCancelled else { return }
                ad = loaded
                isReady = true
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

    /// Drops the ad shortly before the network would consider it stale and
    /// loads a fresh one, so `isReady` never promises an ad that can't play.
    private func scheduleExpiry() {
        expiryTask?.cancel()
        expiryTask = Task { [weak self, sleep, maxAge = policy.maxAge] in
            do {
                try await sleep(maxAge)
            } catch {
                return  // cancelled: the ad was taken or loading stopped
            }
            guard let self, self.isActive else { return }
            self.ad = nil
            self.isReady = false
            self.loadIfNeeded()
        }
    }
}
