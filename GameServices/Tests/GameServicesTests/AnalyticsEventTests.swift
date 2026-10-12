import XCTest
@testable import GameServices

final class AnalyticsEventTests: XCTestCase {
    func testAGoodEventHasNoProblems() {
        let event = AnalyticsEvent("level_end", ["level": .int(12), "success": .bool(true), "language": .string("tr")])
        XCTAssertEqual(event.problems, [])
    }

    func testEventNamesFollowGooglesCharacterRules() {
        XCTAssertFalse(AnalyticsEvent("level end").problems.isEmpty, "no spaces")
        XCTAssertFalse(AnalyticsEvent("2nd_level").problems.isEmpty, "must start with a letter")
        XCTAssertFalse(AnalyticsEvent("seviye_bitti_ğ").problems.isEmpty, "ASCII letters only")
        XCTAssertFalse(AnalyticsEvent("").problems.isEmpty)
        XCTAssertFalse(AnalyticsEvent(String(repeating: "a", count: 41)).problems.isEmpty)
        XCTAssertEqual(AnalyticsEvent(String(repeating: "a", count: 40)).problems, [])
    }

    func testReservedNamesAndPrefixesAreCaught() {
        // "ad_reward" reads like a natural name for our rewarded videos,
        // which is exactly why the check exists: Analytics would drop it.
        XCTAssertFalse(AnalyticsEvent("ad_reward").problems.isEmpty)
        XCTAssertFalse(AnalyticsEvent("firebase_level").problems.isEmpty)
        XCTAssertFalse(AnalyticsEvent("level_end", ["ga_score": .int(1)]).problems.isEmpty)
    }

    func testParameterLimitsAreChecked() {
        let tooMany = Dictionary(uniqueKeysWithValues: (0...25).map { ("p\($0)", AnalyticsEvent.Value.int($0)) })
        XCTAssertFalse(AnalyticsEvent("busy", tooMany).problems.isEmpty)

        let longText = AnalyticsEvent("note", ["text": .string(String(repeating: "x", count: 101))])
        XCTAssertFalse(longText.problems.isEmpty)
    }
}

@MainActor
final class EventLoggerTests: XCTestCase {
    func testValidEventsReachTheBackend() {
        let backend = RecordingBackend()
        let logger = EventLogger(backend: backend, onInvalid: { _, _ in XCTFail("should be valid") })

        logger.log(AnalyticsEvent("tutorial_begin"))

        XCTAssertEqual(backend.sent.map(\.name), ["tutorial_begin"])
    }

    func testInvalidEventsAreReportedAndNotSent() {
        let backend = RecordingBackend()
        var reported: [String] = []
        let logger = EventLogger(backend: backend, onInvalid: { event, _ in reported.append(event.name) })

        logger.log(AnalyticsEvent("ad_reward"))

        XCTAssertEqual(reported, ["ad_reward"])
        XCTAssertEqual(backend.sent, [])
    }
}

@MainActor
private final class RecordingBackend: AnalyticsBackend {
    var sent: [AnalyticsEvent] = []
    func send(_ event: AnalyticsEvent) { sent.append(event) }
}
