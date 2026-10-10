import Foundation
import XCTest
@testable import ArrowwordCore

final class LevelPackTests: XCTestCase {
    /// A pack of two valid copies of the test square, with different ids.
    private func packFile() -> LevelPackFile {
        var first = TestLevels.squareFile()
        first.id = "en-000001"
        var second = TestLevels.squareFile()
        second.id = "en-000002"
        return LevelPackFile(formatVersion: 1, packId: "test-pack", language: "en", levels: [first, second])
    }

    func testDecodesAPackAndKeepsTheLevelOrder() throws {
        let data = try JSONEncoder().encode(packFile())
        let pack = try LevelPack.decode(from: data)

        XCTAssertEqual(pack.id, "test-pack")
        XCTAssertEqual(pack.language, "en")
        XCTAssertEqual(pack.levels.map(\.id), ["en-000001", "en-000002"])
    }

    func testRejectsANewerPackFormat() {
        var file = packFile()
        file.formatVersion = 2
        assertRejects(file, with: .unsupportedFormatVersion(2))
    }

    func testRejectsAnEmptyPack() {
        var file = packFile()
        file.levels = []
        assertRejects(file, with: .noLevels)
    }

    func testReportsWhichLevelIsBrokenAndWhy() {
        // Breaking the second level must name it, so it can be found in a
        // 100-level file, and keep the level's own reason.
        var file = packFile()
        file.levels[1].givens = [cell(0, 0)]
        assertRejects(file, with: .invalidLevel(index: 1, id: "en-000002", .givenNotOnLetterCell(cell(0, 0))))
    }

    func testRejectsALevelInAnotherLanguage() {
        var file = packFile()
        file.levels[0].answerLanguage = "tr"
        assertRejects(file, with: .languageMismatch(levelID: "en-000001", expected: "en", found: "tr"))
    }

    func testRejectsTwoLevelsWithTheSameID() {
        var file = packFile()
        file.levels[1].id = "en-000001"
        assertRejects(file, with: .duplicateLevelID("en-000001"))
    }

    // MARK: - The packs the app ships

    /// Every pack in the app's Levels folder must load. The pipeline checks
    /// levels with its own Python validator; this checks them again with the
    /// rules the app will actually apply, so a disagreement between the two
    /// fails here instead of on a player's phone.
    func testEveryShippedPackLoads() throws {
        let packURLs = try shippedPackURLs()
        XCTAssertFalse(packURLs.isEmpty, "No packs found in \(appLevelsFolder.path)")

        for url in packURLs {
            XCTAssertNoThrow(try LevelPack.decode(from: Data(contentsOf: url)), url.lastPathComponent)
        }
    }

    /// <repo>/grannys_puzzle/Levels, found from this file's location:
    /// <repo>/ArrowwordCore/Tests/ArrowwordCoreTests/LevelPackTests.swift
    private var appLevelsFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ArrowwordCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ArrowwordCore
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("grannys_puzzle/Levels")
    }

    /// Pack files are the JSON files whose top level has a "levels" list;
    /// single-level files such as level-100.json are skipped.
    private func shippedPackURLs() throws -> [URL] {
        let names = try FileManager.default.contentsOfDirectory(atPath: appLevelsFolder.path)
        return try names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .map { appLevelsFolder.appendingPathComponent($0) }
            .filter { url in
                let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
                return (object as? [String: Any])?["levels"] != nil
            }
    }

    // MARK: - Helper

    private func assertRejects(
        _ file: LevelPackFile,
        with expected: LevelPackError,
        file sourceFile: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try LevelPack(file: file), file: sourceFile, line: line) { error in
            XCTAssertEqual(error as? LevelPackError, expected, file: sourceFile, line: line)
        }
    }
}
