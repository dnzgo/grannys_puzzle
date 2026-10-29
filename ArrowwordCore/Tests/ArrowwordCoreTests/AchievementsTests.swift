import Foundation
import XCTest
@testable import ArrowwordCore

final class SolvedWordsTests: XCTestCase {
    func testEveryWordTypedRightCounts() throws {
        var state = PuzzleState(level: try TestLevels.wordSquare())
        state.fillBoard()

        // 4 across and 4 down.
        XCTAssertEqual(state.submit()?.solvedWords, 8)
    }

    func testAWordWithAWrongLetterDoesntCount() throws {
        var state = PuzzleState(level: try TestLevels.wordSquare())
        // (1, 1) and (2, 1) swapped: C and A wrong, in CARD and AREA across
        // and in the first column's CARD down.
        state.fillBoard(swapping: [(cell(1, 1), cell(2, 1))])

        XCTAssertEqual(state.submit()?.solvedWords, 5)
    }

    func testAWordGrandmaFilledAloneDoesntCountButOneTheCatHelpedWithDoes() throws {
        var state = PuzzleState(level: try TestLevels.wordSquare())
        // Grandma solves CARD across; every down word then has one of her
        // letters and three typed ones.
        state.revealActiveAnswer()
        state.fillBoard()

        XCTAssertEqual(state.submit()?.solvedWords, 7)
    }

    func testAWordOfStarterLettersOnlyDoesntCount() throws {
        var file = TestLevels.squareFile()
        file.givens = (1...4).map { cell(1, $0) }  // all of CARD across
        var state = PuzzleState(level: try Level(file: file))
        state.fillBoard()

        XCTAssertEqual(state.submit()?.solvedWords, 7)
    }
}

final class PlayStatsTests: XCTestCase {
    private func result(correct: Int, of judged: Int, revealed: Int = 0, words: Int = 3) -> LevelResult {
        LevelResult(correctLetters: correct, judgedLetters: judged, revealedLetters: revealed, solvedWords: words, rules: .standard)
    }

    func testAPassedLevelCountsItsWordsAndHowItWasPassed() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)

        _ = progress.record(result(correct: 10, of: 10), using: &generator)
        _ = progress.record(result(correct: 9, of: 10, revealed: 2, words: 2), using: &generator)

        XCTAssertEqual(progress.stats.wordsSolved, 5)
        XCTAssertEqual(progress.stats.perfectBoards, 1)
        XCTAssertEqual(progress.stats.levelsWithoutHelp, 1)
    }

    func testAFailedLevelCountsNothing() {
        // It's played again, and its words would count twice.
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)

        _ = progress.record(result(correct: 2, of: 10), using: &generator)

        XCTAssertEqual(progress.stats, PlayStats())
    }

    func testADailyCountsWhateverItsScore() throws {
        var progress = PlayerProgress.newPlayer
        _ = progress.startDaily(today: 100, levelID: "daily-1", now: Date(timeIntervalSince1970: 0))

        _ = progress.finishDaily(result(correct: 2, of: 10, words: 1), now: Date(timeIntervalSince1970: 60))

        XCTAssertEqual(progress.stats.dailiesFinished, 1)
        XCTAssertEqual(progress.stats.perfectDailies, 0)
        XCTAssertEqual(progress.stats.wordsSolved, 1)
    }

    func testTheLongestStreakStaysWhenTheStreakEnds() {
        var progress = PlayerProgress.newPlayer
        for day in 1...4 { progress.recordStreakDay(today: day) }
        // Days 5 and 6 missed: a new streak starts.
        progress.recordStreakDay(today: 7)

        XCTAssertEqual(progress.streakDays, 1)
        XCTAssertEqual(progress.stats.longestStreak, 4)
    }

    func testTheTotalsAreSaved() throws {
        var progress = PlayerProgress.newPlayer
        progress.stats.wordsSolved = 42
        progress.stats.perfectDailies = 2
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decoded.stats, progress.stats)
    }

    func testASaveFromBeforeTheTotalsStartsThemAtZeroButKeepsTheStreak() throws {
        let old = Data(#"{"version":2,"levelNumbers":{"en":5},"hints":2,"grandmas":1,"yarn":{},"streakDays":6,"lastStreakDay":40}"#.utf8)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: old)
        XCTAssertEqual(decoded.stats.wordsSolved, 0)
        XCTAssertEqual(decoded.stats.longestStreak, 6)
    }
}

final class AchievementsTests: XCTestCase {
    func testProgressIsTheShareOfTheTargetCappedAtAHundred() throws {
        var progress = PlayerProgress.newPlayer
        progress.stats.wordsSolved = 250
        let reports = Achievements.progress(for: progress, catalog: .standard)

        func percent(_ id: String) -> Double? { reports.first { $0.id == id }?.percentComplete }
        XCTAssertEqual(percent("grannyspuzzle.words.10"), 100)
        XCTAssertEqual(percent("grannyspuzzle.words.500"), 50)
        XCTAssertEqual(percent("grannyspuzzle.words.5000"), 5)
    }

    func testUntouchedAchievementsAreLeftOut() {
        XCTAssertEqual(Achievements.progress(for: .newPlayer, catalog: .standard), [])
    }

    func testLevelsAndLanguagesAddUpEveryLanguage() {
        var progress = PlayerProgress.newPlayer
        progress.levelNumbers = ["en": 8, "tr": 4]  // 7 + 3 passed
        XCTAssertEqual(Achievements.count(.levelsPassed, for: progress, catalog: .standard), 10)
        XCTAssertEqual(Achievements.count(.languagesPlayed, for: progress, catalog: .standard), 2)

        // A language opened but not passed in yet isn't played.
        progress.levelNumbers = ["en": 8, "tr": 1]
        XCTAssertEqual(Achievements.count(.languagesPlayed, for: progress, catalog: .standard), 1)
    }

    func testASetCountsOnlyWithEveryColour() throws {
        let catalog = KnittingCatalog.standard
        let scarves = catalog.items(for: .cat).filter { $0.kind == .scarf }
        var progress = PlayerProgress.newPlayer
        progress.wardrobe = Set(scarves.dropLast().map(\.id))
        XCTAssertEqual(Achievements.count(.setsCompleted, for: progress, catalog: catalog), 0)

        progress.wardrobe.insert(try XCTUnwrap(scarves.last).id)
        XCTAssertEqual(Achievements.count(.setsCompleted, for: progress, catalog: catalog), 1)
        XCTAssertEqual(Achievements.count(.itemsKnitted, for: progress, catalog: catalog), 4)
    }

    func testTheFullWardrobeIsTheCatsWholeWardrobe() {
        // "Full Wardrobe" is fixed at 20 (see Achievements.all): the cat's
        // wardrobe, the first one. If the cat's ever changes size, this
        // fails as a reminder to change the achievement with it.
        XCTAssertEqual(KnittingCatalog.standard.items(for: .cat).count, 20)
    }

    func testIDsAreUnique() {
        let ids = Achievements.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// The IDs must match App Store Connect, which is set up from
    /// docs/Achievements.md: an ID in one and not the other would report to
    /// nothing, or never be earned.
    func testTheDocListsExactlyTheseAchievements() throws {
        let doc = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ArrowwordCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ArrowwordCore
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("docs/Achievements.md")
        let text = try String(contentsOf: doc, encoding: .utf8)
        let documented = text.split(separator: "\n").compactMap { line -> String? in
            guard line.hasPrefix("| `grannyspuzzle.") else { return nil }
            return line.split(separator: "`").dropFirst().first.map(String.init)
        }
        XCTAssertEqual(documented, Achievements.all.map(\.id), "docs/Achievements.md and Achievements.all differ")
    }
}
