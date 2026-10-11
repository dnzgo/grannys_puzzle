import Foundation
import XCTest
@testable import ArrowwordCore

/// A seeded random generator (SplitMix64), so tests of random drops are
/// repeatable. The system generator can't be seeded.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// A result with the given share of correct letters, scored by the standard rules.
private func result(correct: Int, of judged: Int) -> LevelResult {
    LevelResult(correctLetters: correct, judgedLetters: judged, rules: .standard)
}

final class YarnDropperTests: XCTestCase {
    func testDrawsTheRequestedNumberOfBalls() {
        var generator = SeededGenerator(seed: 1)
        XCTAssertEqual(YarnDropper().draw(3, given: [:], using: &generator).count, 3)
        XCTAssertEqual(YarnDropper().draw(0, given: [:], using: &generator), [])
    }

    func testTheColourYouHaveLeastOfIsTheLikeliest() {
        // The rule itself, without randomness: 0 balls → weight 1, 9 → 0.1.
        let dropper = YarnDropper(colors: [.red, .blue])
        XCTAssertEqual(dropper.weights(given: [.red: 9]), [0.1, 1.0])
    }

    func testBadLuckProtectionShowsUpOverManyDraws() {
        // A player with lots of red and no blue should mostly get blue.
        let dropper = YarnDropper()
        let bag: [YarnColor: Int] = [.red: 20, .yellow: 20, .green: 20]
        var generator = SeededGenerator(seed: 42)
        var blue = 0
        for _ in 0..<1_000 where dropper.draw(1, given: bag, using: &generator) == [.blue] {
            blue += 1
        }
        // Blue's weight is 1 against 3 × 1/21, so its share is about 88%.
        XCTAssertGreaterThan(blue, 800)
    }

    func testOneRewardSpreadsAcrossColours() {
        // Within one reward, each ball counts toward the next one's odds.
        // Three balls of the same colour from two colours is then 1/3 × 1/4
        // = 1 in 12, so about 92% of rewards should be mixed.
        let dropper = YarnDropper(colors: [.red, .blue])
        var generator = SeededGenerator(seed: 7)
        var mixed = 0
        for _ in 0..<200 where Set(dropper.draw(3, given: [:], using: &generator)).count == 2 {
            mixed += 1
        }
        XCTAssertGreaterThan(mixed, 150)
    }

    func testTheSameSeedGivesTheSameColours() {
        var first = SeededGenerator(seed: 99)
        var second = SeededGenerator(seed: 99)
        XCTAssertEqual(
            YarnDropper().draw(5, given: [:], using: &first),
            YarnDropper().draw(5, given: [:], using: &second)
        )
    }
}

final class PlayerProgressTests: XCTestCase {
    func testANewPlayerStartsAtLevelOneWithHelpersAndAnEmptyBag() {
        let progress = PlayerProgress.newPlayer
        XCTAssertEqual(progress.levelNumber, 1)
        XCTAssertEqual(progress.hints, 4)
        XCTAssertEqual(progress.grandmas, 1)
        XCTAssertEqual(progress.totalYarn, 0)
    }

    func testAPassAwardsYarnByScoreAndMovesOn() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)

        let perfect = progress.record(result(correct: 20, of: 20), using: &generator)
        XCTAssertEqual(perfect.count, 3)
        let good = progress.record(result(correct: 18, of: 20), using: &generator)
        XCTAssertEqual(good.count, 2, "90% earns 2 balls")
        let pass = progress.record(result(correct: 16, of: 20), using: &generator)
        XCTAssertEqual(pass.count, 1, "80% passes with 1 ball")

        XCTAssertEqual(progress.levelNumber, 4)
        XCTAssertEqual(progress.totalYarn, 6)
        // The bag holds exactly the balls that were handed out.
        for color in YarnColor.allCases {
            let awarded = (perfect + good + pass).filter { $0 == color }.count
            XCTAssertEqual(progress.yarnCount(of: color), awarded, "\(color)")
        }
    }

    func testAFailAwardsNothingAndStaysOnTheLevel() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)
        XCTAssertEqual(progress.record(result(correct: 10, of: 20), using: &generator), [])
        XCTAssertEqual(progress, .newPlayer)
    }

    func testHelpersCannotGoBelowZero() {
        var progress = PlayerProgress.newPlayer
        progress.grandmas = 1
        XCTAssertTrue(progress.spendGrandma())
        XCTAssertFalse(progress.spendGrandma(), "the second one isn't paid for")
        XCTAssertEqual(progress.grandmas, 0)
    }
}

final class ProgressStoreTests: XCTestCase {
    private var folder: URL!
    private var store: ProgressStore!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = ProgressStore(fileURL: folder.appendingPathComponent("progress.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testNoSaveYetMeansANewPlayer() throws {
        XCTAssertEqual(try store.load(), .newPlayer)
    }

    func testSavedProgressLoadsBackUnchanged() throws {
        let progress = PlayerProgress(levelNumber: 12, hints: 2, grandmas: 0, yarn: [.red: 3, .green: 1])
        try store.save(progress)
        XCTAssertEqual(try store.load(), progress)
    }

    func testTheYarnBagIsSavedAsReadableJSON() throws {
        // Guards the CodingKeyRepresentable choice on YarnColor: without it the
        // bag would be saved as ["red", 3] instead of {"red": 3}.
        try store.save(PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [.red: 3]))
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"red\" : 3"), text)
    }

    func testADamagedFileIsReportedNotSilentlyReplaced() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        XCTAssertThrowsError(try store.load())

        let backup = try store.setAsideDamagedFile(now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(backup.lastPathComponent, "progress-damaged-100.json")
        XCTAssertEqual(try Data(contentsOf: backup), Data("not json".utf8), "the damaged data is kept")
        XCTAssertEqual(try store.load(), .newPlayer, "and the next load starts fresh")
    }

    func testRejectsAFileFromANewerAppVersion() throws {
        // A newer format this version can't decode at all: only the version
        // field is familiar. It must still be reported as "too new".
        let newer = PlayerProgress.currentVersion + 1
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"version": \#(newer), "wallet": {"cats": 3}}"#.utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? ProgressStoreError, .unsupportedVersion(newer))
        }
    }
}

final class PerLanguageProgressTests: XCTestCase {
    func testEachLanguageKeepsItsOwnLevel() {
        var progress = PlayerProgress.newPlayer
        progress.levelNumber = 40

        progress.activeLanguage = "tr"
        XCTAssertEqual(progress.levelNumber, 1, "Turkish starts at its own level 1")
        progress.levelNumber = 3

        progress.activeLanguage = "en"
        XCTAssertEqual(progress.levelNumber, 40, "and English is where it was")
    }

    func testPassingALevelMovesOnlyTheActiveLanguage() {
        var progress = PlayerProgress.newPlayer
        progress.activeLanguage = "tr"
        var generator = SeededGenerator(seed: 5)

        _ = progress.record(LevelResult(correctLetters: 10, judgedLetters: 10, rules: .standard), using: &generator)

        XCTAssertEqual(progress.levelNumbers, ["en": 1, "tr": 2])
    }

    func testAVersionOneSaveBecomesEnglishProgress() throws {
        // Before per-language progress there was only the English pack.
        let oldSave = #"{"version": 1, "levelNumber": 23, "hints": 2, "grandmas": 1, "yarn": {}}"#
        var progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))

        XCTAssertEqual(progress.levelNumbers, ["en": 23])
        XCTAssertEqual(progress.version, PlayerProgress.currentVersion, "converted, so the next save is current")
        progress.activeLanguage = "tr"
        XCTAssertEqual(progress.levelNumber, 1)
    }

    func testBothLanguagesSurviveSaving() throws {
        var progress = PlayerProgress.newPlayer
        progress.levelNumber = 12
        progress.activeLanguage = "tr"
        progress.levelNumber = 5

        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))

        XCTAssertEqual(decoded.levelNumbers, ["en": 12, "tr": 5])
        XCTAssertEqual(decoded.activeLanguage, "en", "the active language isn't saved; the app sets it at launch")
    }
}
