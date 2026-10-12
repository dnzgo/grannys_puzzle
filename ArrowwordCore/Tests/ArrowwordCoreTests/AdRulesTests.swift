import XCTest
@testable import ArrowwordCore

final class AdBreakScheduleTests: XCTestCase {
    func testNewPlayersNeverGetABreak() {
        var schedule = AdBreakSchedule()
        for level in 1..<schedule.firstLevel {
            schedule.levelPassed(number: level)
            XCTAssertFalse(schedule.isBreakDue, "level \(level)")
            XCTAssertFalse(schedule.wantsAdsLoaded(forLevel: level), "level \(level)")
        }
    }

    func testTheFirstBreakComesAFewPassesAfterBreaksStart() {
        // Not straight after the first counting level: a player who just
        // reached it shouldn't be greeted by an ad.
        var schedule = AdBreakSchedule()
        schedule.levelPassed(number: schedule.firstLevel)
        XCTAssertFalse(schedule.isBreakDue)

        schedule.levelPassed(number: schedule.firstLevel + 1)
        XCTAssertTrue(schedule.isBreakDue)
    }

    func testTakingABreakStartsTheCountAgain() {
        var schedule = AdBreakSchedule()
        schedule.levelPassed(number: 20)
        schedule.levelPassed(number: 21)
        schedule.breakTaken()
        XCTAssertFalse(schedule.isBreakDue)

        schedule.levelPassed(number: 22)
        XCTAssertFalse(schedule.isBreakDue)
        schedule.levelPassed(number: 23)
        XCTAssertTrue(schedule.isBreakDue)
    }

    func testABreakTheAdsDeclinedStaysDue() {
        // E.g. the last ad was too recent: the next pass asks again rather
        // than waiting a whole new round.
        var schedule = AdBreakSchedule()
        schedule.levelPassed(number: 30)
        schedule.levelPassed(number: 31)
        schedule.levelPassed(number: 32)
        XCTAssertTrue(schedule.isBreakDue)
    }
}

final class RewardedAdLimitTests: XCTestCase {
    func testTheDailyVideosAreSharedAndRunOut() {
        var progress = PlayerProgress.newPlayer
        let today = 1_000

        for watched in 0..<PlayerProgress.rewardedAdsPerDay {
            XCTAssertEqual(progress.rewardedAdsLeft(today: today), PlayerProgress.rewardedAdsPerDay - watched)
            progress.recordRewardedAd(today: today)
        }
        XCTAssertEqual(progress.rewardedAdsLeft(today: today), 0)
    }

    func testANewDayStartsTheCountAgain() {
        var progress = PlayerProgress.newPlayer
        for _ in 0..<PlayerProgress.rewardedAdsPerDay {
            progress.recordRewardedAd(today: 1_000)
        }

        XCTAssertEqual(progress.rewardedAdsLeft(today: 1_001), PlayerProgress.rewardedAdsPerDay)
        progress.recordRewardedAd(today: 1_001)
        XCTAssertEqual(progress.rewardedAdsLeft(today: 1_001), PlayerProgress.rewardedAdsPerDay - 1)
    }

    func testTheCountSurvivesARestart() throws {
        // Otherwise closing and reopening the app would reset the cap.
        var progress = PlayerProgress.newPlayer
        progress.recordRewardedAd(today: 1_000)
        progress.recordRewardedAd(today: 1_000)

        let reloaded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))

        XCTAssertEqual(reloaded.rewardedAdsLeft(today: 1_000), PlayerProgress.rewardedAdsPerDay - 2)
    }

    func testASaveFromBeforeTheCapHasAFullDay() throws {
        let oldSave = Data(#"{"version":2,"levelNumbers":{"en":5},"hints":0,"grandmas":0,"yarn":{}}"#.utf8)
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: oldSave)
        XCTAssertEqual(progress.rewardedAdsLeft(today: 1_000), PlayerProgress.rewardedAdsPerDay)
    }
}
