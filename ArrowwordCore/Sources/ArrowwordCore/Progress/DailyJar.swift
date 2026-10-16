import Foundation

/// What grandma's jar gives: cat hints, grandma helpers, or both.
public struct JarReward: Codable, Equatable, Sendable {
    public let hints: Int
    public let grandmas: Int

    public init(hints: Int, grandmas: Int) {
        self.hints = hints
        self.grandmas = grandmas
    }
}

/// A jar the player has earned and not opened yet.
///
/// Collecting and opening are separate on purpose: jars can be saved up and
/// opened when the help is wanted. What's inside is decided when the jar is
/// earned, not when it's opened, so a day-7 jar stays a big one whenever
/// it's opened, and opening can't be repeated for a better draw.
public struct Jar: Codable, Equatable, Sendable {
    public enum Source: Codable, Equatable, Sendable {
        /// Collected from the daily streak, on this day of the cycle.
        case daily(streakDay: Int)
        /// The prize for knitting every colour of a garment.
        case setComplete
    }

    public let reward: JarReward
    public let source: Source

    public init(reward: JarReward, source: Source) {
        self.reward = reward
        self.source = source
    }
}

/// The jar's numbers, kept together so they can be tuned in one place (and
/// later come from remote config, like the scoring thresholds).
public struct DailyJarRules: Equatable, Sendable {
    /// Days in one streak cycle; the last day gives `bigReward`.
    public var streakLength = 7
    /// Chance that an ordinary day gives a grandma instead of cats. Grandmas
    /// are worth more (a whole word), so they're the rarer surprise.
    public var grandmaChance = 0.25
    /// An ordinary day's cat hints: 1 to 3, each equally likely.
    public var hintRange = 1...3
    /// The last day of the streak: both kinds, the reason to come back.
    public var bigReward = JarReward(hints: 3, grandmas: 1)

    public init() {}

    public static let standard = DailyJarRules()

    /// Draws the reward for a streak day.
    public func reward<Generator: RandomNumberGenerator>(
        forStreakDay day: Int,
        using generator: inout Generator
    ) -> JarReward {
        if day >= streakLength { return bigReward }
        if Double.random(in: 0..<1, using: &generator) < grandmaChance {
            return JarReward(hints: 0, grandmas: 1)
        }
        return JarReward(hints: Int.random(in: hintRange, using: &generator), grandmas: 0)
    }
}

/// Calendar days as plain numbers, so the jar's rules work on whole days and
/// can be tested without waiting for real days to pass.
public enum JarDay {
    /// Today's day number in the player's time zone. Consecutive calendar
    /// days give consecutive numbers, across months, years and daylight
    /// saving changes, which is all the streak needs.
    public static func number(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }
}

extension PlayerProgress {
    /// Whether today's daily jar is still waiting to be collected.
    public func canCollectDailyJar(today: Int) -> Bool {
        guard let lastJarDay else { return true }
        return today > lastJarDay
    }

    /// The streak day today's jar would be: the next day if the player
    /// collected one yesterday, otherwise day 1 (first time, or a day was
    /// missed).
    public func jarStreakDay(today: Int, rules: DailyJarRules = .standard) -> Int {
        guard let lastJarDay, today == lastJarDay + 1 else { return 1 }
        // After the last day of a cycle, a new cycle starts.
        return jarStreak >= rules.streakLength ? 1 : jarStreak + 1
    }

    /// Collects today's jar: draws what's inside, puts it with the
    /// unopened jars, and moves the streak on. The streak counts collecting,
    /// not opening, so a player saving jars up keeps their streak. Returns
    /// nil if today's was already collected.
    ///
    /// The clock is the device's, so a player could move their date forward
    /// for extra jars. That's accepted for now; it only costs us a few free
    /// hints, and a server time check can come with accounts.
    public mutating func collectDailyJar<Generator: RandomNumberGenerator>(
        today: Int,
        rules: DailyJarRules = .standard,
        using generator: inout Generator
    ) -> Jar? {
        guard canCollectDailyJar(today: today) else { return nil }
        let day = jarStreakDay(today: today, rules: rules)
        let jar = Jar(reward: rules.reward(forStreakDay: day, using: &generator), source: .daily(streakDay: day))
        jars.append(jar)
        jarStreak = day
        lastJarDay = today
        return jar
    }

    /// A jar earned some other way (a finished set), added unopened.
    public mutating func earnJar(_ reward: JarReward, source: Jar.Source) {
        jars.append(Jar(reward: reward, source: source))
    }

    /// Opens the oldest unopened jar and adds what's inside to the helpers.
    /// Nil when there's none.
    public mutating func openJar() -> Jar? {
        guard !jars.isEmpty else { return nil }
        let jar = jars.removeFirst()
        receive(jar.reward)
        return jar
    }
}
