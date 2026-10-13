import Foundation

/// One reminder a game would like to send.
public struct Reminder: Equatable, Sendable {
    /// What kind of reminder this is ("jar", "streak"…). Also how a tap on it
    /// is reported back, so analytics can tell which kinds bring players back.
    public let kind: String
    public let fireDate: Date
    public let title: String
    public let body: String
    /// When two reminders want the same day, the higher one is kept.
    public let priority: Int

    public init(kind: String, fireDate: Date, title: String, body: String, priority: Int = 0) {
        self.kind = kind
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.priority = priority
    }
}

/// The rules that keep reminders welcome. A game can tune them, but every
/// game gets them: the fastest way to lose a player is to nag them.
public struct ReminderRules: Equatable, Sendable {
    /// Hours of the day reminders may arrive (local time): from `start`
    /// up to, not including, `end`. A reminder due outside them moves to the
    /// nearest edge of the same day (an early one to 10:00, a late one to
    /// 19:00), so nobody is pinged at night and it still comes on its day.
    public var deliveryHours: Range<Int> = 10..<20
    /// At most one reminder per calendar day.
    public var maxPerDay = 1
    /// After this many days away, stop: a player who hasn't come back in a
    /// week has decided, and more pings only lead to the app being deleted.
    public var quietAfterDays = 7
    /// iOS keeps at most 64 pending notifications per app; staying well
    /// under leaves room and keeps the schedule easy to reason about.
    public var maxScheduled = 10

    public init() {}

    public static let standard = ReminderRules()
}

/// Turns the reminders a game would like into the ones actually scheduled.
///
/// A pure function: dates in, dates out, no notification centre. That's
/// where the rules that protect players live, so they can be tested by
/// handing it a calendar and a list, without waiting for real days.
public enum ReminderPlanner {
    /// - Parameters:
    ///   - candidates: what the game would like to send, in any order.
    ///   - now: when the player left the app; nothing is planned before it.
    public static func plan(
        _ candidates: [Reminder],
        now: Date,
        rules: ReminderRules = .standard,
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard let quietFrom = calendar.date(byAdding: .day, value: rules.quietAfterDays, to: now) else { return [] }

        let moved = candidates
            .compactMap { reminder -> Reminder? in
                guard let date = intoDeliveryHours(reminder.fireDate, rules: rules, calendar: calendar) else { return nil }
                return Reminder(kind: reminder.kind, fireDate: date, title: reminder.title, body: reminder.body, priority: reminder.priority)
            }
            .filter { $0.fireDate > now && $0.fireDate < quietFrom }

        // Per calendar day, keep the most important ones (earliest first
        // among equals), up to the daily limit.
        let byDay = Dictionary(grouping: moved) { calendar.startOfDay(for: $0.fireDate) }
        let kept = byDay.values.flatMap { sameDay in
            sameDay
                .sorted { ($0.priority, $1.fireDate) > ($1.priority, $0.fireDate) }
                .prefix(rules.maxPerDay)
        }

        return Array(kept.sorted { $0.fireDate < $1.fireDate }.prefix(rules.maxScheduled))
    }

    /// The same time if it's within the delivery hours; otherwise the
    /// nearest edge of the window on the same day: the first hour for an
    /// early one, the start of the last hour for a late one.
    ///
    /// Same day, not the next window: "tomorrow at the time you usually
    /// play" for an evening player should mean tomorrow evening, not the
    /// morning after (an earlier version did that, and skipped a day).
    static func intoDeliveryHours(_ date: Date, rules: ReminderRules, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: date)
        if rules.deliveryHours.contains(hour) { return date }
        let edge = hour < rules.deliveryHours.lowerBound
            ? rules.deliveryHours.lowerBound
            : rules.deliveryHours.upperBound - 1
        return calendar.date(bySettingHour: edge, minute: 0, second: 0, of: date)
    }
}
