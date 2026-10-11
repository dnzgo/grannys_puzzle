import Foundation
import XCTest
@testable import ArrowwordCore

/// Shorthand for coordinates in tests: `cell(1, 2)` reads like the grid.
func cell(_ row: Int, _ column: Int) -> Coordinate {
    Coordinate(row: row, column: column)
}

/// Files the app ships, read straight from the repo so tests check the real
/// thing rather than a copy.
enum ShippedFiles {
    /// <repo>/grannys_puzzle/Levels, found from this file's location:
    /// <repo>/ArrowwordCore/Tests/ArrowwordCoreTests/TestSupport.swift
    static var appLevelsFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ArrowwordCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ArrowwordCore
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("grannys_puzzle/Levels")
    }

    /// Languages with a shipped tutorial board.
    static let tutorialLanguages = ["en", "tr"]

    /// A tutorial's hand-made board.
    static func tutorialLevel(language: String = "en") throws -> Level {
        let url = appLevelsFolder.appendingPathComponent("tutorial-\(language).json")
        let pack = try LevelPack.decode(from: Data(contentsOf: url))
        return try XCTUnwrap(pack.levels.first)
    }
}

enum TestLevels {
    /// A 5×5 level whose 4×4 letter area is a word square: every row and
    /// column reads CARD, AREA, REAR, DART. Clue cells run along the top row
    /// and left column; the corner has no clue. No starter letters.
    ///
    /// Letter bag: A×5, R×5, D×2, E×2, C×1, T×1 (16 letters).
    static func squareFile(
        grid: [String] = ["#####", "#CARD", "#AREA", "#REAR", "#DART"],
        language: String = "en"
    ) -> LevelFile {
        LevelFile(
            formatVersion: 1,
            id: "test-square",
            clueLanguage: language,
            answerLanguage: language,
            grid: grid,
            clues: [
                .init(row: 0, column: 1, arrow: .down, text: "Birthday note"),
                .init(row: 0, column: 2, arrow: .down, text: "Zone"),
                .init(row: 0, column: 3, arrow: .down, text: "Back end"),
                .init(row: 0, column: 4, arrow: .down, text: "Dash off"),
                .init(row: 1, column: 0, arrow: .right, text: "Credit ___"),
                .init(row: 2, column: 0, arrow: .right, text: "Length times width"),
                .init(row: 3, column: 0, arrow: .right, text: "Raise kids"),
                .init(row: 4, column: 0, arrow: .right, text: "Pub missile"),
            ],
            givens: []
        )
    }

    static func wordSquare() throws -> Level {
        try Level(file: squareFile())
    }

    /// The 7×9 Level 100 from the design canvas, with four starter letters.
    static func level100() throws -> Level {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "level-100", withExtension: "json", subdirectory: "Fixtures"),
            "Fixture missing from the test bundle"
        )
        return try Level.decode(from: Data(contentsOf: url))
    }
}

extension PuzzleState {
    /// Test shortcut: select a cell (without toggling direction if it's
    /// already selected) and place a letter there.
    @discardableResult
    mutating func put(_ letter: Character, at target: Coordinate) -> Bool {
        if selection != target {
            select(target)
        }
        return place(letter)
    }

    /// Fills every empty cell with its correct letter, except that each pair
    /// in `swaps` gets the other cell's letter. Swapping keeps the letter
    /// counts valid, so every placement succeeds.
    mutating func fillBoard(swapping swaps: [(Coordinate, Coordinate)] = []) {
        var letters: [Coordinate: Character] = [:]
        for target in level.letterCells where entries[target] == nil {
            letters[target] = level.solution(at: target)
        }
        for (first, second) in swaps {
            let firstLetter = letters[first]
            letters[first] = letters[second]
            letters[second] = firstLetter
        }
        for target in level.letterCells {
            if let letter = letters[target] {
                XCTAssertTrue(put(letter, at: target), "Could not place \(letter) at \(target)")
            }
        }
    }
}
