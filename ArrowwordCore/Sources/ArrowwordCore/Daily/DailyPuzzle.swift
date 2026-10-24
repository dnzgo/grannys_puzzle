import Foundation

/// The daily puzzle's calendar. Everyone plays the same puzzle on the same
/// day, and the day changes at the same moment worldwide (midnight UTC), so
/// a shared leaderboard can compare like with like.
///
/// UTC rather than the player's time zone on purpose: with local midnights,
/// players in different zones would get the puzzle hours apart and could
/// pass answers on. (The daily jar uses local days instead; it's personal.)
public enum DailyDay {
    private static let secondsPerDay: TimeInterval = 86_400

    /// Days since 1 January 1970, counted in UTC. Unix time has no leap
    /// seconds, so every day is exactly 86,400 seconds of it.
    public static func number(for date: Date = Date()) -> Int {
        Int((date.timeIntervalSince1970 / secondsPerDay).rounded(.down))
    }

    /// When `day` ends and the next puzzle starts.
    public static func end(of day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day + 1) * secondsPerDay)
    }

    /// The day the first daily puzzle is played (1 November 2026, as a
    /// `number(for:)`). Puzzles are numbered from it: this day plays daily
    /// number 1, the next day number 2, and so on, through the daily packs
    /// in order (see LevelLibrary).
    ///
    /// Counted from a fixed day rather than taken modulo however many
    /// puzzles a phone has, so adding packs never changes which puzzle a
    /// day has: every phone plays the same one, which a shared leaderboard
    /// needs. Changing this after release would reshuffle everyone's days.
    public static let firstDay = 20_758

    /// The daily puzzle number (1-based) for `day`. Below 1 before
    /// `firstDay`, which only happens while testing before launch.
    public static func puzzleNumber(forDay day: Int) -> Int {
        day - firstDay + 1
    }

    /// The puzzle to play when `number`'s pack isn't on the phone (not
    /// downloaded yet, offline) or not written yet: the available puzzles
    /// in order, starting over when they run out. So there's always a
    /// daily, but it may not be the one everyone else has that day; a
    /// leaderboard must not count such a go (`puzzleNumber` would differ).
    public static func fallbackNumber(for number: Int, available: Int) -> Int? {
        guard available > 0 else { return nil }
        // `%` keeps the sign; adding `available` keeps it positive.
        return ((number - 1) % available + available) % available + 1
    }
}

/// The player's go at one day's puzzle: when they started, and the result
/// once submitted. Only the latest day's is kept.
///
/// A go is played in one sitting. Leaving the daily before submitting
/// throws it away, board and clock, and coming back starts over: the time
/// is how long one sitting at the board took, which can't be shortened by
/// leaving, thinking it over and coming back.
public struct DailyAttempt: Codable, Equatable, Sendable {
    public let day: Int
    /// Which level was played.
    public let levelID: String
    /// The clock runs from here, while the app is in the background too.
    public let startedAt: Date
    /// Set once, when the board is submitted.
    public var result: DailyResult?

    public init(day: Int, levelID: String, startedAt: Date, result: DailyResult? = nil) {
        self.day = day
        self.levelID = levelID
        self.startedAt = startedAt
        self.result = result
    }

    /// Whole seconds since the start, never negative (a clock set back).
    public func elapsedSeconds(at now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt).rounded(.down)))
    }
}

/// How a daily puzzle went: what the stats card shows, and what the
/// leaderboard ranks (its `score`).
public struct DailyResult: Codable, Equatable, Sendable {
    public let correctLetters: Int
    public let judgedLetters: Int
    public let seconds: Int

    public init(correctLetters: Int, judgedLetters: Int, seconds: Int) {
        self.correctLetters = correctLetters
        self.judgedLetters = judgedLetters
        self.seconds = seconds
    }

    /// Correct letters as a whole percentage, rounded down, so 99.6% shows
    /// as 99: only an all-correct board shows 100.
    public var percent: Int {
        guard judgedLetters > 0 else { return 100 }
        return correctLetters * 100 / judgedLetters
    }

    /// The leaderboard score (see DailyScore).
    public var score: DailyScore { DailyScore(self) }

    /// Whether this result ranks above `other`: the higher score, and
    /// between equal scores, the faster board.
    public func ranks(above other: DailyResult) -> Bool {
        if score.total != other.score.total { return score.total > other.score.total }
        return seconds < other.seconds
    }
}

/// The daily leaderboard's score: points for correctness plus a bonus for
/// speed, shown to the player as those two parts adding up, so the number
/// is never a mystery.
///
/// - **Correctness:** up to 10,000 points, the share of correct letters
///   (exact, not the rounded percent shown).
/// - **Speed bonus:** 2.5 points for every second left of 20 minutes, so
///   up to 3,000. Counted per second rather than in steps, so two quick
///   boards rarely tie; after 20 minutes it's 0.
///
/// Correctness weighs more on purpose: it's a word puzzle, and a rushed,
/// sloppy board shouldn't beat a careful one by much. Using the cat or
/// grandma costs no time.
///
/// Fixed in code rather than in Remote Config: everyone on one day's
/// leaderboard must be scored by the same rule, and remote values reach
/// phones at different launches. A change here starts with a new day and
/// an app update.
public struct DailyScore: Equatable, Sendable {
    /// A perfect board's correctness points.
    public static let maxCorrectness = 10_000
    /// The speed bonus runs out after this long.
    public static let speedWindowSeconds = 1_200
    /// Bonus points per second left, as a fraction (2.5 = 5/2), so the
    /// maths stays in whole numbers and every phone gets the same result.
    private static let bonusPerSecond = (numerator: 5, denominator: 2)

    public let correctness: Int
    public let speedBonus: Int
    public var total: Int { correctness + speedBonus }

    /// The highest possible score: a perfect board finished at once.
    public static var maxTotal: Int {
        maxCorrectness + speedWindowSeconds * bonusPerSecond.numerator / bonusPerSecond.denominator
    }

    public init(_ result: DailyResult) {
        correctness = result.judgedLetters > 0
            ? result.correctLetters * Self.maxCorrectness / result.judgedLetters
            : Self.maxCorrectness
        let secondsLeft = max(0, Self.speedWindowSeconds - max(0, result.seconds))
        speedBonus = secondsLeft * Self.bonusPerSecond.numerator / Self.bonusPerSecond.denominator
    }
}

/// Where the player stands with today's puzzle.
public enum DailyStatus: Equatable, Sendable {
    case notStarted
    case inProgress(DailyAttempt)
    case done(DailyResult)
}

extension PlayerProgress {
    public func dailyStatus(today: Int) -> DailyStatus {
        guard let daily, daily.day == today else { return .notStarted }
        if let result = daily.result { return .done(result) }
        return .inProgress(daily)
    }

    /// Starts today's puzzle with a fresh clock. Also what coming back
    /// after leaving does: one left unsubmitted (the app closed mid-way,
    /// say) is replaced. Nil once today's is submitted: one result a day.
    @discardableResult
    public mutating func startDaily(today: Int, levelID: String, now: Date) -> DailyAttempt? {
        if case .done = dailyStatus(today: today) { return nil }
        let attempt = DailyAttempt(day: today, levelID: levelID, startedAt: now)
        daily = attempt
        return attempt
    }

    /// The player left the daily without submitting: the go is thrown away.
    /// A submitted one stays, so its result still counts for the day.
    public mutating func leaveDaily() {
        guard daily?.result == nil else { return }
        daily = nil
    }

    /// Records the submitted daily board with the time it took. Nil when
    /// there's no daily in progress, or it was already submitted, so a
    /// double tap can't record twice or restart the clock.
    @discardableResult
    public mutating func finishDaily(_ result: LevelResult, now: Date) -> DailyResult? {
        guard var attempt = daily, attempt.result == nil else { return nil }
        let finished = DailyResult(
            correctLetters: result.correctLetters,
            judgedLetters: result.judgedLetters,
            seconds: attempt.elapsedSeconds(at: now)
        )
        attempt.result = finished
        daily = attempt
        stats.recordDaily(result)
        return finished
    }
}
