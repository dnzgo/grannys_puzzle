import Foundation
import ArrowwordCore
import NotifyKit

/// Grandma's reminders for a player who just left: which ones, when, and
/// in which words. NotifyKit then applies the rules every game shares
/// (delivery hours, one a day, quiet after a week).
///
/// Each kind reacts to the player's real state, so a reminder always
/// says something true: the jar really is ready, the streak really is
/// about to break, the puzzle really is half done, she really is short of
/// that colour. The schedule is redone every time the app opens or leaves,
/// so one that stopped being true (the streak was kept) is replaced.
///
/// A week away, roughly: day 1 the jar (or the streak, when it's at stake),
/// day 2 the half-done puzzle, day 3 knitting, day 4 the daily challenge,
/// day 6 "I miss you". Each day keeps only its most important one.
enum GrannyReminders {
    /// The kinds, also used to report which ones bring players back.
    enum Kind: String {
        case jar
        case streak
        case streakSave = "streak_save"
        case unfinished
        case knit
        case yarn
        case daily
        case missYou = "miss_you"
    }

    private static let jarAfterDays = 1
    private static let unfinishedAfterDays = 2
    /// Knitting: there's enough for something, or she's short of a colour.
    private static let knitAfterDays = 3
    private static let dailyAfterDays = 4
    private static let missYouAfterDays = 6
    /// The streak reminders come in the evening, late enough to catch a
    /// player who forgot, early enough to still play.
    private static let streakHour = 18
    /// A streak worth a reminder: one day isn't a streak yet.
    private static let streakMinimumDays = 2

    /// Above the usual reminders, so a streak at stake wins its day.
    private enum Priority {
        static let streak = 2
        static let normal = 1
        static let low = 0
    }

    /// - Parameters:
    ///   - hasDailyChallenge: the build has daily puzzles to remind about.
    ///   - line: picks one of several lines for a kind, so the same words
    ///     don't come back every time (NotifyKit's shuffle bag).
    static func candidates(
        progress: PlayerProgress,
        catalog: KnittingCatalog,
        hasDailyChallenge: Bool,
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
        add(.jar, after: jarAfterDays, lines: ReminderLines.jar, priority: Priority.normal)

        // The play streak (the flame on the home screen). Its last chance is
        // the day after the last solve: that evening, if a streak worth
        // keeping is going. Missed anyway, it can still be saved the day
        // after with a video, so one more reminder then.
        let today = JarDay.number(for: now, calendar: calendar)
        switch progress.streakStatus(today: today) {
        case .active(let days, let solvedToday) where days >= streakMinimumDays:
            let lastChance = solvedToday ? 1 : 0
            add(.streak, after: lastChance, at: streakHour, lines: ReminderLines.streak(days: days), priority: Priority.streak)
            add(.streakSave, after: lastChance + 1, at: streakHour, lines: ReminderLines.streakSave(days: days), priority: Priority.streak)
        case .canSave(let days) where days >= streakMinimumDays:
            add(.streakSave, after: 0, at: streakHour, lines: ReminderLines.streakSave(days: days), priority: Priority.streak)
        default:
            break
        }

        if progress.board != nil {
            add(.unfinished, after: unfinishedAfterDays, lines: ReminderLines.unfinished, priority: Priority.normal)
        }

        // Something to knit now, or the colour she's closest to needing
        // (closestYarnNeed is nil while something can be knitted, so it's
        // one or the other).
        if let item = catalog.knittableItems(for: progress).first {
            let name = item.displayName.lowercased(with: .appLanguage)
            add(.knit, after: knitAfterDays, lines: ReminderLines.knit(item: name), priority: Priority.normal)
        } else if let need = progress.closestYarnNeed(in: catalog) {
            let color = need.color.name.lowercased(with: .appLanguage)
            add(.yarn, after: knitAfterDays, lines: ReminderLines.yarn(color: color), priority: Priority.normal)
        }

        if hasDailyChallenge {
            add(.daily, after: dailyAfterDays, lines: ReminderLines.daily, priority: Priority.low)
        }

        add(.missYou, after: missYouAfterDays, lines: ReminderLines.missYou, priority: Priority.low)
        return reminders
    }
}
