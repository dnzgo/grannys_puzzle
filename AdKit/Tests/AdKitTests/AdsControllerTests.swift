import SwiftUI
import XCTest
@testable import AdKit

@MainActor
final class AdsControllerTests: XCTestCase {
    // MARK: - Starting

    func testStartAsksConsentThenTrackingThenStartsTheNetwork() async {
        let log = CallLog()
        let controller = AdsController(network: FakeNetwork(log: log), tracking: FakeTracking(log: log), sleep: WaitLog().sleep)

        await controller.start()

        // The legally important order: nothing ad-related before consent,
        // and the tracking question after the consent message.
        XCTAssertEqual(Array(log.calls.prefix(3)), ["consent", "tracking", "start"])
        XCTAssertEqual(controller.status, .ready)
    }

    func testWithoutConsentThereAreNoAdsAndNoTrackingQuestion() async {
        let log = CallLog()
        let network = FakeNetwork(log: log)
        network.consentGiven = false
        let controller = AdsController(network: network, tracking: FakeTracking(log: log), sleep: WaitLog().sleep)

        await controller.start()

        XCTAssertEqual(log.calls, ["consent"])
        XCTAssertEqual(controller.status, .unavailable)
        XCTAssertNil(controller.bannerView())
        XCTAssertFalse(controller.isRewardedReady)
    }

    func testStartingTwiceAsksForConsentOnce() async {
        let log = CallLog()
        let controller = AdsController(network: FakeNetwork(log: log), tracking: FakeTracking(log: log), sleep: WaitLog().sleep)

        await controller.start()
        await controller.start()

        XCTAssertEqual(log.calls.filter { $0 == "consent" }.count, 1)
    }

    func testAfterBeingUnavailableStartCanTryAgain() async {
        // E.g. the first launch was offline, so consent couldn't be checked.
        let log = CallLog()
        let network = FakeNetwork(log: log)
        network.consentGiven = false
        let controller = AdsController(network: network, tracking: FakeTracking(log: log), sleep: WaitLog().sleep)
        await controller.start()

        network.consentGiven = true
        await controller.start()

        XCTAssertEqual(controller.status, .ready)
    }

    // MARK: - Rewarded ads

    func testARewardedAdIsReadyAfterStarting() async {
        let controller = AdsController(network: FakeNetwork(), tracking: FakeTracking(), sleep: WaitLog().sleep)

        await controller.start()
        await controller.waitForRewardedLoad()

        XCTAssertTrue(controller.isRewardedReady)
    }

    func testWatchingToTheEndEarnsTheRewardAndTheNextAdLoads() async {
        let network = FakeNetwork()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)
        await controller.start()
        await controller.waitForRewardedLoad()

        let earned = await controller.showRewarded()
        await controller.waitForRewardedLoad()

        XCTAssertTrue(earned)
        XCTAssertEqual(network.loadCount, 2)
        XCTAssertTrue(controller.isRewardedReady)
    }

    func testClosingTheAdEarlyEarnsNothing() async {
        let network = FakeNetwork()
        network.viewerWatchesToTheEnd = false
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)
        await controller.start()
        await controller.waitForRewardedLoad()

        let earned = await controller.showRewarded()

        XCTAssertFalse(earned)
    }

    func testWithNoAdLoadedShowingEarnsNothing() async {
        let controller = AdsController(network: FakeNetwork(), tracking: FakeTracking(), sleep: WaitLog().sleep)
        // Not started, so nothing has loaded.
        let earned = await controller.showRewarded()
        XCTAssertFalse(earned)
    }

    func testAFailedLoadIsRetriedWithLongerAndLongerWaits() async {
        let network = FakeNetwork()
        network.failuresBeforeSuccess = 3
        let waits = WaitLog()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: waits.sleep)

        await controller.start()
        await controller.waitForRewardedLoad()

        XCTAssertTrue(controller.isRewardedReady)
        XCTAssertEqual(network.loadCount, 4)
        // The first three waits are the retries (5, 10, 20 s); the last one
        // is the new ad's expiry timer.
        XCTAssertEqual(Array(waits.durations.prefix(3)), [.seconds(5), .seconds(10), .seconds(20)])
    }

    func testRetryWaitsStopGrowingAtTheMaximum() async {
        let network = FakeNetwork()
        network.failuresBeforeSuccess = 10
        let waits = WaitLog()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: waits.sleep)

        await controller.start()
        await controller.waitForRewardedLoad()

        XCTAssertEqual(waits.durations.prefix(10).max(), AdPolicy.standard.maxRetryDelay)
    }

    func testAnAdAboutToExpireIsReplaced() async {
        let network = FakeNetwork()
        let waits = WaitLog()
        // Let the first ad's expiry timer run out at once, then hold the
        // second one's, so the test sees exactly one replacement.
        waits.expiriesToRunOut = 1
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: waits.sleep)

        await controller.start()
        await controller.waitForRewardedLoad()
        // The expiry runs in its own task; give it up to 2 seconds of real
        // time to start the reload, then wait for that load to finish.
        let deadline = ContinuousClock.now + .seconds(2)
        while network.loadCount < 2, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        await controller.waitForRewardedLoad()

        XCTAssertEqual(network.loadCount, 2)
        XCTAssertTrue(controller.isRewardedReady)
    }

    // MARK: - Interstitials

    func testInterstitialsAreNotLoadedUntilTheAppAsksForThem() async {
        let network = FakeNetwork()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)

        await controller.start()
        await controller.waitForRewardedLoad()

        XCTAssertEqual(network.interstitialLoadCount, 0)
        let shown = await controller.showInterstitial()
        XCTAssertFalse(shown)
    }

    func testAskingBeforeStartingLoadsOneOnceAdsAreAllowed() async {
        let network = FakeNetwork()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)

        controller.prepareInterstitials()
        XCTAssertEqual(network.interstitialLoadCount, 0, "Nothing may load before consent")
        await controller.start()
        await controller.waitForInterstitialLoad()

        XCTAssertTrue(controller.isInterstitialReady)
    }

    func testAShownInterstitialIsReplacedByTheNextOne() async {
        let network = FakeNetwork()
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)
        await controller.start()
        controller.prepareInterstitials()
        await controller.waitForInterstitialLoad()

        let shown = await controller.showInterstitial()
        await controller.waitForInterstitialLoad()

        XCTAssertTrue(shown)
        XCTAssertEqual(network.interstitialsPresented, 1)
        XCTAssertEqual(network.interstitialLoadCount, 2)
        XCTAssertTrue(controller.isInterstitialReady)
    }

    func testTheNextInterstitialWaitsForTheMinimumGap() async {
        let clock = TestClock()
        let controller = AdsController(network: FakeNetwork(), tracking: FakeTracking(), sleep: WaitLog().sleep, now: clock.now)
        await controller.start()
        controller.prepareInterstitials()
        await controller.waitForInterstitialLoad()
        _ = await controller.showInterstitial()
        await controller.waitForInterstitialLoad()

        clock.advance(by: AdPolicy.standard.interstitialMinimumGap - .seconds(1))
        let tooSoon = await controller.showInterstitial()
        clock.advance(by: .seconds(1))
        let onTime = await controller.showInterstitial()

        XCTAssertFalse(tooSoon)
        XCTAssertTrue(onTime)
    }

    func testTunedGapsReplaceTheDefaults() async {
        let clock = TestClock()
        let controller = AdsController(network: FakeNetwork(), tracking: FakeTracking(), sleep: WaitLog().sleep, now: clock.now)
        controller.setInterstitialGaps(minimum: .seconds(60), afterRewarded: .zero)
        await controller.start()
        controller.prepareInterstitials()
        await controller.waitForInterstitialLoad()
        _ = await controller.showInterstitial()
        await controller.waitForInterstitialLoad()

        clock.advance(by: .seconds(59))
        let tooSoon = await controller.showInterstitial()
        clock.advance(by: .seconds(1))
        let onTime = await controller.showInterstitial()

        XCTAssertFalse(tooSoon)
        XCTAssertTrue(onTime, "the shorter tuned gap applies, not the 3-minute default")
    }

    func testNoInterstitialRightAfterARewardedVideo() async {
        let clock = TestClock()
        let controller = AdsController(network: FakeNetwork(), tracking: FakeTracking(), sleep: WaitLog().sleep, now: clock.now)
        await controller.start()
        controller.prepareInterstitials()
        await controller.waitForRewardedLoad()
        await controller.waitForInterstitialLoad()

        _ = await controller.showRewarded()
        let rightAfter = await controller.showInterstitial()
        clock.advance(by: AdPolicy.standard.interstitialGapAfterRewarded)
        let later = await controller.showInterstitial()

        XCTAssertFalse(rightAfter)
        XCTAssertTrue(later)
    }

    func testWithoutConsentNoInterstitialLoadsOrShows() async {
        let network = FakeNetwork()
        network.consentGiven = false
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)

        controller.prepareInterstitials()
        await controller.start()
        let shown = await controller.showInterstitial()

        XCTAssertFalse(shown)
        XCTAssertEqual(network.interstitialLoadCount, 0)
    }

    // MARK: - Privacy choices

    func testWithdrawingConsentStopsAds() async {
        let network = FakeNetwork()
        network.privacyOptionsRequired = true
        let controller = AdsController(network: network, tracking: FakeTracking(), sleep: WaitLog().sleep)
        await controller.start()
        await controller.waitForRewardedLoad()
        XCTAssertTrue(controller.isPrivacyOptionsRequired)

        network.consentGiven = false  // what the player picks in the form
        await controller.presentPrivacyOptions()

        XCTAssertEqual(controller.status, .unavailable)
        XCTAssertFalse(controller.isRewardedReady)
        XCTAssertNil(controller.bannerView())
    }
}

// MARK: - Test doubles

/// Records the order of calls across the fakes.
@MainActor
private final class CallLog {
    var calls: [String] = []
}

/// Stands in for real waiting. Retry waits return at once; an ad's expiry
/// wait returns at once only `expiriesToRunOut` times and otherwise holds,
/// so a loaded ad stays loaded for the rest of the test (with every wait
/// instant, each new ad would expire at once and reload forever).
private final class WaitLog: @unchecked Sendable {
    var durations: [Duration] = []
    var expiriesToRunOut = 0

    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in
            await MainActor.run { self.durations.append(duration) }
            guard duration == AdPolicy.standard.maxAge else { return }
            let runsOut = await MainActor.run { () -> Bool in
                guard self.expiriesToRunOut > 0 else { return false }
                self.expiriesToRunOut -= 1
                return true
            }
            if !runsOut {
                // Held until the test ends (or the task is cancelled).
                try await Task.sleep(for: .seconds(3_600))
            }
        }
    }
}

@MainActor
private final class FakeTracking: TrackingPermission {
    private let log: CallLog?
    init(log: CallLog? = nil) { self.log = log }
    func requestIfNeeded() async { log?.calls.append("tracking") }
}

private struct LoadFailed: Error {}

@MainActor
private final class FakeNetwork: AdNetwork {
    var consentGiven = true
    var privacyOptionsRequired = false
    var failuresBeforeSuccess = 0
    var viewerWatchesToTheEnd = true
    private(set) var loadCount = 0
    private let log: CallLog?

    init(log: CallLog? = nil) { self.log = log }

    func gatherConsent() async -> Bool {
        log?.calls.append("consent")
        return consentGiven
    }

    var canRequestAds: Bool { consentGiven }
    var isPrivacyOptionsRequired: Bool { privacyOptionsRequired }
    func presentPrivacyOptions() async -> Bool { true }

    func start() async { log?.calls.append("start") }

    func loadRewarded() async throws -> any LoadedRewardedAd {
        loadCount += 1
        if failuresBeforeSuccess > 0 {
            failuresBeforeSuccess -= 1
            throw LoadFailed()
        }
        return FakeRewardedAd(earns: viewerWatchesToTheEnd)
    }

    private(set) var interstitialLoadCount = 0
    private(set) var interstitialsPresented = 0

    func loadInterstitial() async throws -> any LoadedInterstitialAd {
        interstitialLoadCount += 1
        return FakeInterstitialAd { [weak self] in self?.interstitialsPresented += 1 }
    }

    func makeBannerView(size: AdBannerSize) -> AnyView { AnyView(Color.clear) }
}

@MainActor
private final class FakeRewardedAd: LoadedRewardedAd {
    private let earns: Bool
    init(earns: Bool) { self.earns = earns }
    func present() async -> Bool { earns }
}

@MainActor
private final class FakeInterstitialAd: LoadedInterstitialAd {
    private let onPresent: () -> Void
    init(onPresent: @escaping () -> Void) { self.onPresent = onPresent }
    func present() async { onPresent() }
}

/// A clock the test moves by hand, for the time-between-ads rules.
private final class TestClock: @unchecked Sendable {
    private var instant = ContinuousClock.now

    var now: () -> ContinuousClock.Instant {
        { [self] in instant }
    }

    func advance(by duration: Duration) {
        instant = instant + duration
    }
}
