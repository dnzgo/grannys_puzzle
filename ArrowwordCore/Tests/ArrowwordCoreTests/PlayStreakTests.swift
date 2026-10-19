import Foundation
import XCTest
@testable import ArrowwordCore

/// The play streak: counting days in a row, and saving one missed day.
final class PlayStreakTests: XCTestCase {
    private let today = 1_000

    private func player(days: Int = 0, lastDay: Int? = nil) -> PlayerProgress {
        PlayerProgress(levelNumber: 5, hints: 0, grandmas: 0, yarn: [:], streakDays: days, lastStreakDay: lastDay)
    }

    // MARK: Counting

    func testTheFirstSolveStartsAStreakOfOne() {
        var progress = player()
        XCTAssertEqual(progress.streakStatus(today: today), .none)

        XCTAssertEqual(progress.recordStreakDay(today: today), 1)
        XCTAssertEqual(progress.streakStatus(today: today), .active(days: 1, solvedToday: true))
    }

    func testSolvingAgainTheSameDayCountsOnce() {
        var progress = player(days: 4, lastDay: today)
        XCTAssertEqual(progress.recordStreakDay(today: today), 4)
    }

    func testTheNextDayCarriesItOn() {
        var progress = player(days: 4, lastDay: today - 1)
        XCTAssertEqual(progress.streakStatus(today: today), .active(days: 4, solvedToday: false),
                       "still alive, waiting for today's solve")
        XCTAssertEqual(progress.recordStreakDay(today: today), 5)
    }

    func testTwoMissedDaysEndIt() {
        var progress = player(days: 9, lastDay: today - 3)
        XCTAssertEqual(progress.streakStatus(today: today), .none)
        XCTAssertEqual(progress.recordStreakDay(today: today), 1)
    }

    // MARK: Saving one missed day

    func testOneMissedDayCanBeSaved() {
        let progress = player(days: 12, lastDay: today - 2)
        XCTAssertEqual(progress.streakStatus(today: today), .canSave(days: 12))
    }

    func testSavingKeepsTheCountAndTodaysSolveCarriesItOn() {
        var progress = player(days: 12, lastDay: today - 2)

        XCTAssertTrue(progress.saveStreak(today: today))

        XCTAssertEqual(progress.streakStatus(today: today), .active(days: 12, solvedToday: false),
                       "the missed day is covered, not counted")
        XCTAssertEqual(progress.recordStreakDay(today: today), 13)
    }

    func testPlayingOnWithoutSavingStartsOver() {
        var progress = player(days: 12, lastDay: today - 2)
        XCTAssertEqual(progress.recordStreakDay(today: today), 1)
        XCTAssertFalse(progress.saveStreak(today: today), "too late once something was solved")
    }

    func testTurningTheSaveDownEndsItForToday() {
        var progress = player(days: 12, lastDay: today - 2)

        progress.declineStreakSave(today: today)

        XCTAssertEqual(progress.streakStatus(today: today), .none)
        XCTAssertFalse(progress.saveStreak(today: today))
        XCTAssertEqual(progress.recordStreakDay(today: today), 1)
    }

    func testThereIsNothingToSaveWithoutAStreak() {
        var progress = player()
        XCTAssertFalse(progress.saveStreak(today: today))
        progress = player(days: 3, lastDay: today - 1)
        XCTAssertFalse(progress.saveStreak(today: today), "an alive streak needs no saving")
    }

    func testEverySingleMissedDayCanBeSaved() {
        // Saved once, then missed a day again later: offered again.
        var progress = player(days: 12, lastDay: today - 2)
        progress.saveStreak(today: today)
        progress.recordStreakDay(today: today)

        XCTAssertEqual(progress.streakStatus(today: today + 2), .canSave(days: 13))
    }

    // MARK: Saving to disk

    func testTheStreakSurvivesSavingAndOldSavesHaveNone() throws {
        var progress = player()
        progress.recordStreakDay(today: today)
        let reloaded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(reloaded.streakStatus(today: today), .active(days: 1, solvedToday: true))

        let oldSave = #"{"grandmas": 1, "hints": 3, "levelNumbers": {"en": 8}, "version": 2, "yarn": {}}"#
        let old = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))
        XCTAssertEqual(old.streakStatus(today: today), .none)
    }
}
