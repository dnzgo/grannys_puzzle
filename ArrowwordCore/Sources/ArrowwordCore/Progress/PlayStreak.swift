/// The play streak: how many days in a row the player has solved something
/// (a level passed, or the daily challenge submitted). Shown on the home
/// screen, and the reason to come back every day.
///
/// Days are the player's own calendar days (`JarDay` numbers), like the
/// daily jar: a streak is personal, unlike the daily challenge, which
/// changes at the same moment worldwide.
///
/// A streak broken by a single missed day can be saved, by watching an ad,
/// on the day the player comes back and before they solve anything: saving
/// counts the missed day as covered, so solving today carries it on.
/// Missing two or more days ends it for good.
public enum StreakStatus: Equatable, Sendable {
    /// No streak: never started, ended, or the save was turned down.
    case none
    /// Alive. `solvedToday` false means it ends unless the player solves
    /// something today (the home screen shows that).
    case active(days: Int, solvedToday: Bool)
    /// Yesterday was missed: this many days can still be saved today.
    case canSave(days: Int)

    /// The number the home screen shows.
    public var days: Int {
        switch self {
        case .none: 0
        case .active(let days, _): days
        case .canSave(let days): days
        }
    }
}

extension PlayerProgress {
    public func streakStatus(today: Int) -> StreakStatus {
        guard let lastStreakDay, streakDays > 0 else { return .none }
        switch today - lastStreakDay {
        case 0: return .active(days: streakDays, solvedToday: true)
        case 1: return .active(days: streakDays, solvedToday: false)
        case 2: return streakSaveDeclinedDay == today ? .none : .canSave(days: streakDays)
        // More than one day missed, or the clock went backwards.
        default: return .none
        }
    }

    /// Something was solved today: the streak goes on (once per day), or a
    /// new one starts at 1 if it had ended. Solving with a save still on
    /// offer means the player chose to play on without it: it ends.
    @discardableResult
    public mutating func recordStreakDay(today: Int) -> Int {
        switch streakStatus(today: today) {
        case .active(_, solvedToday: true):
            break
        case .active(_, solvedToday: false):
            streakDays += 1
        case .none, .canSave:
            streakDays = 1
        }
        lastStreakDay = today
        stats.longestStreak = max(stats.longestStreak, streakDays)
        return streakDays
    }

    /// Saves a streak that missed yesterday: yesterday counts as covered, so
    /// it's alive again and today's solve carries it on. The saved day isn't
    /// added to the count; only days actually played are. Returns whether
    /// there was a streak to save.
    @discardableResult
    public mutating func saveStreak(today: Int) -> Bool {
        guard case .canSave = streakStatus(today: today) else { return false }
        lastStreakDay = today - 1
        return true
    }

    /// The player turned the save down: no more asking today, and the
    /// streak is over (the next solve starts a new one).
    public mutating func declineStreakSave(today: Int) {
        guard case .canSave = streakStatus(today: today) else { return }
        streakSaveDeclinedDay = today
    }
}
