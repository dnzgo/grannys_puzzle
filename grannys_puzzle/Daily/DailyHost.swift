import ArrowwordCore

/// The daily puzzle's stand-in for the `Game` as a `LevelHost`, like the
/// lesson's TutorialHost: the daily runs on the normal level screen, and
/// this host changes what its actions mean without "if daily" checks
/// throughout the level code.
/// - The board is never saved: leaving the daily throws the go away, and
///   coming back starts over (see DailyAttempt). The level the player left
///   halfway is untouched.
/// - Submitting records the result and time instead of awarding yarn and
///   moving the level on. There's one go a day, so no Try again.
/// - The cat, grandma and their videos work as on any level (chosen on
///   purpose; it'll want a second look once there's a leaderboard).
final class DailyHost: LevelHost {
    /// Weak because the game owns this host.
    weak var game: Game?

    var hints: Int { game?.hints ?? 0 }
    var grandmas: Int { game?.grandmas ?? 0 }

    func spendHint() -> Bool { game?.spendHint() ?? false }
    func spendGrandma() -> Bool { game?.spendGrandma() ?? false }

    func record(_ result: LevelResult) -> LevelReward {
        LevelReward(daily: game?.finishDaily(result))
    }

    func saveBoard(_ board: SavedBoard?) {}

    var canWatchAdForHelper: Bool { game?.canWatchAdForHelper ?? false }
    var rewardedVideosLeftToday: Int { game?.rewardedVideosLeftToday ?? 0 }

    /// The stats card isn't a celebration with a pause after it, which is
    /// where the rating prompt waits on a level; it stays out of the daily.
    func mayAskForReview() -> Bool { false }
    func reviewAsked(_ moment: ReviewMoment) {}

    func amount(of reward: HelperAdReward) -> Int {
        game?.amount(of: reward) ?? reward.amount(in: .standard)
    }

    func adOfferOpened(outOf helper: HelperAdReward) {
        game?.adOfferOpened(outOf: helper)
    }

    func adOfferCancelled(outOf helper: HelperAdReward) {
        game?.adOfferCancelled(outOf: helper)
    }

    func watchAd(for reward: HelperAdReward, amount: Int, outOf helper: HelperAdReward) async -> Bool {
        await game?.watchAd(for: reward, amount: amount, outOf: helper) ?? false
    }

    /// The stats card's only way on is home: there's no next daily today.
    func continueToNextLevel() {
        game?.leaveDaily()
    }

    /// The back button mid-way, or Home on the stats card.
    func goHome() {
        game?.leaveDaily()
    }
}
