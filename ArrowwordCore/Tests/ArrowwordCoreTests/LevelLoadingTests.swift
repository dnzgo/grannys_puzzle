import XCTest
@testable import ArrowwordCore

/// Loading a valid level: does the model match the grid we wrote?
final class LevelLoadingTests: XCTestCase {
    func testDecodesLevel100() throws {
        let level = try TestLevels.level100()

        XCTAssertEqual(level.rows, 9)
        XCTAssertEqual(level.columns, 7)
        XCTAssertEqual(level.answers.count, 25)
        XCTAssertEqual(level.letterCells.count, 45)
        XCTAssertEqual(level.givens.count, 4)
    }

    func testBentArrowsStartBesideTheClueAndTurn() throws {
        let level = try TestLevels.level100()

        // The corner's right-then-down arrow: starts to the right, reads down.
        let gateID = try XCTUnwrap(level.answerID(at: cell(0, 1), direction: .down))
        XCTAssertEqual(level.answers[gateID].solution, "GATE")
        XCTAssertEqual(level.answers[gateID].clueCell, cell(0, 0))

        // The corner's down-then-right arrow: starts below, reads across.
        let sagaID = try XCTUnwrap(level.answerID(at: cell(1, 0), direction: .across))
        XCTAssertEqual(level.answers[sagaID].solution, "SAGA")
        XCTAssertEqual(level.answers[sagaID].clueCell, cell(0, 0))
    }

    func testAnswersAreNumberedInReadingOrder() throws {
        let level = try TestLevels.level100()

        XCTAssertEqual(level.answers.map(\.id), Array(0..<level.answers.count))
        // Across answers come first, top to bottom...
        XCTAssertEqual(level.answers.first?.solution, "SAGA")
        // ...then down answers, left to right.
        XCTAssertEqual(level.answers.first(where: { $0.direction == .down })?.solution, "GATE")
        XCTAssertEqual(level.answers.last?.direction, .down)
    }

    func testSplitClueCellPutsTheRightExitingClueOnTop() throws {
        let level = try TestLevels.level100()

        let cornerArrows = level.answerIDs(atClueCell: cell(0, 0)).map { level.answers[$0].arrow }
        XCTAssertEqual(cornerArrows, [.rightDown, .downRight])

        let innerArrows = level.answerIDs(atClueCell: cell(2, 4)).map { level.answers[$0].arrow }
        XCTAssertEqual(innerArrows, [.right, .down])
    }

    func testTrayLettersFollowTheEnglishAlphabet() throws {
        let level = try TestLevels.level100()

        XCTAssertEqual(level.trayLetters, Array("ABDEGILMNOPSTU"))
    }

    func testTrayLettersFollowTheTurkishAlphabet() throws {
        // The words don't need to be real for this test; only the letters matter.
        let file = TestLevels.squareFile(
            grid: ["#####", "#ŞAİÇ", "#IZÜA", "#AAAA", "#AAAA"],
            language: "tr"
        )
        let level = try Level(file: file)

        // Sorting by Unicode would give A, I, Z, Ç, Ü, İ, Ş. Turkish order:
        XCTAssertEqual(level.trayLetters, Array("AÇIİŞÜZ"))
    }

    func testCellQueries() throws {
        let level = try TestLevels.wordSquare()

        XCTAssertTrue(level.isClueCell(cell(0, 0)))
        XCTAssertTrue(level.isLetterCell(cell(1, 1)))
        XCTAssertEqual(level.solution(at: cell(2, 3)), "E")
        XCTAssertNil(level.solution(at: cell(9, 9)), "Outside the grid is neither kind of cell")
        XCTAssertFalse(level.isClueCell(cell(9, 9)))
    }
}
