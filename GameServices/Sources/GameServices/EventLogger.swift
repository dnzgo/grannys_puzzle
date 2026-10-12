import os

/// Where events go: Firebase in the app, a list in tests. One method, so a
/// new analytics service later means one new type, not changes in the game.
@MainActor
public protocol AnalyticsBackend: AnyObject {
    func send(_ event: AnalyticsEvent)
}

/// The app's way to record events. It checks each event against Google
/// Analytics' rules before passing it on, so a bad name is caught while
/// developing instead of being silently dropped in production.
@MainActor
public final class EventLogger {
    private let backend: any AnalyticsBackend
    /// What to do with an event that breaks the rules. Debug builds stop
    /// (a bug to fix now); release builds log and drop it rather than crash.
    private let onInvalid: (AnalyticsEvent, [String]) -> Void

    public init(
        backend: any AnalyticsBackend,
        onInvalid: @escaping (AnalyticsEvent, [String]) -> Void = EventLogger.reportInvalid
    ) {
        self.backend = backend
        self.onInvalid = onInvalid
    }

    public func log(_ event: AnalyticsEvent) {
        let problems = event.problems
        guard problems.isEmpty else {
            onInvalid(event, problems)
            return
        }
        backend.send(event)
    }

    public nonisolated static func reportInvalid(_ event: AnalyticsEvent, problems: [String]) {
        Logger(subsystem: "GameServices", category: "analytics")
            .error("Dropped invalid event \(event.name, privacy: .public): \(problems.joined(separator: "; "), privacy: .public)")
        assertionFailure("Invalid analytics event \(event.name): \(problems)")
    }
}
