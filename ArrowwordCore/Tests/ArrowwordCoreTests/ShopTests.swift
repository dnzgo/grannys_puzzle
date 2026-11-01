import Foundation
import XCTest
@testable import ArrowwordCore

/// The shop's two rules that protect the player's money: a purchase's
/// helpers are given exactly once, and pack sizes from the server can't
/// turn a pack into nothing.
final class ShopTests: XCTestCase {
    // MARK: - Granting purchases

    func testAPurchaseAddsItsHelpers() {
        var progress = PlayerProgress.newPlayer
        let before = (progress.hints, progress.grandmas)

        let added = progress.grantPurchase("tx-1", JarReward(hints: 15, grandmas: 2))

        XCTAssertTrue(added)
        XCTAssertEqual(progress.hints, before.0 + 15)
        XCTAssertEqual(progress.grandmas, before.1 + 2)
    }

    func testTheSamePurchaseHandedOverAgainAddsNothing() {
        // The App Store repeats a purchase after a crash before it was
        // finished, and a bundle with every "Restore purchases".
        var progress = PlayerProgress.newPlayer
        progress.grantPurchase("bundle-7", JarReward(hints: 30, grandmas: 5))
        let afterFirst = progress

        let added = progress.grantPurchase("bundle-7", JarReward(hints: 30, grandmas: 5))

        XCTAssertFalse(added)
        XCTAssertEqual(progress, afterFirst)
    }

    func testTwoPurchasesOfTheSamePackBothCount() {
        // Packs can be bought again: each purchase has its own key.
        var progress = PlayerProgress.newPlayer
        let start = progress.hints
        progress.grantPurchase("tx-1", JarReward(hints: 15, grandmas: 0))
        progress.grantPurchase("tx-2", JarReward(hints: 15, grandmas: 0))
        XCTAssertEqual(progress.hints, start + 30)
    }

    func testGrantedPurchasesSurviveSaving() throws {
        // Saved with the helpers, so a relaunch can't give them twice.
        var progress = PlayerProgress.newPlayer
        progress.grantPurchase("tx-1", JarReward(hints: 15, grandmas: 0))

        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))

        XCTAssertEqual(decoded.grantedPurchases, ["tx-1"])
        XCTAssertFalse({ var copy = decoded; return copy.grantPurchase("tx-1", JarReward(hints: 15, grandmas: 0)) }())
    }

    func testASaveFromBeforePurchasesHasNoneGranted() throws {
        let oldSave = #"{"version": 2, "levelNumbers": {"en": 4}, "hints": 2, "grandmas": 1, "yarn": {}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))
        XCTAssertEqual(progress.grantedPurchases, [])
    }

    // MARK: - Pack sizes from the server

    private func resolve(_ values: [GameTuning.Key: Double]) -> (tuning: GameTuning, ignored: [GameTuning.Key]) {
        GameTuning.resolved { name in
            GameTuning.Key(rawValue: name).flatMap { values[$0] }
        }
    }

    func testPackSizesCanBeChangedFromTheServer() {
        let result = resolve([.shopCatHintsSmall: 20, .shopGrandmasBig: 12, .shopBundleHints: 40, .shopBundleGrandmas: 6])
        XCTAssertEqual(result.tuning.shop.catHintsSmall, JarReward(hints: 20, grandmas: 0))
        XCTAssertEqual(result.tuning.shop.grandmasBig, JarReward(hints: 0, grandmas: 12))
        XCTAssertEqual(result.tuning.shop.welcomeBundle, JarReward(hints: 40, grandmas: 6))
        XCTAssertEqual(result.ignored, [])
    }

    func testAPackOfNothingIsIgnored() {
        // A pack sold for money must give something; 0 or a typo keeps the
        // default.
        let result = resolve([.shopCatHintsSmall: 0, .shopGrandmasSmall: 2.5])
        XCTAssertEqual(result.tuning.shop, .standard)
        XCTAssertEqual(Set(result.ignored), [.shopCatHintsSmall, .shopGrandmasSmall])
    }

    func testTheBundleMayGiveNoHelpers() {
        // It still removes ads, so 0 helpers is a valid (if odd) choice.
        let result = resolve([.shopBundleHints: 0, .shopBundleGrandmas: 0])
        XCTAssertEqual(result.tuning.shop.welcomeBundle, JarReward(hints: 0, grandmas: 0))
        XCTAssertEqual(result.ignored, [])
    }
}
