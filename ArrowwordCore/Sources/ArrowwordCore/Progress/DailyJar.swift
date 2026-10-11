import Foundation

/// What grandma's jar gives: cat hints, grandma helpers, or both.
public struct JarReward: Equatable, Sendable {
    public let hints: Int
    public let grandmas: Int

    public init(hints: Int, grandmas: Int) {
        self.hints = hints
        self.grandmas = grandmas
    }
}

/// The result of opening the jar: what came out, and the streak day it was.
public struct JarOpening: Equatable, Sendable {
    public let reward: JarReward
    /// 1…`DailyJarRules.streakLength`; the last day gives the big reward.
    public let streakDay: Int

    public init(reward: JarReward, streakDay: Int) {
        self.reward = reward
        self.streakDay = streakDay
    }
}

/// The jar's numbers, kept together so they can be tuned in one place (and
/// later come from remote config, like the scoring thresholds).
public struct DailyJarRules: Sendable {
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
    /// Whether today's jar is still closed.
    public func canOpenJar(today: Int) -> Bool {
        guard let lastJarDay else { return true }
        return today > lastJarDay
    }

    /// The streak day today's jar would be: the next day if the player opened
    /// it yesterday, otherwise day 1 (first time, or a day was missed).
    public func jarStreakDay(today: Int, rules: DailyJarRules = .standard) -> Int {
        guard let lastJarDay, today == lastJarDay + 1 else { return 1 }
        // After the last day of a cycle, a new cycle starts.
        return jarStreak >= rules.streakLength ? 1 : jarStreak + 1
    }

    /// Opens today's jar: draws the reward, adds it to the helpers, and
    /// records the day. Returns nil if it was already opened today.
    ///
    /// The clock is the device's, so a player could move their date forward
    /// for extra jars. That's accepted for now; it only costs us a few free
    /// hints, and a server time check can come with accounts.
    public mutating func openJar<Generator: RandomNumberGenerator>(
        today: Int,
        rules: DailyJarRules = .standard,
        using generator: inout Generator
    ) -> JarOpening? {
        guard canOpenJar(today: today) else { return nil }
        let day = jarStreakDay(today: today, rules: rules)
        let reward = rules.reward(forStreakDay: day, using: &generator)
        hints += reward.hints
        grandmas += reward.grandmas
        jarStreak = day
        lastJarDay = today
        return JarOpening(reward: reward, streakDay: day)
    }
}
