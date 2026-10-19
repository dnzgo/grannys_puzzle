import XCTest
@testable import ArrowwordCore

final class TutorialCoachTests: XCTestCase {
    /// The English board's words the tests point at (tutorial-en.json):
    /// the one the player types, the two sharing the square they turn on
    /// (across, then down), and the one grandma solves.
    private let typedWord = "TEA"
    private let turnedFromWord = "GIRL"
    private let turnedWord = "BITE"
    private let grandmasWord = "ME"

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

    func testEveryShippedBoardIsBiggerThanTheCloseUp() throws {
        // The lesson opens on the close-up, 5×5 squares (BoardMetrics in
        // the app), and asks to pinch out: on a board no bigger, there'd be
        // nothing more to see.
        for language in ShippedFiles.tutorialLanguages {
            let level = try ShippedFiles.tutorialLevel(language: language)
            XCTAssertGreaterThan(level.rows, 5, language)
            XCTAssertGreaterThan(level.columns, 5, language)
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

    func testEveryShippedLessonNeedsBothTapsToSwitchDirection() throws {
        // The board is laid out so the first tap on the shared square only
        // selects it, still reading across: the second tap is the lesson.
        for language in ShippedFiles.tutorialLanguages {
            let level = try ShippedFiles.tutorialLevel(language: language)
            let script = try XCTUnwrap(TutorialScript.standard(for: language))
            var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
            var puzzle = PuzzleState(level: level)

            for _ in 0..<50 where !coach.isFinished && coach.line != .switchDirection {
                let action = try XCTUnwrap(Self.actionFollowingGrandma(coach, puzzle))
                Self.perform(action, on: &puzzle)
                coach.didPerform(action, on: puzzle)
            }
            guard case .cell(let square) = coach.target(on: puzzle) else { return XCTFail("\(language): no square to tap") }

            puzzle.select(square)
            coach.didPerform(.selectCell(square), on: puzzle)
            XCTAssertEqual(coach.line, .switchDirection, "\(language): one tap already switched")
            puzzle.select(square)
            coach.didPerform(.selectCell(square), on: puzzle)
            XCTAssertEqual(coach.line, .catHelps, language)

            // The square is empty, so the cat fills the one just selected.
            XCTAssertNil(puzzle.entries[square], "\(language): the square to turn on should be empty")
            XCTAssertEqual(puzzle.revealLetter(), square, language)
        }
    }

    func testThereIsNoLessonForALanguageWithoutABoard() {
        XCTAssertNil(TutorialScript.standard(for: "de"))
    }

    // MARK: - Staying on the lesson

    func testTheZoomStepsWaitForTheirOwnPinch() throws {
        let level = try ShippedFiles.tutorialLevel()
        var coach = try XCTUnwrap(TutorialCoach(script: .english, level: level))
        let puzzle = PuzzleState(level: level)

        XCTAssertEqual(coach.line, .zoomOut)
        XCTAssertEqual(coach.target(on: puzzle), .zoomOut)
        XCTAssertFalse(coach.allows(.zoomIn, on: puzzle), "Pinching in first isn't what she asked")
        coach.didPerform(.zoomIn, on: puzzle)
        XCTAssertEqual(coach.line, .zoomOut)

        coach.didPerform(.zoomOut, on: puzzle)
        XCTAssertEqual(coach.line, .zoomIn)
        XCTAssertEqual(coach.target(on: puzzle), .zoomIn)
        coach.didPerform(.zoomIn, on: puzzle)
        XCTAssertEqual(coach.line, .clueBox)
    }

    func testOnlyTheLetterGrandmaPointsAtIsAllowed() throws {
        let level = try ShippedFiles.tutorialLevel()
        var coach = try XCTUnwrap(TutorialCoach(script: .english, level: level))
        var puzzle = PuzzleState(level: level)
        let typedID = try XCTUnwrap(level.answers.first { $0.solution == typedWord }?.id)
        // Past the pinches and the clue, onto typing.
        coach.didPerform(.zoomOut, on: puzzle)
        coach.didPerform(.zoomIn, on: puzzle)
        puzzle.selectAnswer(typedID)
        coach.didPerform(.selectClue(answerID: typedID), on: puzzle)

        let first = try XCTUnwrap(typedWord.first)
        let wrong = try XCTUnwrap(level.trayLetters.first { $0 != first })
        XCTAssertEqual(coach.line, .typeWord)
        XCTAssertEqual(coach.target(on: puzzle), .key(first))
        XCTAssertTrue(coach.allows(.type(first), on: puzzle))
        XCTAssertFalse(coach.allows(.type(wrong), on: puzzle))
        XCTAssertFalse(coach.allows(.useCat, on: puzzle))
        XCTAssertFalse(coach.allows(.selectCell(puzzle.selection), on: puzzle), "Squares are only for switching direction")
        XCTAssertFalse(coach.allows(.next, on: puzzle), "Next only belongs to explaining steps")
    }

    func testWhileGrandmaExplainsOnlyNextMovesOn() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [
            .init(.zoomOut, .read(pointingAt: nil)),
            .init(.clueBox, .read(pointingAt: typedWord)),
        ])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        let puzzle = PuzzleState(level: level)

        XCTAssertTrue(coach.waitsForNext)
        XCTAssertNil(coach.target(on: puzzle))
        XCTAssertFalse(coach.allows(.selectClue(answerID: 0), on: puzzle))
        XCTAssertFalse(coach.allows(.zoomOut, on: puzzle))

        coach.didPerform(.next, on: puzzle)
        XCTAssertEqual(coach.line, .clueBox)
    }

    func testOnlyTheClueGrandmaPointsAtCanBeTapped() throws {
        let level = try ShippedFiles.tutorialLevel()
        let typedID = try XCTUnwrap(level.answers.first { $0.solution == typedWord }?.id)
        let otherID = try XCTUnwrap(level.answers.first { $0.solution == grandmasWord }?.id)
        let script = TutorialScript(steps: [.init(.clueBox, .selectClue(of: typedWord))])
        let coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        let puzzle = PuzzleState(level: level)

        XCTAssertEqual(coach.target(on: puzzle), .clue(answerID: typedID))
        XCTAssertTrue(coach.allows(.selectClue(answerID: typedID), on: puzzle))
        XCTAssertFalse(coach.allows(.selectClue(answerID: otherID), on: puzzle))
    }

    func testSwitchingDirectionTakesTheSharedSquareTwice() throws {
        let level = try ShippedFiles.tutorialLevel()
        let typed = try XCTUnwrap(level.answers.first { $0.solution == typedWord })
        let across = try XCTUnwrap(level.answers.first { $0.solution == turnedFromWord })
        let turned = try XCTUnwrap(level.answers.first { $0.solution == turnedWord })
        let shared = try XCTUnwrap(Set(across.cells).intersection(turned.cells).first)
        let other = try XCTUnwrap(across.cells.first { $0 != shared })
        let script = TutorialScript(steps: [.init(.switchDirection, .switchDirection(from: turnedFromWord, to: turnedWord))])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        var puzzle = PuzzleState(level: level)
        // Somewhere else, reading across, as after typing the first word.
        puzzle.selectAnswer(typed.id)

        XCTAssertEqual(coach.target(on: puzzle), .cell(shared))
        XCTAssertEqual(coach.litAnswerID(on: puzzle), turned.id, "The word to turn into is lit")
        XCTAssertFalse(coach.allows(.selectCell(other), on: puzzle))
        XCTAssertTrue(coach.allows(.selectCell(shared), on: puzzle))

        // Reading across, the first tap selects the square and the second
        // turns down into the other word.
        puzzle.select(shared)
        coach.didPerform(.selectCell(shared), on: puzzle)
        XCTAssertFalse(coach.isFinished, "Still reading across after one tap")
        puzzle.select(shared)
        coach.didPerform(.selectCell(shared), on: puzzle)
        XCTAssertTrue(coach.isFinished)
    }

    // MARK: - Moving on

    func testAStepThatsAlreadyTrueIsPassedOver() throws {
        // The board opens with some word selected, so "tap that word's
        // clue" is already done when it comes up. Waiting on it would leave
        // the player stuck with nothing they're allowed to tap.
        let level = try ShippedFiles.tutorialLevel()
        let puzzle = PuzzleState(level: level)
        let selected = try XCTUnwrap(puzzle.activeAnswer?.solution)
        let script = TutorialScript(steps: [
            .init(.zoomOut, .read(pointingAt: nil)),
            .init(.clueBox, .selectClue(of: selected)),
            .init(.typeWord, .fill(selected)),
        ])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))

        coach.didPerform(.next, on: puzzle)

        XCTAssertEqual(coach.line, .typeWord)
    }

    func testFillingAWordFinishesItsStep() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [.init(.typeWord, .fill(typedWord))])
        var coach = try XCTUnwrap(TutorialCoach(script: script, level: level))
        var puzzle = PuzzleState(level: level)
        puzzle.selectAnswer(try XCTUnwrap(level.answers.first { $0.solution == typedWord }?.id))

        for letter in typedWord.dropLast() {
            puzzle.place(letter)
            coach.didPerform(.type(letter), on: puzzle)
        }
        XCTAssertFalse(coach.isFinished, "All but one letter isn't the word yet")

        let last = try XCTUnwrap(typedWord.last)
        puzzle.place(last)
        coach.didPerform(.type(last), on: puzzle)
        XCTAssertTrue(coach.isFinished)
        XCTAssertNil(coach.line)
        XCTAssertNil(coach.target(on: puzzle))
    }

    // MARK: - Checking the script against the board

    func testAScriptNamingAWordTheBoardLacksIsRejected() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [.init(.typeWord, .fill("QQQ"))])
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

    func testAScriptSwitchingBetweenWordsThatDontCrossIsRejected() throws {
        let level = try ShippedFiles.tutorialLevel()
        let script = TutorialScript(steps: [.init(.switchDirection, .switchDirection(from: typedWord, to: grandmasWord))])
        XCTAssertNil(TutorialCoach(script: script, level: level))
    }

    // MARK: - Helpers

    /// What a player does when they follow grandma: Next while she
    /// explains, otherwise whatever she points at.
    private static func actionFollowingGrandma(_ coach: TutorialCoach, _ puzzle: PuzzleState) -> TutorialAction? {
        if coach.waitsForNext { return .next }
        switch coach.target(on: puzzle) {
        case .zoomOut: return .zoomOut
        case .zoomIn: return .zoomIn
        case .clue(let id): return .selectClue(answerID: id)
        case .cell(let cell): return .selectCell(cell)
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
        case .next, .zoomOut, .zoomIn: break
        case .selectClue(let id): puzzle.selectAnswer(id)
        case .selectCell(let cell): puzzle.select(cell)
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
