import Foundation
import XCTest
@testable import ArrowwordCore

/// The level rules exist twice: in `Shared/level-rules.json`, which the
/// content pipeline reads, and in `LevelRules`, which the app uses. If they
/// drift apart, both sides' checks still "pass" while contradicting each
/// other. This test reads the shared file and fails on any difference.
final class LevelRulesSyncTests: XCTestCase {
    private struct SharedRules: Decodable {
        struct Grid: Decodable {
            let minRows: Int
            let maxRows: Int
            let minColumns: Int
            let maxColumns: Int
        }

        let formatVersion: Int
        let grid: Grid
        let maxDistinctLetters: Int
        let maxCluesPerCell: Int
        let maxGapShare: Double
        let maxShapeGapShare: Double
        let minAnswerLength: Int
        let alphabets: [String: String]
    }

    /// The repo root, found from this file's location:
    /// <repo>/ArrowwordCore/Tests/ArrowwordCoreTests/LevelRulesSyncTests.swift
    private var sharedRulesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ArrowwordCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ArrowwordCore
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Shared/level-rules.json")
    }

    private func loadSharedRules() throws -> SharedRules {
        let data = try Data(contentsOf: sharedRulesURL)
        return try JSONDecoder().decode(SharedRules.self, from: data)
    }

    func testLevelRulesMatchTheSharedFile() throws {
        let shared = try loadSharedRules()
        let rules = LevelRules.standard

        XCTAssertEqual(rules.supportedFormatVersion, shared.formatVersion)
        XCTAssertEqual(rules.rows, shared.grid.minRows...shared.grid.maxRows)
        XCTAssertEqual(rules.columns, shared.grid.minColumns...shared.grid.maxColumns)
        XCTAssertEqual(rules.maxDistinctLetters, shared.maxDistinctLetters)
        XCTAssertEqual(rules.maxCluesPerCell, shared.maxCluesPerCell)
        XCTAssertEqual(rules.maxGapShare, shared.maxGapShare)
        XCTAssertEqual(rules.maxShapeGapShare, shared.maxShapeGapShare)
        XCTAssertEqual(rules.minAnswerLength, shared.minAnswerLength)
    }

    func testAlphabetsMatchTheSharedFile() throws {
        let shared = try loadSharedRules()

        for (language, letters) in shared.alphabets {
            XCTAssertEqual(Alphabet.letters(for: language), Array(letters), "Alphabet for \(language)")
        }
    }
}
