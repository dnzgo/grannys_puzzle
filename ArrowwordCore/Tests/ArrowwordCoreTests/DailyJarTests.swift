import Foundation
import XCTest
@testable import ArrowwordCore

final class DailyJarTests: XCTestCase {
    /// An arbitrary day number to count from.
    private let monday = 740_000

    func testTheFirstJarIsDayOneAndPaysOut() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:])
        var generator = SeededGenerator(seed: 1)

        let opening = try XCTUnwrap(progress.openJar(today: monday, using: &generator))

        XCTAssertEqual(opening.streakDay, 1)
        XCTAssertEqual(progress.hints, opening.reward.hints)
        XCTAssertEqual(progress.grandmas, opening.reward.grandmas)
        XCTAssertGreaterThan(opening.reward.hints + opening.reward.grandmas, 0)
    }

    func testOnlyOneJarPerDay() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)
        XCTAssertNotNil(progress.openJar(today: monday, using: &generator))
        XCTAssertFalse(progress.canOpenJar(today: monday))
        XCTAssertNil(progress.openJar(today: monday, using: &generator), "a second tap the same day gives nothing")
        XCTAssertTrue(progress.canOpenJar(today: monday + 1))
    }

    func testConsecutiveDaysBuildTheStreakAndDaySevenGivesBoth() throws {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 2)
        var openings: [JarOpening] = []
        for offset in 0..<7 {
            openings.append(try XCTUnwrap(progress.openJar(today: monday + offset, using: &generator)))
        }
        XCTAssertEqual(openings.map(\.streakDay), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(openings.last?.reward, DailyJarRules.standard.bigReward)
        XCTAssertEqual(progress.jarStreak, 7)
    }

    func testAfterDaySevenANewCycleStarts() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jarStreak: 7, lastJarDay: monday)
        var generator = SeededGenerator(seed: 3)
        XCTAssertEqual(try XCTUnwrap(progress.openJar(today: monday + 1, using: &generator)).streakDay, 1)
    }

    func testMissingADayResetsTheStreak() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jarStreak: 4, lastJarDay: monday)
        var generator = SeededGenerator(seed: 4)
        XCTAssertEqual(progress.jarStreakDay(today: monday + 2), 1, "skipped a day")
        XCTAssertEqual(try XCTUnwrap(progress.openJar(today: monday + 2, using: &generator)).streakDay, 1)
    }

    func testOrdinaryDaysGiveOneToThreeCatsOrOneGrandma() {
        // Over many draws: never both, never nothing, cats within range,
        // and grandmas roughly at their 25% chance.
        let rules = DailyJarRules.standard
        var generator = SeededGenerator(seed: 5)
        var grandmaDays = 0
        for _ in 0..<1_000 {
            let reward = rules.reward(forStreakDay: 3, using: &generator)
            if reward.grandmas > 0 {
                grandmaDays += 1
                XCTAssertEqual(reward, JarReward(hints: 0, grandmas: 1))
            } else {
                XCTAssertTrue(rules.hintRange.contains(reward.hints), "\(reward.hints) cats")
            }
        }
        XCTAssertTrue((180...320).contains(grandmaDays), "\(grandmaDays) grandma days in 1000")
    }

    func testConsecutiveCalendarDaysGiveConsecutiveNumbers() throws {
        // Across a month end and a daylight-saving change (Europe, 25 Oct 2026).
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let date = { (day: Int, month: Int) in
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
        }
        let october24 = JarDay.number(for: try date(24, 10), calendar: calendar)
        XCTAssertEqual(JarDay.number(for: try date(25, 10), calendar: calendar), october24 + 1)
        XCTAssertEqual(JarDay.number(for: try date(1, 11), calendar: calendar), october24 + 8)
    }

    func testASaveFromBeforeTheJarStillLoads() throws {
        let oldSave = #"{"grandmas": 0, "hints": 0, "levelNumber": 12, "version": 1, "yarn": {}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))
        XCTAssertEqual(progress.jarStreak, 0)
        XCTAssertNil(progress.lastJarDay)
        XCTAssertTrue(progress.canOpenJar(today: monday))
    }
}
