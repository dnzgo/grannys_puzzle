import ArrowwordCore

/// The lesson's stand-in for the `Game` as a `LevelHost`.
///
/// The lesson runs on the normal level screen and view model, which only
/// talk to their host. Swapping in this host changes what the lesson's
/// actions *mean* without adding "if tutorial" checks throughout:
/// - the cat and grandma are free, so a player who has used theirs up can
///   still replay the lesson;
/// - the board is never saved, so it can't overwrite the real level the
///   player left halfway;
/// - finishing gives the lesson's yarn instead of moving to the next level.
final class TutorialHost: LevelHost {
    /// Weak because the game owns this host.
    weak var game: Game?

    // One of each, so the helper buttons show as available.
    var hints: Int { 1 }
    var grandmas: Int { 1 }

    func spendHint() -> Bool { true }
    func spendGrandma() -> Bool { true }

    func record(_ result: LevelResult) -> [YarnColor] {
        // The lesson only lets the player put in correct letters, so the
        // board always passes.
        game?.completeTutorial() ?? []
    }

    func saveBoard(_ board: SavedBoard?) {}

    // Helpers are free in the lesson, so there's never an ad to offer.
    var canWatchAdForHelper: Bool { false }
    var rewardedVideosLeftToday: Int { 0 }
    /// The lesson is the player's first minutes: far too early to ask.
    func mayAskForReview() -> Bool { false }
    func reviewAsked(_ moment: ReviewMoment) {}
    func amount(of reward: HelperAdReward) -> Int { reward.amount(in: .standard) }
    func watchAd(for reward: HelperAdReward, amount: Int) async -> Bool { false }

    func continueToNextLevel() {
        game?.leaveTutorial()
    }

    /// Also how Skip leaves the lesson.
    func goHome() {
        game?.leaveTutorial()
    }
}
