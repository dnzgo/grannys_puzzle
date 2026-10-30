import Foundation
import XCTest
@testable import ArrowwordCore

/// The daily puzzle: its calendar, the one-go-a-day rule, the clock that
/// keeps running, and how results rank.
final class DailyPuzzleTests: XCTestCase {
    // MARK: - Calendar

    func testTheDayChangesAtMidnightUTC() {
        // 2026-10-19 00:00:00 UTC.
        let midnight = Date(timeIntervalSince1970: 1_792_368_000)
        let day = DailyDay.number(for: midnight)

        XCTAssertEqual(DailyDay.number(for: midnight.addingTimeInterval(-1)), day - 1)
        XCTAssertEqual(DailyDay.number(for: midnight.addingTimeInterval(86_399)), day)
        XCTAssertEqual(DailyDay.end(of: day), midnight.addingTimeInterval(86_400))
    }

    func testPuzzlesAreNumberedFromTheFirstDay() {
        XCTAssertEqual(DailyDay.puzzleNumber(forDay: DailyDay.firstDay), 1)
        XCTAssertEqual(DailyDay.puzzleNumber(forDay: DailyDay.firstDay + 100), 101, "day 101 is the second pack's first")
        XCTAssertEqual(DailyDay.puzzleNumber(forDay: DailyDay.firstDay - 1), 0)
    }

    func testTheFirstDayCanBeAnotherDay() {
        // Launch slipped by ten days: the server moves the first day, and
        // that day plays puzzle 1 rather than puzzle 11.
        let later = DailyDay.firstDay + 10
        XCTAssertEqual(DailyDay.puzzleNumber(forDay: later, firstDay: later), 1)
        XCTAssertEqual(DailyDay.puzzleNumber(forDay: later), 11)
    }

    func testADateReadsAsItsDay() {
        // The built-in first day is 1 November 2026.
        XCTAssertEqual(DailyDay.number(fromDate: 20261101), DailyDay.firstDay)
        XCTAssertEqual(DailyDay.number(fromDate: 20261201), DailyDay.firstDay + 30)
        XCTAssertEqual(DailyDay.number(fromDate: 20270101), DailyDay.firstDay + 61)
    }

    func testNotARealDateIsRefused() {
        XCTAssertNil(DailyDay.number(fromDate: 20260231), "no 31 February")
        XCTAssertNil(DailyDay.number(fromDate: 20261301), "no 13th month")
        XCTAssertNil(DailyDay.number(fromDate: 2026121), "a digit short")
    }

    func testWithoutTheDaysPackThePuzzlesOnThePhoneGoRound() {
        XCTAssertEqual(DailyDay.fallbackNumber(for: 1, available: 30), 1)
        XCTAssertEqual(DailyDay.fallbackNumber(for: 31, available: 30), 1)
        XCTAssertEqual(DailyDay.fallbackNumber(for: 130, available: 100), 30)
        // Before the first day (testing before launch), counting backwards.
        XCTAssertEqual(DailyDay.fallbackNumber(for: 0, available: 30), 30)
        XCTAssertEqual(DailyDay.fallbackNumber(for: -29, available: 30), 1)
        XCTAssertNil(DailyDay.fallbackNumber(for: 5, available: 0), "no puzzles, no daily")
    }

    // MARK: - One go a day

    private let start = Date(timeIntervalSince1970: 1_792_400_000)
    private let today = 20_745

    private func newPlayer() -> PlayerProgress {
        PlayerProgress(levelNumber: 5, hints: 0, grandmas: 0, yarn: [:])
    }

    private func result(correct: Int, of judged: Int) -> LevelResult {
        LevelResult(correctLetters: correct, judgedLetters: judged, rules: .standard)
    }

    func testComingBackStartsOverWithAFreshClock() {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)

        let again = player.startDaily(today: today, levelID: "en-900001", now: start.addingTimeInterval(300))

        XCTAssertEqual(again?.startedAt, start.addingTimeInterval(300))
        XCTAssertEqual(player.dailyStatus(today: today), .inProgress(again!))
    }

    func testLeavingThrowsTheGoAway() {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)

        player.leaveDaily()

        XCTAssertEqual(player.dailyStatus(today: today), .notStarted)
    }

    func testLeavingAfterSubmittingKeepsTheResult() {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)
        let finished = player.finishDaily(result(correct: 50, of: 50), now: start.addingTimeInterval(90))

        player.leaveDaily()

        XCTAssertEqual(player.dailyStatus(today: today), .done(finished!))
    }

    func testTheClockCountsTheTimeTaken() throws {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)

        // 4 minutes 12 seconds later, the app in the background or not.
        let finished = player.finishDaily(result(correct: 46, of: 50), now: start.addingTimeInterval(252))

        XCTAssertEqual(finished, DailyResult(correctLetters: 46, judgedLetters: 50, seconds: 252))
        XCTAssertEqual(player.dailyStatus(today: today), .done(finished!))
    }

    func testOnlyOneGoADay() throws {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)
        player.finishDaily(result(correct: 50, of: 50), now: start.addingTimeInterval(100))

        XCTAssertNil(player.startDaily(today: today, levelID: "en-900001", now: start.addingTimeInterval(200)))
        XCTAssertNil(player.finishDaily(result(correct: 50, of: 50), now: start.addingTimeInterval(50)),
                     "a second submit can't improve the time")
        XCTAssertEqual(player.daily?.result?.seconds, 100)
    }

    func testANewDayHasANewPuzzle() throws {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)
        player.finishDaily(result(correct: 40, of: 50), now: start.addingTimeInterval(100))

        XCTAssertEqual(player.dailyStatus(today: today + 1), .notStarted)
        let tomorrow = player.startDaily(today: today + 1, levelID: "en-900002", now: start.addingTimeInterval(86_400))
        XCTAssertEqual(tomorrow?.day, today + 1)
        XCTAssertNil(tomorrow?.result)
    }

    func testTheDailySurvivesSavingAndOldSavesHaveNone() throws {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "en-900001", now: start)
        let reloaded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(player))
        XCTAssertEqual(reloaded.daily, player.daily)

        let oldSave = #"{"grandmas": 1, "hints": 3, "levelNumbers": {"en": 8}, "version": 2, "yarn": {}}"#
        XCTAssertNil(try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8)).daily)
    }

    // MARK: - Leaderboard

    func testASubmittedGoBelongsOnItsLanguagesLeaderboard() {
        var player = newPlayer()
        player.startDaily(today: today, levelID: "daily-tr-1", now: start, language: "tr")
        XCTAssertNil(player.daily?.leaderboardLanguage, "nothing to submit before the board is judged")
        player.finishDaily(result(correct: 50, of: 50), now: start.addingTimeInterval(240))
        XCTAssertEqual(player.daily?.leaderboardLanguage, "tr")
    }

    func testAFallbackPuzzleStaysOffTheLeaderboard() {
        // Not the puzzle everyone else had that day, so not comparable.
        var player = newPlayer()
        player.startDaily(today: today, levelID: "daily-en-7", now: start, language: "en", isFallbackPuzzle: true)
        player.finishDaily(result(correct: 50, of: 50), now: start.addingTimeInterval(240))
        XCTAssertNil(player.daily?.leaderboardLanguage)
    }

    func testOldSavesKeepTheirDailyWithoutALanguage() throws {
        let old = #"{"day": 20745, "levelID": "en-900001", "startedAt": 0}"#
        let attempt = try JSONDecoder().decode(DailyAttempt.self, from: Data(old.utf8))
        XCTAssertNil(attempt.language)
        XCTAssertNil(attempt.leaderboardLanguage)
    }

    // MARK: - Ranking

    func testTheScoreIsCorrectnessPlusSpeed() {
        // 47 of 50 is 94%: 9,400. 240 seconds leaves 960, at 2.5 each: 2,400.
        let score = DailyResult(correctLetters: 47, judgedLetters: 50, seconds: 240).score
        XCTAssertEqual(score.correctness, 9_400)
        XCTAssertEqual(score.speedBonus, 2_400)
        XCTAssertEqual(score.total, 11_800)
    }

    func testTheBestAndSlowestBoards() {
        XCTAssertEqual(DailyResult(correctLetters: 50, judgedLetters: 50, seconds: 0).score.total, DailyScore.maxTotal)
        XCTAssertEqual(DailyScore.maxTotal, 13_000)
        // Past 20 minutes there's no bonus, and it never goes below 0.
        XCTAssertEqual(DailyResult(correctLetters: 50, judgedLetters: 50, seconds: 1_200).score.speedBonus, 0)
        XCTAssertEqual(DailyResult(correctLetters: 50, judgedLetters: 50, seconds: 5_000).score.total, 10_000)
    }

    func testCorrectnessUsesTheExactShare() {
        // 199/200 shows as 99%, but scores as 99.5%.
        let result = DailyResult(correctLetters: 199, judgedLetters: 200, seconds: 1_200)
        XCTAssertEqual(result.percent, 99)
        XCTAssertEqual(result.score.correctness, 9_950)
    }

    func testACarefulBoardBeatsARushedSloppyOne() {
        let careful = DailyResult(correctLetters: 50, judgedLetters: 50, seconds: 240)  // 12,400
        let rushed = DailyResult(correctLetters: 47, judgedLetters: 50, seconds: 120)   // 12,100
        XCTAssertTrue(careful.ranks(above: rushed))
        XCTAssertFalse(rushed.ranks(above: careful))
    }

    func testAFastNearlyPerfectBoardCanBeatASlowPerfectOne() {
        // Speed counts: that's what makes it a race.
        let slowPerfect = DailyResult(correctLetters: 50, judgedLetters: 50, seconds: 900)  // 10,750
        let fastNearly = DailyResult(correctLetters: 49, judgedLetters: 50, seconds: 180)   // 12,350
        XCTAssertTrue(fastNearly.ranks(above: slowPerfect))
    }

    func testEqualScoresGoToTheFasterBoard() {
        // 2,500 more correctness points exactly matches 1,000 seconds slower.
        let fast = DailyResult(correctLetters: 15, judgedLetters: 20, seconds: 200)  // 7,500 + 2,500
        let slow = DailyResult(correctLetters: 20, judgedLetters: 20, seconds: 1_200) // 10,000 + 0
        XCTAssertEqual(fast.score.total, slow.score.total)
        XCTAssertTrue(fast.ranks(above: slow))
    }

    func testOnlyAPerfectBoardShowsAHundredPercent() {
        XCTAssertEqual(DailyResult(correctLetters: 199, judgedLetters: 200, seconds: 1).percent, 99)
        XCTAssertEqual(DailyResult(correctLetters: 200, judgedLetters: 200, seconds: 1).percent, 100)
    }
}
