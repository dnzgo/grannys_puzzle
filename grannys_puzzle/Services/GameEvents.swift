import ArrowwordCore
import GameServices

/// Every analytics event the game sends, named in one place.
///
/// Each one answers a question from the game plan's "Numbers to tune":
/// how hard levels feel, which video reward players pick, how often ad
/// breaks show, whether the jar brings people back. An event nobody will
/// look at is noise, so add one only with the question it answers.
///
/// Where Google Analytics has a recommended event for games (`level_start`,
/// `level_end`, `tutorial_begin`, `tutorial_complete`), its name and
/// parameters are used, so Analytics' built-in game reports understand them.
///
/// Custom parameters (score, mistakes…) are collected either way, but only
/// show in reports once registered as custom dimensions or metrics in the
/// Analytics console.
extension AnalyticsEvent {
    // MARK: - Levels

    /// - Parameter resumed: the player left this level halfway earlier and
    ///   came back to it.
    static func levelStart(level: Int, language: String, resumed: Bool) -> AnalyticsEvent {
        AnalyticsEvent("level_start", [
            "level_name": .string(levelName(level, language)),
            "level": .int(level),
            "language": .string(language),
            "resumed": .bool(resumed),
        ])
    }

    /// One submitted board (a retry after a fail is another one).
    /// - Parameter seconds: since the level opened or the last submit,
    ///   including any time the app spent in the background, so look at
    ///   medians rather than averages.
    static func levelEnd(level: Int, language: String, result: LevelResult, yarn: Int, seconds: Int) -> AnalyticsEvent {
        AnalyticsEvent("level_end", [
            "level_name": .string(levelName(level, language)),
            "level": .int(level),
            "language": .string(language),
            "success": .bool(result.passed),
            "score_percent": .int(Int((result.share * 100).rounded())),
            "mistakes": .int(result.judgedLetters - result.correctLetters),
            "revealed_letters": .int(result.revealedLetters),
            "yarn": .int(yarn),
            "seconds": .int(seconds),
        ])
    }

    /// "en-12": one value per level and language, for reports that list levels.
    private static func levelName(_ level: Int, _ language: String) -> String {
        "\(language)-\(level)"
    }

    // MARK: - Helpers and ads

    static func helperUsed(_ helper: HelperKind, level: Int) -> AnalyticsEvent {
        AnalyticsEvent("helper_used", ["helper": .string(helper.rawValue), "level": .int(level)])
    }

    /// A rewarded video the player chose to watch. Not named "ad_reward":
    /// that name is reserved by Analytics.
    /// - Parameter earned: watched to the end (false if closed early).
    static func rewardedVideo(_ reward: HelperAdReward, earned: Bool, level: Int) -> AnalyticsEvent {
        let choice = switch reward {
        case .catHints: "cat_hints"
        case .grandma: "grandma"
        }
        return AnalyticsEvent("rewarded_video", [
            "reward": .string(choice),
            "earned": .bool(earned),
            "level": .int(level),
        ])
    }

    /// An interstitial actually shown between levels.
    static func adBreak(afterLevel level: Int) -> AnalyticsEvent {
        AnalyticsEvent("ad_break", ["level": .int(level)])
    }

    // MARK: - Home

    static func jarOpened(_ opening: JarOpening) -> AnalyticsEvent {
        AnalyticsEvent("jar_opened", [
            "streak_day": .int(opening.streakDay),
            "hints": .int(opening.reward.hints),
            "grandmas": .int(opening.reward.grandmas),
        ])
    }

    static func itemKnitted(_ item: KnitItem) -> AnalyticsEvent {
        AnalyticsEvent("item_knitted", ["item_id": .string(item.id), "cost": .int(item.cost)])
    }

    static func languageSwitched(to language: String) -> AnalyticsEvent {
        AnalyticsEvent("language_switched", ["language": .string(language)])
    }

    // MARK: - Reminders

    /// The player answered iOS's notification prompt (after grandma's own
    /// question).
    static func reminderPermission(allowed: Bool) -> AnalyticsEvent {
        AnalyticsEvent("reminder_permission", ["allowed": .bool(allowed)])
    }

    /// "Not now" to grandma's question.
    static let reminderAskDeclined = AnalyticsEvent("reminder_ask_declined")

    /// A reminder was tapped and opened the game. `kind` is jar, streak,
    /// yarn or miss_you.
    static func reminderOpened(kind: String) -> AnalyticsEvent {
        AnalyticsEvent("reminder_opened", ["kind": .string(kind)])
    }

    // MARK: - Ratings

    /// The game asked iOS for the rating prompt at this moment. iOS decides
    /// whether it actually shows, and never says, so this counts asks.
    static func reviewPromptRequested(_ moment: ReviewMoment) -> AnalyticsEvent {
        AnalyticsEvent("review_prompt_requested", ["moment": .string(moment.rawValue)])
    }

    // MARK: - Tutorial

    static let tutorialBegin = AnalyticsEvent("tutorial_begin")
    static let tutorialComplete = AnalyticsEvent("tutorial_complete")
    static let tutorialSkip = AnalyticsEvent("tutorial_skip")
}

/// The two helpers, as analytics names them.
enum HelperKind: String {
    case cat
    case grandma
}
