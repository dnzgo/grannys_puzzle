import Foundation
import XCTest
@testable import ArrowwordCore

final class DailyJarTests: XCTestCase {
    /// An arbitrary day number to count from.
    private let monday = 740_000

    // MARK: - Collecting (the daily streak)

    func testTheFirstJarIsDayOneAndIsKeptUnopened() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:])
        var generator = SeededGenerator(seed: 1)

        let jar = try XCTUnwrap(progress.collectDailyJar(today: monday, using: &generator))

        XCTAssertEqual(jar.source, .daily(streakDay: 1))
        XCTAssertEqual(progress.jars, [jar])
        // Collecting doesn't pay out; opening does.
        XCTAssertEqual(progress.hints, 0)
        XCTAssertEqual(progress.grandmas, 0)
        XCTAssertGreaterThan(jar.reward.hints + jar.reward.grandmas, 0)
    }

    func testOnlyOneDailyJarPerDay() {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 1)
        XCTAssertNotNil(progress.collectDailyJar(today: monday, using: &generator))
        XCTAssertFalse(progress.canCollectDailyJar(today: monday))
        XCTAssertNil(progress.collectDailyJar(today: monday, using: &generator), "a second collect the same day gives nothing")
        XCTAssertTrue(progress.canCollectDailyJar(today: monday + 1))
        XCTAssertEqual(progress.jars.count, 1)
    }

    func testConsecutiveDaysBuildTheStreakAndDaySevenGivesBoth() throws {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 2)
        var jars: [Jar] = []
        for offset in 0..<7 {
            jars.append(try XCTUnwrap(progress.collectDailyJar(today: monday + offset, using: &generator)))
        }
        XCTAssertEqual(jars.map(\.source), (1...7).map { Jar.Source.daily(streakDay: $0) })
        XCTAssertEqual(jars.last?.reward, DailyJarRules.standard.bigReward)
        XCTAssertEqual(progress.jarStreak, 7)
    }

    /// The streak counts collecting, so a player saving their jars up for
    /// later keeps it.
    func testSavingJarsUpKeepsTheStreak() throws {
        var progress = PlayerProgress.newPlayer
        var generator = SeededGenerator(seed: 6)
        for offset in 0..<3 {
            _ = try XCTUnwrap(progress.collectDailyJar(today: monday + offset, using: &generator))
        }
        XCTAssertEqual(progress.jarStreak, 3)
        XCTAssertEqual(progress.jars.count, 3)
    }

    func testAfterDaySevenANewCycleStarts() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jarStreak: 7, lastJarDay: monday)
        var generator = SeededGenerator(seed: 3)
        XCTAssertEqual(try XCTUnwrap(progress.collectDailyJar(today: monday + 1, using: &generator)).source, .daily(streakDay: 1))
    }

    func testMissingADayResetsTheStreak() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jarStreak: 4, lastJarDay: monday)
        var generator = SeededGenerator(seed: 4)
        XCTAssertEqual(progress.jarStreakDay(today: monday + 2), 1, "skipped a day")
        XCTAssertEqual(try XCTUnwrap(progress.collectDailyJar(today: monday + 2, using: &generator)).source, .daily(streakDay: 1))
    }

    // MARK: - Opening

    func testOpeningPaysOutTheOldestJarFirst() throws {
        let first = Jar(reward: JarReward(hints: 2, grandmas: 0), source: .daily(streakDay: 1))
        let second = Jar(reward: JarReward(hints: 0, grandmas: 1), source: .daily(streakDay: 2))
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jars: [first, second])

        XCTAssertEqual(progress.openJar(), first)
        XCTAssertEqual(progress.hints, 2)
        XCTAssertEqual(progress.grandmas, 0)
        XCTAssertEqual(progress.jars, [second])
    }

    /// What's inside was decided when the jar was earned: a big jar stays
    /// big, however long it's kept.
    func testAKeptJarHoldsWhatItWasEarnedWith() throws {
        var progress = PlayerProgress(levelNumber: 1, hints: 0, grandmas: 0, yarn: [:], jarStreak: 6, lastJarDay: monday)
        var generator = SeededGenerator(seed: 7)
        let bigJar = try XCTUnwrap(progress.collectDailyJar(today: monday + 1, using: &generator))
        XCTAssertEqual(bigJar.reward, DailyJarRules.standard.bigReward)

        // A week later, after a broken streak.
        _ = progress.collectDailyJar(today: monday + 8, using: &generator)
        XCTAssertEqual(progress.openJar()?.reward, DailyJarRules.standard.bigReward)
    }

    func testNoJarNothingToOpen() {
        var progress = PlayerProgress.newPlayer
        XCTAssertNil(progress.openJar())
        XCTAssertEqual(progress.hints, PlayerProgress.newPlayer.hints)
    }

    func testASetJarIsKeptLikeTheOthers() {
        var progress = PlayerProgress.newPlayer
        progress.earnJar(DailyJarRules.standard.bigReward, source: .setComplete)

        XCTAssertEqual(progress.jars, [Jar(reward: DailyJarRules.standard.bigReward, source: .setComplete)])
        XCTAssertEqual(progress.hints, PlayerProgress.newPlayer.hints, "kept, not opened")
    }

    // MARK: - Draws and days

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

    // MARK: - Saving

    func testASaveFromBeforeTheJarStillLoads() throws {
        let oldSave = #"{"grandmas": 0, "hints": 0, "levelNumber": 12, "version": 1, "yarn": {}}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(oldSave.utf8))
        XCTAssertEqual(progress.jarStreak, 0)
        XCTAssertNil(progress.lastJarDay)
        XCTAssertTrue(progress.canCollectDailyJar(today: monday))
        XCTAssertEqual(progress.jars, [])
    }

    /// Unopened jars are part of the save, with what's inside them.
    func testUnopenedJarsAreSaved() throws {
        let jars = [
            Jar(reward: JarReward(hints: 3, grandmas: 1), source: .daily(streakDay: 7)),
            Jar(reward: JarReward(hints: 3, grandmas: 1), source: .setComplete),
        ]
        let progress = PlayerProgress(levelNumber: 4, hints: 1, grandmas: 0, yarn: [:], jars: jars)

        let reloaded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))

        XCTAssertEqual(reloaded.jars, jars)
    }
}
