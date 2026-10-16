import Foundation
import ArrowwordCore
import NotifyKit

/// Grandma's reminders for a player who just left: which ones, when, and
/// in which words. NotifyKit then applies the rules every game shares
/// (delivery hours, one a day, quiet after a week).
///
/// Each kind reacts to the player's real state, so a reminder always
/// says something true: the jar really is ready, the streak really is
/// about to break, she really is short of that colour.
enum GrannyReminders {
    /// The kinds, also used to report which ones bring players back.
    enum Kind: String {
        case jar
        case streak
        case yarn
        case missYou = "miss_you"
    }

    /// Timing, counted from when the player leaves: tomorrow, then a few
    /// days on, then once more near the end of the week. Fewer as time
    /// passes, rather than every day.
    private static let jarAfterDays = 1
    private static let yarnAfterDays = 3
    private static let missYouAfterDays = 6
    /// The streak reminder comes in the evening of its last day, late
    /// enough to catch a player who forgot, early enough to still play.
    private static let streakHour = 18

    /// - Parameter line: picks one of several lines for a kind, so the same
    ///   words don't come back every time (NotifyKit's shuffle bag).
    static func candidates(
        progress: PlayerProgress,
        catalog: KnittingCatalog,
        jarRules: DailyJarRules = .standard,
        now: Date,
        calendar: Calendar = .current,
        line: ([String], String) -> String?
    ) -> [Reminder] {
        var reminders: [Reminder] = []

        func add(_ kind: Kind, after days: Int, at hour: Int? = nil, lines: [String], priority: Int) {
            guard let body = line(lines, kind.rawValue),
                  var date = calendar.date(byAdding: .day, value: days, to: now)
            else { return }
            if let hour {
                date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
            }
            reminders.append(Reminder(kind: kind.rawValue, fireDate: date, title: ReminderLines.title, body: body, priority: priority))
        }

        // At the time of day they usually play: the same clock time they
        // left, a day on. People tend to play at the same times.
        add(.jar, after: jarAfterDays, lines: ReminderLines.jar, priority: 1)

        // A streak breaks on the first day without a jar: the day after the
        // last one collected. If a streak worth keeping is going (two days or
        // more), remind them that evening. It usually falls on the same day
        // as the jar reminder, and wins it (higher priority).
        // Not after the last day of a cycle: the jar starts a new one then
        // whatever they do, so "your streak starts over" wouldn't be true.
        if let lastJarDay = progress.lastJarDay,
           progress.jarStreak >= 2,
           progress.jarStreak < jarRules.streakLength {
            let today = JarDay.number(for: now, calendar: calendar)
            let daysUntilLastChance = lastJarDay + 1 - today
            if daysUntilLastChance >= 0 {
                add(.streak, after: daysUntilLastChance, at: streakHour,
                    lines: ReminderLines.streak(days: progress.jarStreak), priority: 2)
            }
        }

        if let need = progress.closestYarnNeed(in: catalog) {
            let color = need.color.name.lowercased(with: .appLanguage)
            add(.yarn, after: yarnAfterDays, lines: ReminderLines.yarn(color: color), priority: 1)
        }

        add(.missYou, after: missYouAfterDays, lines: ReminderLines.missYou, priority: 0)
        return reminders
    }
}
