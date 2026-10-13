import XCTest
@testable import NotifyKit

/// A fixed calendar and clock, so "10:00 tomorrow" means the same thing on
/// every machine and in every time zone the tests run in.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

/// 2026-10-13 at the given hour and minute, plus `days`.
private func date(days: Int = 0, _ hour: Int, _ minute: Int = 0) -> Date {
    let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: hour, minute: minute))!
    return calendar.date(byAdding: .day, value: days, to: base)!
}

private func reminder(_ kind: String, at fireDate: Date, priority: Int = 0) -> Reminder {
    Reminder(kind: kind, fireDate: fireDate, title: "Granny", body: kind, priority: priority)
}

final class ReminderPlannerTests: XCTestCase {
    private func plan(_ candidates: [Reminder], now: Date = date(18)) -> [Reminder] {
        ReminderPlanner.plan(candidates, now: now, calendar: calendar)
    }

    func testAReminderInsideTheDeliveryHoursKeepsItsTime() {
        XCTAssertEqual(plan([reminder("jar", at: date(days: 1, 15, 30))]).map(\.fireDate), [date(days: 1, 15, 30)])
    }

    func testRemindersOutsideTheHoursMoveToTheEdgeOfTheSameDay() {
        // 23:00 comes earlier, at 19:00; 06:00 later, at 10:00. Both keep
        // their day: an evening player gets tomorrow's reminder tomorrow.
        let result = plan([
            reminder("late", at: date(days: 1, 23)),
            reminder("early", at: date(days: 4, 6)),
        ])
        XCTAssertEqual(result.map(\.fireDate), [date(days: 1, 19), date(days: 4, 10)])
    }

    func testOnlyOneReminderADayAndTheMoreImportantWins() {
        let result = plan([
            reminder("jar", at: date(days: 1, 12), priority: 1),
            reminder("streak", at: date(days: 1, 19), priority: 2),
        ])
        XCTAssertEqual(result.map(\.kind), ["streak"])
    }

    func testAmongEqualsTheEarlierOneIsKept() {
        let result = plan([reminder("b", at: date(days: 1, 16)), reminder("a", at: date(days: 1, 11))])
        XCTAssertEqual(result.map(\.kind), ["a"])
    }

    func testRemindersStopAfterAWeekAway() {
        let result = plan([
            reminder("day6", at: date(days: 6, 12)),
            reminder("day8", at: date(days: 8, 12)),
        ])
        XCTAssertEqual(result.map(\.kind), ["day6"])
    }

    func testNothingIsPlannedInThePast() {
        XCTAssertEqual(plan([reminder("old", at: date(12))], now: date(18)), [])
    }

    func testTheResultIsInTimeOrder() {
        let result = plan([
            reminder("c", at: date(days: 3, 12)),
            reminder("a", at: date(days: 1, 12)),
            reminder("b", at: date(days: 2, 12)),
        ])
        XCTAssertEqual(result.map(\.kind), ["a", "b", "c"])
    }
}

final class ShuffleBagTests: XCTestCase {
    func testEveryLineIsUsedOnceBeforeAnyRepeats() {
        var bag = ShuffleBag(count: 5)
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            let round = (0..<5).compactMap { _ in bag.next(using: &generator) }
            XCTAssertEqual(Set(round), Set(0..<5), "each round deals every line once")
        }
    }

    func testTheSameLineNeverComesTwiceInARow() {
        // Across reshuffles too: the last line of one round can't open the next.
        var bag = ShuffleBag(count: 3)
        var generator = SystemRandomNumberGenerator()
        var previous: Int?
        for _ in 0..<300 {
            let next = bag.next(using: &generator)
            XCTAssertNotEqual(next, previous)
            previous = next
        }
    }

    func testOneLineIsAlwaysThatLineAndNoLinesIsNothing() {
        var generator = SystemRandomNumberGenerator()
        var one = ShuffleBag(count: 1)
        XCTAssertEqual(one.next(using: &generator), 0)
        XCTAssertEqual(one.next(using: &generator), 0)
        var none = ShuffleBag(count: 0)
        XCTAssertNil(none.next(using: &generator))
    }

    func testTheOrderSurvivesSavingAndLoading() throws {
        var bag = ShuffleBag(count: 4)
        var generator = SystemRandomNumberGenerator()
        _ = bag.next(using: &generator)
        var reloaded = try JSONDecoder().decode(ShuffleBag.self, from: JSONEncoder().encode(bag))
        var original = bag
        // The rest of this round was shuffled when it began, so no new
        // randomness is drawn: a bag that was saved and loaded must deal
        // exactly what the original deals.
        for _ in 0..<3 {
            XCTAssertEqual(reloaded.next(using: &generator), original.next(using: &generator))
        }
    }

    func testAddingALineStartsAFreshDeck() {
        XCTAssertEqual(ShuffleBag(count: 3).resized(to: 4).count, 4)
    }
}

@MainActor
final class RemindersTests: XCTestCase {
    private var defaults: UserDefaults!
    private var scheduler: FakeScheduler!

    override func setUp() async throws {
        let suite = "NotifyKitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        scheduler = FakeScheduler()
    }

    private func makeReminders() -> Reminders {
        Reminders(scheduler: scheduler, calendar: calendar, defaults: defaults)
    }

    func testNothingIsScheduledWithoutPermission() async {
        let reminders = makeReminders()
        await reminders.refreshPermission()  // not asked yet

        await reminders.schedule([reminder("jar", at: date(days: 1, 12))], now: date(18))

        XCTAssertEqual(scheduler.scheduled, [])
    }

    func testOnceAllowedTheRulesAreAppliedAndTheResultScheduled() async {
        scheduler.grants = true
        let reminders = makeReminders()
        await reminders.requestPermission()

        await reminders.schedule([
            reminder("jar", at: date(days: 1, 23)),  // too late: moves to 19:00 that day
        ], now: date(18))

        XCTAssertEqual(scheduler.scheduled.map(\.fireDate), [date(days: 1, 19)])
    }

    func testThePlayersSwitchStopsRemindersAndIsRemembered() async {
        scheduler.grants = true
        let reminders = makeReminders()
        await reminders.requestPermission()
        reminders.isEnabled = false

        await reminders.schedule([reminder("jar", at: date(days: 1, 12))], now: date(18))

        XCTAssertEqual(scheduler.scheduled, [])
        XCTAssertFalse(makeReminders().isEnabled, "a new launch reads the saved switch")
    }

    func testNotNowWaitsTwoWeeksAndTheGameStopsAskingAfterTwice() {
        let reminders = makeReminders()
        XCTAssertTrue(reminders.canOfferSoftAsk(now: date(12)))

        reminders.declineSoftAsk(now: date(12))
        XCTAssertFalse(reminders.canOfferSoftAsk(now: date(days: 13, 12)))
        XCTAssertTrue(reminders.canOfferSoftAsk(now: date(days: 14, 12)))

        reminders.declineSoftAsk(now: date(days: 14, 12))
        XCTAssertFalse(reminders.canOfferSoftAsk(now: date(days: 100, 12)))
    }

    func testOnceTheSystemHasAnsweredTheGameDoesNotAsk() async {
        scheduler.grants = false
        let reminders = makeReminders()
        await reminders.requestPermission()
        XCTAssertEqual(reminders.permission, .denied)
        XCTAssertFalse(reminders.canOfferSoftAsk(now: date(12)))
    }

    func testLeavingAndComingStraightBackLeavesNothingScheduled() async {
        // Scheduling is slow here (it adds after 50 ms); the cancel starts
        // at 10 ms, while it's still running, and must win because it came
        // last. Without the ordering, the cancel would clear at once and the
        // late add would leave the jar reminder behind.
        scheduler.grants = true
        scheduler.replaceDelay = .milliseconds(50)
        let reminders = makeReminders()
        await reminders.requestPermission()

        async let leaving: Void = reminders.schedule([reminder("jar", at: date(days: 1, 12))], now: date(18))
        try? await Task.sleep(for: .milliseconds(10))
        await reminders.cancelAll()
        await leaving

        XCTAssertEqual(scheduler.scheduled, [])
    }

    func testLinesDoNotRepeatBackToBackEvenAcrossLaunches() {
        let lines = ["a", "b", "c"]
        var previous: String?
        for _ in 0..<30 {
            // A new controller each time, like a new launch.
            let next = makeReminders().line(from: lines, kind: "jar")
            XCTAssertNotEqual(next, previous)
            previous = next
        }
    }
}

@MainActor
private final class FakeScheduler: ReminderScheduler {
    var grants = false
    /// Makes replacing take a while, like the real centre's several steps.
    var replaceDelay: Duration = .zero
    private var asked = false
    private(set) var scheduled: [Reminder] = []

    func permission() async -> NotificationPermission {
        asked ? (grants ? .allowed : .denied) : .notAsked
    }

    func requestPermission() async -> Bool {
        asked = true
        return grants
    }

    func replaceScheduled(with reminders: [Reminder]) async {
        // Like the real centre: removing is immediate, only adding takes
        // time. (If clearing were slow too, the ordering test below would
        // pass even without the ordering it checks.)
        scheduled = []
        if !reminders.isEmpty, replaceDelay > .zero { try? await Task.sleep(for: replaceDelay) }
        scheduled = reminders
    }
}
