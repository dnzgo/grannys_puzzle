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

    /// Records a submitted board and returns what it earned (nothing for a
    /// fail). Called once per submission, as soon as the result is known, so
    /// the reward is saved even if the app is closed on the result screen.
    func record(_ result: LevelResult) -> LevelReward

    /// Keeps the board as it is now, so leaving the level (or the app being
    /// closed) doesn't lose it. Nil means there's nothing to keep.
    func saveBoard(_ board: SavedBoard?)

    /// Whether helpers can be earned by watching a short ad right now
    /// (an ad is loaded and allowed).
    var canWatchAdForHelper: Bool { get }

    /// Videos the player may still watch today. When an ad can't be offered,
    /// 0 here means the daily limit is why (grandma says so); otherwise no
    /// ad happened to be ready.
    var rewardedVideosLeftToday: Int { get }

    /// Whether a happy moment now may be used to ask for a rating.
    func mayAskForReview() -> Bool
    /// The rating prompt was just requested. Recorded only now, not when
    /// `mayAskForReview` said yes: a player who leaves the screen during the
    /// short pause before it never saw it, and shouldn't cost a chance.
    func reviewAsked(_ moment: ReviewMoment)

    /// How many helpers a video gives for this choice right now. The host
    /// decides because the number is tuned remotely (see `GameTuning`).
    func amount(of reward: HelperAdReward) -> Int

    /// Plays a rewarded ad and, if it's watched to the end, gives the
    /// reward the player picked, in the `amount` they were shown (asked of
    /// `amount(of:)` when the offer opened, so it can't change mid-video).
    /// Returns whether it was given.
    func watchAd(for reward: HelperAdReward, amount: Int) async -> Bool

    func continueToNextLevel()
    func goHome()
}

/// What a submitted board earned, for the celebration to show.
struct LevelReward {
    /// The yarn balls, in the order they were drawn.
    var yarn: [YarnColor] = []
    /// An item this level's yarn made affordable for the first time, which
    /// grandma mentions. Nil when nothing new became affordable.
    var newlyKnittable: KnitItem?
    /// The daily puzzle's result, for its stats card; nil on other levels.
    var daily: DailyResult?
}

/// The happy moments that may lead to Apple's rating prompt.
enum ReviewMoment: String {
    case perfectBoard = "perfect_board"
    case itemKnitted = "item_knitted"
}

/// What one rewarded video can give. The player picks before watching.
enum HelperAdReward: CaseIterable {
    case catHints
    case grandma

    /// How many a video gives. A grandma solves a whole word, about three
    /// letters' worth, so by default one grandma and three cats are offered
    /// as equal choices; the server can change the rate.
    func amount(in tuning: GameTuning) -> Int {
        switch self {
        case .catHints: tuning.catHintsPerAd
        case .grandma: tuning.grandmasPerAd
        }
    }
}
