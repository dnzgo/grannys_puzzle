import ArrowwordCore

/// What a level needs from the rest of the game: the player's helpers, and
/// somewhere to report results and navigation.
///
/// Why a protocol instead of handing the level the whole `Game`: the level
/// screen only needs these few things, and naming them here makes that
/// boundary explicit. `LevelViewModel` can't reach into progress or other
/// screens, and a preview or test can supply a simple stand-in.
///
/// `AnyObject` because the level holds its host weakly (see LevelViewModel).
protocol LevelHost: AnyObject {
    var hints: Int { get }
    var grandmas: Int { get }

    /// Pays for one cat hint. Returns false if the player has none left.
    func spendHint() -> Bool
    /// Pays for one grandma. Returns false if the player has none left.
    func spendGrandma() -> Bool

    /// Records a submitted board and returns the yarn it earned (none for a
    /// fail). Called once per submission, as soon as the result is known, so
    /// the reward is saved even if the app is closed on the result screen.
    func record(_ result: LevelResult) -> [YarnColor]

    /// Keeps the board as it is now, so leaving the level (or the app being
    /// closed) doesn't lose it. Nil means there's nothing to keep.
    func saveBoard(_ board: SavedBoard?)

    /// Whether helpers can be earned by watching a short ad right now
    /// (an ad is loaded and allowed).
    var canWatchAdForHelper: Bool { get }

    /// Plays a rewarded ad and, if it's watched to the end, gives the
    /// reward the player picked. Returns whether it was given.
    func watchAd(for reward: HelperAdReward) async -> Bool

    func continueToNextLevel()
    func goHome()
}

/// What one rewarded video can give. The player picks before watching.
enum HelperAdReward: CaseIterable {
    case catHints
    case grandma

    /// A grandma solves a whole word, about three letters' worth, so one
    /// grandma and three cats are offered as equal choices. Tune here.
    var amount: Int {
        switch self {
        case .catHints: 3
        case .grandma: 1
        }
    }
}
