/// Every number the game plan lists under "Numbers to tune", in one place.
///
/// The defaults are today's values; a server (Remote Config) can override
/// any of them, so the game can be tuned from player data without an App
/// Store update. The rules themselves don't change: they already take
/// their numbers as values (`ScoringRules`, `DailyJarRules`), and this just
/// decides which values.
public struct GameTuning: Equatable, Sendable {
    public var scoring = ScoringRules.standard
    public var jar = DailyJarRules.standard
    /// Rewarded videos per day, shared by both helpers. 0 turns them off.
    public var rewardedAdsPerDay = PlayerProgress.rewardedAdsPerDay
    /// What one rewarded video gives, by the player's choice. The game plan
    /// flags this as the exchange rate to watch: if nearly everyone picks
    /// grandma, cats are worth too little.
    public var catHintsPerAd = 3
    public var grandmasPerAd = 1
    /// See `AdBreakSchedule`: the level rules for interstitials.
    public var adBreakFirstLevel = AdBreakSchedule().firstLevel
    public var adBreakLevelsBetween = AdBreakSchedule().levelsBetween
    /// The time rules for interstitials, enforced by the ads package (its
    /// `AdPolicy`, whose defaults these match): least time from one
    /// interstitial to the next, and from a rewarded video to one. A break
    /// needs both the level rule and the time rule to allow it. 0 leaves
    /// only the level rule.
    public var adBreakMinimumSeconds = 180
    public var adBreakSecondsAfterRewarded = 120
    /// When the rating prompt may be asked for (levels passed and the wait
    /// between asks). Only the level count is tunable from the server.
    public var review = ReviewPromptRules.standard
    /// Levels passed before grandma asks whether she may send reminders.
    /// A player who has played a few levels knows what they'd be reminded
    /// of; the lesson doesn't count.
    public var reminderAskMinLevels = 3
    /// The day daily puzzle number 1 is played (a `DailyDay` number). Set
    /// from the server while the launch date isn't certain; see
    /// `DailyDay.firstDay` for why it mustn't change after launch.
    public var dailyFirstDay = DailyDay.firstDay

    public init() {}

    public static let standard = GameTuning()

    // MARK: - From remote values

    /// The names the values have on the server (Remote Config parameter
    /// keys). Changing one here means changing it in the console too.
    public enum Key: String, CaseIterable, Sendable {
        case passThreshold = "pass_threshold"
        case threeBallThreshold = "three_ball_threshold"
        case twoBallThreshold = "two_ball_threshold"
        case oneBallThreshold = "one_ball_threshold"
        case jarGrandmaChance = "jar_grandma_chance"
        case jarHintsMin = "jar_hints_min"
        case jarHintsMax = "jar_hints_max"
        case jarBigRewardHints = "jar_big_reward_hints"
        case jarBigRewardGrandmas = "jar_big_reward_grandmas"
        case rewardedAdsPerDay = "rewarded_ads_per_day"
        case catHintsPerAd = "cat_hints_per_ad"
        case grandmasPerAd = "grandmas_per_ad"
        case adBreakFirstLevel = "ad_break_first_level"
        case adBreakLevelsBetween = "ad_break_levels_between"
        case adBreakMinimumSeconds = "ad_break_min_seconds"
        case adBreakSecondsAfterRewarded = "ad_break_seconds_after_rewarded"
        case reviewMinLevels = "review_min_levels"
        case reminderAskMinLevels = "reminder_ask_min_levels"
        case dailyFirstDay = "daily_first_day"
    }

    /// Builds the tuning from server values, looked up by key.
    ///
    /// A server value is a promise nobody compiled: a typo in the console
    /// shouldn't break the game for everyone. So every value is checked,
    /// and a missing or out-of-range one keeps its default. Values that
    /// only make sense together (the score thresholds, the jar's hint
    /// range) are accepted or rejected as a group, so a half-applied change
    /// can't leave them contradicting each other.
    ///
    /// - Returns: the tuning, and the keys whose server values were ignored
    ///   (for the app to log, so a console mistake is easy to spot).
    public static func resolved(from remoteValue: @escaping (String) -> Double?) -> (tuning: GameTuning, ignored: [Key]) {
        var reader = Reader(remoteValue: remoteValue)
        var tuning = GameTuning()

        // Scoring: four shares that must step down in order.
        let pass = reader.fraction(.passThreshold)
        let three = reader.fraction(.threeBallThreshold)
        let two = reader.fraction(.twoBallThreshold)
        let one = reader.fraction(.oneBallThreshold)
        var scoring = tuning.scoring
        scoring.passThreshold = pass.value ?? scoring.passThreshold
        scoring.threeBallThreshold = three.value ?? scoring.threeBallThreshold
        scoring.twoBallThreshold = two.value ?? scoring.twoBallThreshold
        scoring.oneBallThreshold = one.value ?? scoring.oneBallThreshold
        if scoring.threeBallThreshold >= scoring.twoBallThreshold,
           scoring.twoBallThreshold >= scoring.oneBallThreshold {
            tuning.scoring = scoring
        } else {
            reader.reject([pass, three, two, one])
        }

        // The jar.
        if let chance = reader.fraction(.jarGrandmaChance).value {
            tuning.jar.grandmaChance = chance
        }
        let low = reader.integer(.jarHintsMin, in: 1...10)
        let high = reader.integer(.jarHintsMax, in: 1...10)
        let range = (low.value ?? tuning.jar.hintRange.lowerBound, high.value ?? tuning.jar.hintRange.upperBound)
        if range.0 <= range.1 {
            tuning.jar.hintRange = range.0...range.1
        } else {
            reader.reject([low, high])
        }
        let bigHints = reader.integer(.jarBigRewardHints, in: 0...20).value ?? tuning.jar.bigReward.hints
        let bigGrandmas = reader.integer(.jarBigRewardGrandmas, in: 0...5).value ?? tuning.jar.bigReward.grandmas
        tuning.jar.bigReward = JarReward(hints: bigHints, grandmas: bigGrandmas)

        // Ads.
        tuning.rewardedAdsPerDay = reader.integer(.rewardedAdsPerDay, in: 0...20).value ?? tuning.rewardedAdsPerDay
        tuning.catHintsPerAd = reader.integer(.catHintsPerAd, in: 1...10).value ?? tuning.catHintsPerAd
        tuning.grandmasPerAd = reader.integer(.grandmasPerAd, in: 1...5).value ?? tuning.grandmasPerAd
        tuning.adBreakFirstLevel = reader.integer(.adBreakFirstLevel, in: 1...1_000).value ?? tuning.adBreakFirstLevel
        tuning.adBreakLevelsBetween = reader.integer(.adBreakLevelsBetween, in: 1...50).value ?? tuning.adBreakLevelsBetween
        // Up to an hour: beyond that a session rarely sees a break at all,
        // which is better done by raising the levels between them.
        tuning.adBreakMinimumSeconds = reader.integer(.adBreakMinimumSeconds, in: 0...3_600).value ?? tuning.adBreakMinimumSeconds
        tuning.adBreakSecondsAfterRewarded = reader.integer(.adBreakSecondsAfterRewarded, in: 0...3_600).value
            ?? tuning.adBreakSecondsAfterRewarded

        // When to ask. At least one level, so neither question can ever come
        // straight after the lesson, whatever the console says.
        tuning.review.minLevelsPassed = reader.integer(.reviewMinLevels, in: 1...500).value ?? tuning.review.minLevelsPassed
        tuning.reminderAskMinLevels = reader.integer(.reminderAskMinLevels, in: 1...100).value ?? tuning.reminderAskMinLevels

        // The daily's first day, as a date like 20261201. Not a real date
        // (20261301, 2026121) is a console mistake: the default stands.
        let firstDay = reader.integer(.dailyFirstDay, in: 20_250_101...20_991_231)
        if let date = firstDay.value {
            if let day = DailyDay.number(fromDate: date) {
                tuning.dailyFirstDay = day
            } else {
                reader.reject([firstDay])
            }
        }

        return (tuning, reader.ignored)
    }
}

/// Reads and checks server values, remembering which ones it had to ignore.
private struct Reader {
    /// One value as read. `value` is nil when the default should be used:
    /// the server didn't set it, or set something unusable.
    struct Read<Value> {
        let key: GameTuning.Key
        let value: Value?
    }

    let remoteValue: (String) -> Double?
    var ignored: [GameTuning.Key] = []

    /// A share from 0 to 1.
    mutating func fraction(_ key: GameTuning.Key) -> Read<Double> {
        guard let number = remoteValue(key.rawValue) else { return Read(key: key, value: nil) }
        guard number.isFinite, (0...1).contains(number) else { return ignore(key) }
        return Read(key: key, value: number)
    }

    /// A whole number within `range`.
    mutating func integer(_ key: GameTuning.Key, in range: ClosedRange<Int>) -> Read<Int> {
        guard let number = remoteValue(key.rawValue) else { return Read(key: key, value: nil) }
        guard let whole = Int(exactly: number), range.contains(whole) else { return ignore(key) }
        return Read(key: key, value: whole)
    }

    /// A group that didn't fit together: its server values are ignored too,
    /// even those that were fine on their own. (Ones already ignored, or not
    /// set, have no value and aren't listed twice.)
    mutating func reject<Value>(_ group: [Read<Value>]) {
        ignored += group.filter { $0.value != nil }.map(\.key)
    }

    private mutating func ignore<Value>(_ key: GameTuning.Key) -> Read<Value> {
        ignored.append(key)
        return Read(key: key, value: nil)
    }
}
