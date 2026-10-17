import XCTest
@testable import ArrowwordCore

/// Every rule in the level format spec has a test that breaks exactly that
/// rule and checks the level is rejected with the matching error.
final class LevelValidationTests: XCTestCase {
    private var square: LevelFile { TestLevels.squareFile() }

    func testTheValidSquareLoads() {
        // Guards the other tests: each one changes this file in one way, so
        // it has to be valid to begin with.
        XCTAssertNoThrow(try Level(file: square))
    }

    func testRejectsANewerFormatVersion() {
        var file = square
        file.formatVersion = 2
        assertRejects(file, with: .unsupportedFormatVersion(2))
    }

    func testRejectsAnUnsupportedLanguage() {
        var file = square
        file.answerLanguage = "xx"
        assertRejects(file, with: .unsupportedLanguage("xx"))
    }

    func testRejectsAGridWiderThanTheMaximum() {
        var file = square
        // 11 columns: one past the maximum of 10.
        file.grid = ["###########", "#CARDCARDCA", "#AREAAREAAR", "#REARREARRE", "#DARTDARTDA"]
        assertRejects(file, with: .gridSizeOutOfRange(rows: 5, columns: 11))
    }

    func testRejectsRowsOfDifferentLengths() {
        var file = square
        file.grid[2] = "#ARE"
        assertRejects(file, with: .raggedGrid(row: 2))
    }

    func testRejectsLowercaseLetters() {
        // The generator uppercases (language-aware); the app never does.
        var file = square
        file.grid[1] = "#cARD"
        assertRejects(file, with: .letterNotInAlphabet("c", at: cell(1, 1)))
    }

    func testRejectsAGridWithNoLetters() {
        var file = square
        file.grid = Array(repeating: "#####", count: 5)
        file.clues = []
        assertRejects(file, with: .noLetterCells)
    }

    func testRejectsAClueOutsideTheGrid() {
        var file = square
        file.clues.append(.init(row: 9, column: 9, arrow: .right, text: "Nowhere"))
        assertRejects(file, with: .clueOutsideGrid(cell(9, 9)))
    }

    func testRejectsAClueOnALetterCell() {
        var file = square
        file.clues.append(.init(row: 1, column: 1, arrow: .right, text: "Misplaced"))
        assertRejects(file, with: .clueNotOnClueCell(cell(1, 1)))
    }

    func testRejectsMoreCluesInACellThanAllowed() {
        var rules = LevelRules()
        rules.maxCluesPerCell = 0
        assertRejects(square, rules: rules, with: .tooManyClues(at: cell(0, 1)))
    }

    func testRejectsAnswersShorterThanTheMinimum() {
        var rules = LevelRules()
        rules.minAnswerLength = 5
        assertRejects(square, rules: rules, with: .answerTooShort(clueAt: cell(0, 1)))
    }

    func testRejectsTwoAnswersOverTheSameCellsInOneDirection() {
        var file = square
        file.clues.append(.init(row: 0, column: 1, arrow: .down, text: "Duplicate"))
        assertRejects(file, with: .overlappingAnswers(at: cell(1, 1), .down))
    }

    func testRejectsALetterCellThatNoAnswerCovers() {
        var file = square
        // Remove both clues through (1, 1): column 1 down and row 1 across.
        file.clues.removeAll { $0.row == 0 && $0.column == 1 }
        file.clues.removeAll { $0.row == 1 && $0.column == 0 }
        assertRejects(file, with: .letterCellWithoutAnswer(cell(1, 1)))
    }

    func testRejectsMoreDistinctLettersThanTheTrayHolds() {
        var rules = LevelRules()
        rules.maxDistinctLetters = 5
        assertRejects(square, rules: rules, with: .tooManyDistinctLetters(6))
    }

    func testRejectsAStarterLetterOnAClueCell() {
        var file = square
        file.givens = [cell(0, 0)]
        assertRejects(file, with: .givenNotOnLetterCell(cell(0, 0)))
    }

    // MARK: - Helper

    private func assertRejects(
        _ file: LevelFile,
        rules: LevelRules = .standard,
        with expected: LevelError,
        file sourceFile: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try Level(file: file, rules: rules), file: sourceFile, line: line) { error in
            XCTAssertEqual(error as? LevelError, expected, file: sourceFile, line: line)
        }
    }
}
