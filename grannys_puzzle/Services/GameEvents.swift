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

    /// A helper video the player chose to watch. Not named "ad_reward":
    /// that name is reserved by Analytics.
    /// - `reward`: what the player picked on the offer card.
    /// - `out_of`: the helper whose button opened the offer (the one that ran
    ///   out). Comparing the two says which helper players value more: out of
    ///   cats, do they still take cats, or switch to grandma?
    /// - `videos_today`: helper videos watched today, this one included if
    ///   it was earned; against the daily cap, it shows whether the cap bites.
    /// - `earned`: watched to the end (false if closed early).
    static func rewardedVideo(_ reward: HelperAdReward, outOf helper: HelperAdReward, earned: Bool, level: Int, videosToday: Int) -> AnalyticsEvent {
        AnalyticsEvent("rewarded_video", [
            "reward": .string(reward.analyticsName),
            "out_of": .string(helper.analyticsName),
            "earned": .bool(earned),
            "level": .int(level),
            "videos_today": .int(videosToday),
        ])
    }

    /// The "watch a video, pick a treat" card opened: the player ran out of
    /// a helper and a video was ready. With `ad_offer_cancel` and
    /// `rewarded_video`, it makes the funnel: offered, then watched or not.
    static func adOffer(outOf helper: HelperAdReward, level: Int, videosToday: Int) -> AnalyticsEvent {
        AnalyticsEvent("ad_offer", [
            "out_of": .string(helper.analyticsName),
            "level": .int(level),
            "videos_today": .int(videosToday),
        ])
    }

    /// The offer card closed without picking a video.
    static func adOfferCancel(outOf helper: HelperAdReward, level: Int) -> AnalyticsEvent {
        AnalyticsEvent("ad_offer_cancel", [
            "out_of": .string(helper.analyticsName),
            "level": .int(level),
        ])
    }

    /// A video watched (or not finished) to save a streak that missed a
    /// day. Same event as the helper videos, so one report shows which
    /// rewards players watch for; `streak_days` says how much was at stake.
    static func streakSaveVideo(days: Int, earned: Bool) -> AnalyticsEvent {
        AnalyticsEvent("rewarded_video", [
            "reward": .string("streak_save"),
            "earned": .bool(earned),
            "streak_days": .int(days),
        ])
    }

    /// An interstitial actually shown between levels.
    static func adBreak(afterLevel level: Int) -> AnalyticsEvent {
        AnalyticsEvent("ad_break", ["level": .int(level)])
    }

    // MARK: - Home

    /// Today's jar collected from the streak card. Whether the jar brings
    /// players back is measured by these (and their streak days).
    static func jarCollected(_ jar: Jar) -> AnalyticsEvent {
        AnalyticsEvent("jar_collected", jarParameters(jar))
    }

    /// A kept jar opened. `still_unopened` shows whether players save jars
    /// up, and so whether keeping them is worth having.
    static func jarOpened(_ jar: Jar, stillUnopened: Int) -> AnalyticsEvent {
        var parameters = jarParameters(jar)
        parameters["still_unopened"] = .int(stillUnopened)
        return AnalyticsEvent("jar_opened", parameters)
    }

    private static func jarParameters(_ jar: Jar) -> [String: Value] {
        var parameters: [String: Value] = [
            "hints": .int(jar.reward.hints),
            "grandmas": .int(jar.reward.grandmas),
        ]
        switch jar.source {
        case .daily(let streakDay):
            parameters["jar_source"] = .string("daily")
            parameters["streak_day"] = .int(streakDay)
        case .setComplete:
            parameters["jar_source"] = .string("set")
        }
        return parameters
    }

    static func itemKnitted(_ item: KnitItem) -> AnalyticsEvent {
        AnalyticsEvent("item_knitted", ["item_id": .string(item.id), "cost": .int(item.cost)])
    }

    /// The last colour of a garment was knitted, finishing its set.
    static func setCompleted(_ lastItem: KnitItem) -> AnalyticsEvent {
        AnalyticsEvent("set_completed", [
            "member": .string(lastItem.member.rawValue),
            "garment": .string(lastItem.kind.rawValue),
        ])
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

    /// A reminder was tapped and opened the game. `kind` is one of
    /// GrannyReminders.Kind: jar, streak, streak_save, unfinished, knit,
    /// yarn, daily or miss_you.
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

private extension HelperAdReward {
    /// How a helper is named in events. Fixed strings, so a renamed Swift
    /// case can't quietly split one report into two.
    var analyticsName: String {
        switch self {
        case .catHints: "cat_hints"
        case .grandma: "grandma"
        }
    }
}
