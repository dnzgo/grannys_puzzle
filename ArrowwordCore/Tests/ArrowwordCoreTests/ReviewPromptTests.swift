import XCTest
@testable import ArrowwordCore

final class ReviewPromptRulesTests: XCTestCase {
    private let rules = ReviewPromptRules.standard
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    func testNewPlayersAreNeverAsked() {
        XCTAssertFalse(rules.mayAsk(levelsPassed: 4, lastAsked: nil, now: now, calendar: calendar))
        XCTAssertTrue(rules.mayAsk(levelsPassed: 5, lastAsked: nil, now: now, calendar: calendar))
    }

    func testAfterAskingTheGameWaitsBeforeAskingAgain() {
        XCTAssertFalse(rules.mayAsk(levelsPassed: 50, lastAsked: daysAgo(119), now: now, calendar: calendar))
        XCTAssertTrue(rules.mayAsk(levelsPassed: 50, lastAsked: daysAgo(120), now: now, calendar: calendar))
    }
}
