import Foundation
import XCTest
@testable import ArrowwordCore

final class GameTuningTests: XCTestCase {
    /// Server values for a test, by key.
    private func resolve(_ values: [GameTuning.Key: Double]) -> (tuning: GameTuning, ignored: [GameTuning.Key]) {
        GameTuning.resolved { name in
            GameTuning.Key(rawValue: name).flatMap { values[$0] }
        }
    }

    func testWithNoServerValuesEverythingKeepsItsDefault() {
        // First launch, offline, or a console that sets nothing.
        let result = resolve([:])
        XCTAssertEqual(result.tuning, .standard)
        XCTAssertEqual(result.ignored, [])
    }

    func testServerValuesReplaceDefaults() {
        let result = resolve([
            .rewardedAdsPerDay: 5,
            .catHintsPerAd: 4,
            .adBreakFirstLevel: 15,
            .passThreshold: 0.75,
            .jarGrandmaChance: 0.4,
        ])
        XCTAssertEqual(result.tuning.rewardedAdsPerDay, 5)
        XCTAssertEqual(result.tuning.catHintsPerAd, 4)
        XCTAssertEqual(result.tuning.adBreakFirstLevel, 15)
        XCTAssertEqual(result.tuning.scoring.passThreshold, 0.75)
        XCTAssertEqual(result.tuning.jar.grandmaChance, 0.4)
        XCTAssertEqual(result.ignored, [])
    }

    func testOutOfRangeOrFractionalValuesAreIgnored() {
        // A console typo must not break the game: 3.5 cats, -1 videos, a
        // share of 80 (meant 0.8).
        let result = resolve([.catHintsPerAd: 3.5, .rewardedAdsPerDay: -1, .passThreshold: 80])
        XCTAssertEqual(result.tuning, .standard)
        XCTAssertEqual(Set(result.ignored), [.catHintsPerAd, .rewardedAdsPerDay, .passThreshold])
    }

    func testZeroVideosADayIsAValidWayToTurnThemOff() {
        XCTAssertEqual(resolve([.rewardedAdsPerDay: 0]).tuning.rewardedAdsPerDay, 0)
    }

    func testScoreThresholdsOutOfOrderAreIgnoredTogether() {
        // Each value is a fine share on its own, but 2 balls can't need
        // more than 3 balls. Applying only some would leave the rules
        // contradicting each other, so all of them keep their defaults.
        let result = resolve([.threeBallThreshold: 0.9, .twoBallThreshold: 0.95])
        XCTAssertEqual(result.tuning.scoring, .standard)
        XCTAssertEqual(Set(result.ignored), [.threeBallThreshold, .twoBallThreshold])
    }

    func testAJarHintRangeUpsideDownIsIgnoredTogether() {
        let result = resolve([.jarHintsMin: 4, .jarHintsMax: 2])
        XCTAssertEqual(result.tuning.jar.hintRange, DailyJarRules.standard.hintRange)
        XCTAssertEqual(Set(result.ignored), [.jarHintsMin, .jarHintsMax])
    }

    func testOneSideOfTheJarRangeCanMoveAlone() {
        XCTAssertEqual(resolve([.jarHintsMax: 5]).tuning.jar.hintRange, 1...5)
    }

    func testInterstitialTimingCanBeTuned() {
        let tuned = resolve([.adBreakMinimumSeconds: 300, .adBreakSecondsAfterRewarded: 0, .adBreakLevelsBetween: 3]).tuning

        XCTAssertEqual(tuned.adBreakMinimumSeconds, 300)
        XCTAssertEqual(tuned.adBreakSecondsAfterRewarded, 0, "0 leaves only the level rule")
        XCTAssertEqual(tuned.adBreakLevelsBetween, 3)
    }

    func testInterstitialGapsOverAnHourAreIgnored() {
        let (tuning, ignored) = resolve([.adBreakMinimumSeconds: 7_200])
        XCTAssertEqual(tuning.adBreakMinimumSeconds, GameTuning.standard.adBreakMinimumSeconds)
        XCTAssertEqual(ignored, [.adBreakMinimumSeconds])
    }

    func testWhenToAskCanBeTuned() {
        let tuned = resolve([.reviewMinLevels: 8, .reminderAskMinLevels: 2]).tuning

        XCTAssertEqual(tuned.review.minLevelsPassed, 8)
        XCTAssertEqual(tuned.reminderAskMinLevels, 2)
    }

    /// Zero would mean asking straight after the lesson, the very thing
    /// these numbers exist to prevent.
    func testAskingRightAfterTheLessonIsRefused() {
        let (tuning, ignored) = resolve([.reviewMinLevels: 0, .reminderAskMinLevels: 0])

        XCTAssertEqual(tuning.review.minLevelsPassed, GameTuning.standard.review.minLevelsPassed)
        XCTAssertEqual(tuning.reminderAskMinLevels, GameTuning.standard.reminderAskMinLevels)
        XCTAssertEqual(Set(ignored), [.reviewMinLevels, .reminderAskMinLevels])
    }

    func testTheDailysFirstDayIsSetAsADate() {
        let result = resolve([.dailyFirstDay: 20261210])
        XCTAssertEqual(result.tuning.dailyFirstDay, DailyDay.firstDay + 39)
        XCTAssertEqual(result.ignored, [])
    }

    func testAFirstDayThatIsntADateKeepsTheDefault() {
        // 31 February, and a day number typed instead of a date.
        for value in [20260231.0, 20_788] {
            let result = resolve([.dailyFirstDay: value])
            XCTAssertEqual(result.tuning.dailyFirstDay, DailyDay.firstDay, "\(value)")
            XCTAssertEqual(result.ignored, [.dailyFirstDay], "\(value)")
        }
    }

    func testEveryKeyIsReadSomewhere() {
        // A key added to the list but never read would look tunable in the
        // console and do nothing. Setting each to an out-of-range value must
        // get it reported, which only happens if it's read.
        let silly = Dictionary(uniqueKeysWithValues: GameTuning.Key.allCases.map { ($0, -1.0) })
        XCTAssertEqual(Set(resolve(silly).ignored), Set(GameTuning.Key.allCases))
    }

    // MARK: - The console template

    /// Firebase/remoteconfig.template.json creates every key in the
    /// console (set to "use in-app default"), so tuning later is an edit,
    /// not typing a key name. It must list exactly the keys the game reads:
    /// a missing one can't be tuned, an extra one does nothing.
    func testTheConsoleTemplateListsEveryKey() throws {
        let url = ShippedFiles.appLevelsFolder
            .deletingLastPathComponent()  // grannys_puzzle
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Firebase/remoteconfig.template.json")
        let template = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let groups = template["parameterGroups"] as? [String: [String: Any]] ?? [:]
        var keys = Set((template["parameters"] as? [String: Any] ?? [:]).keys)
        for group in groups.values {
            keys.formUnion((group["parameters"] as? [String: Any] ?? [:]).keys)
        }
        XCTAssertEqual(keys, Set(GameTuning.Key.allCases.map(\.rawValue)))
    }
}
