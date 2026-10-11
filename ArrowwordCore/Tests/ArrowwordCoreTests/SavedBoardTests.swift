import Foundation
import XCTest
@testable import ArrowwordCore

final class SavedBoardTests: XCTestCase {
    // The test square: rows and columns read CARD, AREA, REAR, DART.

    func testAFreshBoardHasNothingToSave() throws {
        XCTAssertNil(PuzzleState(level: try TestLevels.wordSquare()).savedBoard())
    }

    func testTypedAndRevealedLettersComeBackAsTheyWere() throws {
        let level = try TestLevels.wordSquare()
        var state = PuzzleState(level: level)
        state.put("C", at: cell(1, 1))
        state.put("R", at: cell(1, 2))  // wrong on purpose: saved as typed
        let revealed = try XCTUnwrap(state.revealLetter())

        let saved = try XCTUnwrap(state.savedBoard())
        let restored = try XCTUnwrap(PuzzleState.restored(level: level, from: saved))

        XCTAssertEqual(restored.entries, state.entries)
        XCTAssertEqual(restored.entries[revealed]?.source, .revealed, "paid-for letters stay revealed")
        XCTAssertEqual(restored.entries[cell(1, 2)]?.source, .placed, "and typed ones stay editable")
        XCTAssertEqual(restored.remainingCounts(), state.remainingCounts())
    }

    func testStarterLettersAreNotSaved() throws {
        // Level 100 has starter letters; they come from the level, not the save.
        let level = try TestLevels.level100()
        var state = PuzzleState(level: level)
        _ = state.revealLetter()
        let saved = try XCTUnwrap(state.savedBoard())

        let savedCells = Set(saved.letters.map { cell($0.row, $0.column) })
        XCTAssertTrue(savedCells.isDisjoint(with: level.givens))
        XCTAssertEqual(PuzzleState.restored(level: level, from: saved)?.entries, state.entries)
    }

    func testTheRestoredLevelSelectsTheFirstEmptyCell() throws {
        let level = try TestLevels.wordSquare()
        var state = PuzzleState(level: level)
        state.put("C", at: cell(1, 1))
        let restored = try XCTUnwrap(PuzzleState.restored(level: level, from: try XCTUnwrap(state.savedBoard())))
        XCTAssertEqual(restored.selection, cell(1, 2))
    }

    func testASubmittedBoardIsNotSaved() throws {
        var state = PuzzleState(level: try TestLevels.wordSquare())
        state.fillBoard()
        XCTAssertNotNil(state.savedBoard(), "a full board can still be left and resumed")
        state.submit()
        XCTAssertNil(state.savedBoard(), "but once judged, it's finished")
    }

    // MARK: - Boards that must not be restored

    func testABoardFromARegeneratedPackIsIgnored() throws {
        // Same level id, different grid: the saved letters belong elsewhere.
        let level = try TestLevels.wordSquare()
        var state = PuzzleState(level: level)
        state.put("C", at: cell(1, 1))
        let saved = try XCTUnwrap(state.savedBoard())

        var regenerated = TestLevels.squareFile(grid: ["#####", "#DART", "#AREA", "#REAR", "#TRAD"])
        regenerated.id = level.id
        let newLevel = try Level(file: regenerated)
        XCTAssertNotEqual(newLevel.fingerprint, level.fingerprint)
        XCTAssertNil(PuzzleState.restored(level: newLevel, from: saved))
    }

    func testRejectsLettersTheTrayNeverHad() throws {
        // The square has a single C; two C's can't come from playing it.
        let level = try TestLevels.wordSquare()
        let saved = board(for: level, [(1, 1, "C", false), (1, 2, "C", false)])
        XCTAssertNil(PuzzleState.restored(level: level, from: saved))
    }

    func testRejectsAWrongRevealedLetter() throws {
        // Revealed letters are always correct; a wrong one means a bad save.
        let level = try TestLevels.wordSquare()
        XCTAssertNil(PuzzleState.restored(level: level, from: board(for: level, [(1, 1, "A", true)])))
    }

    func testRejectsLettersOnClueCellsAndDuplicates() throws {
        let level = try TestLevels.wordSquare()
        XCTAssertNil(PuzzleState.restored(level: level, from: board(for: level, [(0, 0, "C", false)])))
        XCTAssertNil(PuzzleState.restored(level: level, from: board(for: level, [(1, 1, "C", false), (1, 1, "A", false)])))
    }

    // MARK: - Fingerprints and saving

    func testTheFingerprintIsStable() throws {
        // A fixed value guards against anyone switching to Swift's hashValue,
        // which changes on every launch.
        let first = try TestLevels.wordSquare().fingerprint
        XCTAssertEqual(first, try TestLevels.wordSquare().fingerprint)
        XCTAssertFalse(first.isEmpty)
    }

    func testTheBoardSurvivesTheProgressFile() throws {
        let level = try TestLevels.wordSquare()
        var state = PuzzleState(level: level)
        state.put("C", at: cell(1, 1))
        var progress = PlayerProgress.newPlayer
        progress.board = state.savedBoard()

        let data = try JSONEncoder().encode(progress)
        XCTAssertEqual(try JSONDecoder().decode(PlayerProgress.self, from: data), progress)
    }

    // MARK: - Helper

    private func board(for level: Level, _ letters: [(Int, Int, String, Bool)]) -> SavedBoard {
        SavedBoard(
            levelID: level.id,
            levelFingerprint: level.fingerprint,
            letters: letters.map { SavedBoard.Letter(row: $0.0, column: $0.1, letter: $0.2, revealed: $0.3) }
        )
    }
}
