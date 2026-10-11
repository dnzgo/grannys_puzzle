import XCTest
@testable import ArrowwordCore

final class TutorialCoachTests: XCTestCase {
    // MARK: - The shipped lesson

    /// The most important check: a new player who does exactly what grandma
    /// points at gets through the whole lesson to a perfect board. If the
    /// board file and the script ever drift apart, this is where it shows.
    func testFollowingGrandmaFinishesEveryShippedLessonWithAPerfectBoard() throws {
        for language in ShippedFiles.tutorialLanguages {
            let level = try ShippedFiles.tutorialLevel(language: language)
            XCTAssertEqual(level.answerLanguage, language)
            let script = try XCTUnwrap(TutorialScript.standard(for: language), "No script for \(language)")
            var coach = try XCTUnwrap(TutorialCoach(script: script, level: level), "\(language): script names a word the board lacks")
            var puzzle = PuzzleState(level: level)
            var linesSeen: [TutorialLine] = []

            // Bounded, so a lesson that stops moving fails instead of hanging.
            for _ in 0..<50 where !coach.isFinished {
                if let line = coach.line, linesSeen.last != line { linesSeen.append(line) }
                let action = try XCTUnwrap(Self.actionFollowingGrandma(coach, puzzle), "\(language): step \(coach.stepIndex) has nothing to do")
                XCTAssertTrue(coach.allows(action, on: puzzle), "\(language): grandma points at \(action) but refuses it")
                Self.perform(action, on: &puzzle)
                coach.didPerform(action, on: puzzle)
            }

            XCTAssertTrue(coach.isFinished, language)
            XCTAssertEqual(linesSeen, TutorialLine.allCases, "\(language): every step should be shown, in order")
            let result = try XCTUnwrap(puzzle.result, language)
            XCTAssertTrue(result.passed, language)
            XCTAssertEqual(result.yarnBalls, 3, language)
        }
    }

    func testEveryShippedLessonUsesBothHelpersOnRealWork() throws {
        // The cat and grandma steps must each have something to reveal, or
        // the player would tap the button and see nothing happen.
        for language in ShippedFiles.tutorialLanguages {
            let level = try ShippedFiles.tutorialLevel(language: language)
            let script = try XCTUnwrap(TutorialScript.standard(for: language))
            var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
            var puzzle = PuzzleState(level: level)

            for _ in 0..<50 where !coach.isFinished {
                guard let action = Self.actionFollowingGrandma(coach, puzzle) else { break }
                let filledBefore = puzzle.filledCount
                Self.perform(action, on: &puzzle)
                if action == .useCat { XCTAssertEqual(puzzle.filledCount, filledBefore + 1, "\(language): the cat revealed nothing") }
                if action == .useGrandma { XCTAssertGreaterThan(puzzle.filledCount, filledBefore + 1, "\(language): grandma should solve more than a letter") }
                coach.didPerform(action, on: puzzle)
            }
            XCTAssertTrue(coach.isFinished, language)
        }
    }

    func testThereIsNoLessonForALanguageWithoutABoard() {
        XCTAssertNil(TutorialScript.standard(for: "de"))
    }

    // MARK: - Staying on the lesson

    func testOnlyTheLetterGrandmaPointsAtIsAllowed() throws {
        let level = try ShippedFiles.tutorialLevel()
        var coach = try XCTUnwrap(TutorialCoach(script: .english, level: level))
        let puzzle = PuzzleState(level: level)
        // Past the two explaining steps, onto "type CAT".
        coach.didPerform(.next, on: puzzle)
        coach.didPerform(.next, on: puzzle)

        XCTAssertEqual(coach.line, .typeWord)
        XCTAssertEqual(coach.target(on: puzzle), .key("C"))
        XCTAssertTrue(coach.allows(.type("C"), on: puzzle))
        XCTAssertFalse(coach.allows(.type("A"), on: puzzle))
        XCTAssertFalse(coach.allows(.useCat, on: puzzle))
        XCTAssertFalse(coach.allows(.next, on: puzzle), "Next only belongs to explaining steps")
    }

    func testWhileGrandmaExplainsOnlyNextMovesOn() throws {
        let level = try ShippedFiles.tutorialLevel()
        var coach = try XCTUnwrap(TutorialCoach(script: .english, level: level))
        let puzzle = PuzzleState(level: level)

        XCTAssertTrue(coach.waitsForNext)
        XCTAssertNil(coach.target(on: puzzle))
        XCTAssertFalse(coach.allows(.selectClue(answerID: 0), on: puzzle))

        coach.didPerform(.next, on: puzzle)
        XCTAssertEqual(coach.line, .clueBox)
    }

    func testOnlyTheClueGrandmaPointsAtCanBeTapped() throws {
        let level = try ShippedFiles.tutorialLevel()
        let teaID = try XCTUnwrap(level.answers.first { $0.solution == "TEA" }?.id)
        let hatID = try XCTUnwrap(level.answers.first { $0.solution == "HAT" }?.id)
        let script = TutorialScript(steps: [.init(.tapClue, .selectClue(of: "TEA"))])
        let coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        let puzzle = PuzzleState(level: level)

        XCTAssertEqual(coach.target(on: puzzle), .clue(answerID: teaID))
        XCTAssertTrue(coach.allows(.selectClue(answerID: teaID), on: puzzle))
        XCTAssertFalse(coach.allows(.selectClue(answerID: hatID), on: puzzle))
    }

    // MARK: - Moving on

    func testAStepThatsAlreadyTrueIsPassedOver() throws {
        // The board opens with CAT selected, so "tap CAT's clue" is
        // already done when it comes up. Waiting on it would leave the
        // player stuck with nothing they're allowed to tap.
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [
            .init(.welcome, .read(pointingAt: nil)),
            .init(.tapClue, .selectClue(of: "CAT")),
            .init(.typeWord, .fill("CAT")),
        ])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        let puzzle = PuzzleState(level: level)

        coach.didPerform(.next, on: puzzle)

        XCTAssertEqual(coach.line, .typeWord)
    }

    func testFillingAWordFinishesItsStep() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [.init(.typeWord, .fill("CAT"))])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        var puzzle = PuzzleState(level: level)

        for letter in "CA" {
            puzzle.place(letter)
            coach.didPerform(.type(letter), on: puzzle)
        }
        XCTAssertFalse(coach.isFinished, "Two of three letters isn't the word yet")

        puzzle.place("T")
        coach.didPerform(.type("T"), on: puzzle)
        XCTAssertTrue(coach.isFinished)
        XCTAssertNil(coach.line)
        XCTAssertNil(coach.target(on: puzzle))
    }

    // MARK: - Checking the script against the board

    func testAScriptNamingAWordTheBoardLacksIsRejected() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [.init(.typeWord, .fill("DOG"))])
        XCTAssertNil(TutorialCoach(script: script, level: level))
    }

    func testAScriptNamingAWordTheBoardHasTwiceIsRejected() throws {
        // In a word square every word appears twice (once across, once down),
        // so "CARD" can't tell the coach which one to point at.
        let level = try TestLevels.wordSquare()
        XCTAssertEqual(level.answers.filter { $0.solution == "CARD" }.count, 2)
        let script = TutorialScript(steps: [.init(.typeWord, .fill("CARD"))])
        XCTAssertNil(TutorialCoach(script: script, level: level))
    }

    // MARK: - Helpers

    /// What a player does when they follow grandma: Next while she
    /// explains, otherwise whatever she points at.
    private static func actionFollowingGrandma(_ coach: TutorialCoach, _ puzzle: PuzzleState) -> TutorialAction? {
        if coach.waitsForNext { return .next }
        switch coach.target(on: puzzle) {
        case .clue(let id): return .selectClue(answerID: id)
        case .key(let letter): return .type(letter)
        case .cat: return .useCat
        case .grandma: return .useGrandma
        case .submit: return .submit
        case nil: return nil
        }
    }

    /// Does to the puzzle what the level's view model does for each action.
    private static func perform(_ action: TutorialAction, on puzzle: inout PuzzleState) {
        switch action {
        case .next: break
        case .selectClue(let id): puzzle.selectAnswer(id)
        case .type(let letter): puzzle.place(letter)
        case .useCat: puzzle.revealLetter()
        case .useGrandma: puzzle.revealActiveAnswer()
        case .submit: puzzle.submit()
        }
    }
}

final class TutorialProgressTests: XCTestCase {
    func testFinishingTheLessonGivesItsYarnOnce() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 3)
        XCTAssertFalse(progress.tutorialDone)

        let first = progress.completeTutorial(using: &generator)
        XCTAssertEqual(first.count, PlayerProgress.tutorialYarn)
        XCTAssertEqual(progress.totalYarn, PlayerProgress.tutorialYarn)
        XCTAssertTrue(progress.tutorialDone)
        XCTAssertEqual(progress.levelNumber, 1, "The lesson isn't a level; level 1 is still next")

        // A replay from Settings gives nothing more.
        XCTAssertEqual(progress.completeTutorial(using: &generator), [])
        XCTAssertEqual(progress.totalYarn, PlayerProgress.tutorialYarn)
    }

    func testTheLessonFlagIsSaved() throws {
        var progress = PlayerProgress.newPlayer
        progress.tutorialDone = true
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertTrue(decoded.tutorialDone)
    }

    func testASaveFromBeforeTheLessonSkipsItOnlyForPlayersPastLevelOne() throws {
        // Someone who has played on already knows how; someone still on
        // level 1 may never have finished a board, so they get the lesson.
        func oldSave(level: Int) -> Data {
            Data(#"{"version":1,"levelNumber":\#(level),"hints":2,"grandmas":1,"yarn":{}}"#.utf8)
        }
        XCTAssertTrue(try JSONDecoder().decode(PlayerProgress.self, from: oldSave(level: 12)).tutorialDone)
        XCTAssertFalse(try JSONDecoder().decode(PlayerProgress.self, from: oldSave(level: 1)).tutorialDone)
    }
}
