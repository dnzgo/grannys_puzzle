import XCTest
@testable import ArrowwordCore

/// Playing a level: selecting, placing, erasing, the cat and grandma, and
/// submitting. Most tests use the 4×4 word square, whose letter counts are
/// small enough to reason about by hand (A×5, R×5, D×2, E×2, C×1, T×1).
final class PuzzleStateTests: XCTestCase {
    private func newSquareGame() throws -> PuzzleState {
        PuzzleState(level: try TestLevels.wordSquare())
    }

    // MARK: - Starting

    func testStartsOnTheFirstEmptyCellReadingAcross() throws {
        let state = try newSquareGame()

        XCTAssertEqual(state.selection, cell(1, 1))
        XCTAssertEqual(state.direction, .across)
        XCTAssertEqual(state.activeAnswer?.solution, "CARD")
    }

    func testStartSkipsStarterLettersAndPicksADirectionThatHasAnAnswer() throws {
        let state = PuzzleState(level: try TestLevels.level100())

        // (0, 1) is a starter letter, so the first empty cell is (0, 3).
        // That cell has no across answer, so the game reads down.
        XCTAssertEqual(state.selection, cell(0, 3))
        XCTAssertEqual(state.direction, .down)
        XCTAssertEqual(state.entries.count, 4)
    }

    // MARK: - Selecting

    func testTappingTheSelectedCellSwitchesDirection() throws {
        var state = try newSquareGame()

        state.select(cell(1, 1))

        XCTAssertEqual(state.direction, .down)
        XCTAssertEqual(state.activeAnswerID, state.level.answerID(at: cell(1, 1), direction: .down))
    }

    func testClueCellsCannotBeSelected() throws {
        var state = try newSquareGame()

        state.select(cell(0, 0))

        XCTAssertEqual(state.selection, cell(1, 1))
    }

    func testSelectingAnAnswerJumpsToItsFirstEmptyCell() throws {
        var state = try newSquareGame()
        state.put("A", at: cell(2, 1))

        state.selectAnswer(try XCTUnwrap(state.level.answerID(at: cell(2, 1), direction: .across)))

        XCTAssertEqual(state.selection, cell(2, 2))
        XCTAssertEqual(state.direction, .across)
    }

    func testPreviousAnswerWrapsAroundFromTheFirst() throws {
        var state = try newSquareGame()  // starts on answer 0

        state.selectPreviousAnswer()

        XCTAssertEqual(state.activeAnswerID, state.level.answers.count - 1)
    }

    // MARK: - Placing and erasing

    func testPlacingALetterMovesToTheNextCellInTheAnswer() throws {
        var state = try newSquareGame()

        XCTAssertTrue(state.place("C"))

        XCTAssertEqual(state.entries[cell(1, 1)], PuzzleState.Entry(letter: "C", source: .placed))
        XCTAssertEqual(state.selection, cell(1, 2))
    }

    func testTrayCountsAreDerivedFromTheBoard() throws {
        var state = try newSquareGame()
        XCTAssertEqual(state.remaining("A"), 5)

        state.put("A", at: cell(1, 2))

        XCTAssertEqual(state.remaining("A"), 4)
    }

    func testALetterWithNoTilesLeftCannotBePlaced() throws {
        var state = try newSquareGame()
        state.put("C", at: cell(1, 1))  // the only C

        XCTAssertFalse(state.put("C", at: cell(2, 1)))

        XCTAssertNil(state.entries[cell(2, 1)])
        XCTAssertEqual(state.remaining("C"), 0)
    }

    func testReplacingALetterReturnsTheOldTileToTheTray() throws {
        var state = try newSquareGame()
        state.put("A", at: cell(1, 1))
        XCTAssertEqual(state.remaining("A"), 4)

        // C is available only if the replacement is handled in the right
        // order: the A comes off first.
        XCTAssertTrue(state.put("C", at: cell(1, 1)))

        XCTAssertEqual(state.remaining("A"), 5)
        XCTAssertEqual(state.remaining("C"), 0)
    }

    func testEraseRemovesThePlacedLetter() throws {
        var state = try newSquareGame()
        state.put("C", at: cell(1, 1))
        state.select(cell(1, 1))

        XCTAssertTrue(state.erase())

        XCTAssertNil(state.entries[cell(1, 1)])
    }

    func testEraseOnAnEmptyCellStepsBackLikeBackspace() throws {
        var state = try newSquareGame()
        state.put("C", at: cell(1, 1))  // cursor moves on to (1, 2), which is empty

        XCTAssertTrue(state.erase())

        XCTAssertEqual(state.selection, cell(1, 1))
        XCTAssertNil(state.entries[cell(1, 1)])
    }

    func testStarterLettersCannotBeChanged() throws {
        var state = PuzzleState(level: try TestLevels.level100())
        state.select(cell(0, 1))  // a starter "G"

        XCTAssertFalse(state.place("A"))
        XCTAssertFalse(state.erase(), "Nothing before the first cell of the answer to step back to")
        XCTAssertEqual(state.entries[cell(0, 1)]?.source, .given)
    }

    // MARK: - The cat (one letter)

    func testCatRevealsTheSelectedCell() throws {
        var state = try newSquareGame()

        XCTAssertEqual(state.revealLetter(), cell(1, 1))

        XCTAssertEqual(state.entries[cell(1, 1)], PuzzleState.Entry(letter: "C", source: .revealed))
        XCTAssertEqual(state.selection, cell(1, 2))
    }

    func testCatTakesBackAMisplacedCopyWhenNoTileIsLeft() throws {
        var state = try newSquareGame()
        // Swap the first two letters of CARD: A in C's cell, C in A's cell.
        state.put("A", at: cell(1, 1))
        state.put("C", at: cell(1, 2))
        state.select(cell(1, 1))

        XCTAssertEqual(state.revealLetter(), cell(1, 1))

        // The only C was at (1, 2), in the wrong place, so it moved to (1, 1).
        XCTAssertEqual(state.entries[cell(1, 1)], PuzzleState.Entry(letter: "C", source: .revealed))
        XCTAssertNil(state.entries[cell(1, 2)], "The misplaced C leaves an empty cell behind")
        XCTAssertEqual(state.remaining("C"), 0)
        XCTAssertEqual(state.remaining("A"), 5)
    }

    func testRevealedLettersCannotBeChanged() throws {
        var state = try newSquareGame()
        state.revealLetter()
        state.select(cell(1, 1))

        XCTAssertFalse(state.place("A"))
        XCTAssertEqual(state.entries[cell(1, 1)]?.source, .revealed)
    }

    // MARK: - Grandma (whole word)

    func testGrandmaRevealsTheWholeActiveAnswer() throws {
        var state = try newSquareGame()
        state.select(cell(2, 1))  // AREA, across

        let revealed = state.revealActiveAnswer()

        XCTAssertEqual(revealed, [cell(2, 1), cell(2, 2), cell(2, 3), cell(2, 4)])
        for target in revealed {
            XCTAssertEqual(state.entries[target]?.letter, state.level.solution(at: target))
            XCTAssertEqual(state.entries[target]?.source, .revealed)
        }
    }

    func testGrandmaFixesWrongLettersAndKeepsCorrectOnes() throws {
        var state = try newSquareGame()
        state.put("A", at: cell(1, 1))  // wrong (C belongs here)
        state.put("A", at: cell(1, 2))  // right
        state.select(cell(1, 1))

        let revealed = state.revealActiveAnswer()

        XCTAssertEqual(revealed, [cell(1, 1), cell(1, 3), cell(1, 4)])
        XCTAssertEqual(state.entries[cell(1, 2)]?.source, .placed, "Correct letters stay the player's")
    }

    func testGrandmaOnACorrectAnswerRevealsNothing() throws {
        var state = try newSquareGame()
        for (column, letter) in zip(1...4, "CARD") {
            state.put(letter, at: cell(1, column))
        }
        state.select(cell(1, 1))

        XCTAssertEqual(state.revealActiveAnswer(), [], "Empty result tells the caller not to charge")
    }

    // MARK: - Submitting

    func testSubmitNeedsAFullBoard() throws {
        var state = try newSquareGame()

        XCTAssertNil(state.submit())
        XCTAssertFalse(state.isSubmitted)
    }

    func testAPerfectBoardEarnsThreeYarnBalls() throws {
        var state = try newSquareGame()
        state.fillBoard()

        let result = try XCTUnwrap(state.submit())

        XCTAssertEqual(result.yarnBalls, 3)
        XCTAssertTrue(result.passed)
    }

    func testOneSwapCostsTwoLetters() throws {
        // The tray counts letters exactly, so one letter in the wrong cell
        // always forces a second wrong letter somewhere else.
        var state = try newSquareGame()
        state.fillBoard(swapping: [(cell(1, 1), cell(1, 2))])

        let result = try XCTUnwrap(state.submit())

        XCTAssertEqual(result.correctLetters, 14)
        XCTAssertEqual(result.judgedLetters, 16)
        XCTAssertEqual(result.yarnBalls, 1, "14 / 16 = 87.5%: above 80%, below 90%")
        XCTAssertTrue(result.passed)
    }

    func testABoardBelowTheThresholdFails() throws {
        var state = try newSquareGame()
        state.fillBoard(swapping: [
            (cell(1, 1), cell(1, 2)),
            (cell(3, 1), cell(3, 2)),
            (cell(2, 3), cell(2, 4)),
            (cell(4, 1), cell(4, 4)),
        ])

        let result = try XCTUnwrap(state.submit())

        XCTAssertEqual(result.correctLetters, 8)
        XCTAssertEqual(result.yarnBalls, 0)
        XCTAssertFalse(result.passed)
    }

    func testHelpersDoNotCostYarn() throws {
        var state = try newSquareGame()
        state.revealActiveAnswer()  // grandma does CARD
        state.fillBoard()

        XCTAssertEqual(state.submit()?.yarnBalls, 3)
    }

    func testStarterLettersAreNotJudged() throws {
        var state = PuzzleState(level: try TestLevels.level100())
        state.fillBoard()

        let result = try XCTUnwrap(state.submit())

        XCTAssertEqual(result.judgedLetters, 45 - 4)
    }

    func testWrongLettersStayHiddenUntilSubmit() throws {
        var state = try newSquareGame()
        state.fillBoard(swapping: [(cell(1, 1), cell(1, 2))])

        XCTAssertFalse(state.isWrong(cell(1, 1)))
        state.submit()
        XCTAssertTrue(state.isWrong(cell(1, 1)))
        XCTAssertFalse(state.isWrong(cell(1, 3)))
    }

    func testTheBoardIsLockedAfterSubmit() throws {
        var state = try newSquareGame()
        state.fillBoard()
        state.submit()
        state.select(cell(1, 1))

        XCTAssertFalse(state.place("A"))
        XCTAssertFalse(state.erase())
        XCTAssertNil(state.revealLetter())
        XCTAssertNil(state.submit(), "A board is judged once")
    }

    func testRestartKeepsOnlyTheStarterLetters() throws {
        var state = PuzzleState(level: try TestLevels.level100())
        state.fillBoard()
        state.submit()

        state.restart()

        XCTAssertEqual(state.entries.count, 4)
        XCTAssertFalse(state.isSubmitted)
    }
}
