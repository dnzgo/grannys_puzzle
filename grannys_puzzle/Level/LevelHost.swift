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

    func continueToNextLevel()
    func goHome()
}
