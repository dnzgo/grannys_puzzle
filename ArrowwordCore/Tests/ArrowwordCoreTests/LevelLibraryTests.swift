import Foundation
import XCTest
@testable import ArrowwordCore

/// The level numbering across packs, and when the next pack is fetched.
final class LevelLibraryTests: XCTestCase {
    /// A pack of `count` copies of the test square, with ids that say which
    /// pack and place each has ("p2-7": pack 2, its 7th level).
    private func pack(_ number: Int, levels count: Int = LevelLibrary.packSize, language: String = "en") throws -> LevelPack {
        let levels = (1...count).map { index -> LevelFile in
            var file = TestLevels.squareFile(language: language)
            file.id = "p\(number)-\(index)"
            return file
        }
        return try LevelPack(file: LevelPackFile(formatVersion: 1, packId: "\(language)-\(number)", language: language, levels: levels))
    }

    // MARK: - Numbering

    func testLevelNumbersRunOnAcrossPacks() throws {
        let library = try LevelLibrary(packs: [pack(1), pack(2)])

        XCTAssertEqual(library.level(number: 1)?.id, "p1-1")
        XCTAssertEqual(library.level(number: 100)?.id, "p1-100")
        XCTAssertEqual(library.level(number: 101)?.id, "p2-1")
        XCTAssertEqual(library.level(number: 200)?.id, "p2-100")
        XCTAssertNil(library.level(number: 201), "pack 3 isn't here")
        XCTAssertNil(library.level(number: 0))
        XCTAssertEqual(library.levelCount, 200)
        XCTAssertEqual(library.nextPackNumber, 3)
    }

    func testAShortLastPackHoldsOnlyItsOwnLevels() throws {
        // The daily pack shipped with 30 puzzles: its place has room for 100.
        let library = try LevelLibrary(packs: [pack(1, levels: 30)])

        XCTAssertEqual(library.level(number: 30)?.id, "p1-30")
        XCTAssertNil(library.level(number: 31))
        XCTAssertEqual(library.levelCount, 30)
    }

    // MARK: - What may join

    func testNoPackMayFollowOneThatIsntFull() throws {
        // Pack 2 would then start at level 31 here but 101 everywhere else.
        var library = try LevelLibrary(packs: [pack(1, levels: 30)])
        XCTAssertThrowsError(try library.append(pack(2))) { error in
            XCTAssertEqual(error as? LevelLibrary.AppendError, .previousPackNotFull)
        }
    }

    func testRejectsAPackTooBigForItsPlace() throws {
        var library = LevelLibrary(language: "en")
        XCTAssertThrowsError(try library.append(pack(1, levels: 101))) { error in
            XCTAssertEqual(error as? LevelLibrary.AppendError, .packTooLarge(id: "en-1", levels: 101))
        }
    }

    func testRejectsAnotherLanguagesPack() throws {
        var library = try LevelLibrary(packs: [pack(1)])
        XCTAssertThrowsError(try library.append(pack(2, language: "tr"))) { error in
            XCTAssertEqual(error as? LevelLibrary.AppendError, .languageMismatch(expected: "en", found: "tr"))
        }
    }

    // MARK: - Fetching the next pack

    func testTheNextPackIsWantedOnce90LevelsOfTheLastArePlayed() throws {
        let one = try LevelLibrary(packs: [pack(1)])
        XCTAssertFalse(one.wantsNextPack(nextNumber: 90), "89 played")
        XCTAssertTrue(one.wantsNextPack(nextNumber: 91), "90 played")
        XCTAssertTrue(one.wantsNextPack(nextNumber: 101), "all played, still missing")

        // With two packs it's 90% of the second that counts.
        let two = try LevelLibrary(packs: [pack(1), pack(2)])
        XCTAssertFalse(two.wantsNextPack(nextNumber: 91))
        XCTAssertFalse(two.wantsNextPack(nextNumber: 190))
        XCTAssertTrue(two.wantsNextPack(nextNumber: 191))
    }
}
