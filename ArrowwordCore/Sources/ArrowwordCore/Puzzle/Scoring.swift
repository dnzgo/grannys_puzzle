/// Thresholds that turn a submitted board into yarn balls and pass/fail.
///
/// These are placeholders until playtesting. In the app they come from remote
/// config, which is why they're a value passed in rather than constants.
public struct ScoringRules: Sendable, Equatable {
    /// Minimum share of correct letters to pass the level.
    public var passThreshold: Double = 0.8
    /// Minimum share of correct letters for 3, 2 and 1 yarn balls.
    public var threeBallThreshold: Double = 1.0
    public var twoBallThreshold: Double = 0.9
    public var oneBallThreshold: Double = 0.8

    public init() {}

    public static let standard = ScoringRules()
}

/// The outcome of submitting a full board.
public struct LevelResult: Sendable, Equatable {
    /// Letters the player supplied that are correct. Revealed letters count
    /// as correct, because using the cat or grandma doesn't cost yarn.
    public let correctLetters: Int
    /// Letters the player had to supply: every letter cell except starter
    /// letters, which would otherwise inflate the score.
    public let judgedLetters: Int
    /// How many yarn balls the board earns, 0–3. A failed board can still
    /// score here in principle, but the game only awards yarn on a pass.
    public let yarnBalls: Int
    public let passed: Bool
    /// Letters the cat or grandma filled in. Not part of the score (they
    /// count as correct); kept because it's the clearest sign of how hard
    /// a level felt, which is what analytics wants to know.
    public let revealedLetters: Int

    public var share: Double {
        judgedLetters == 0 ? 1 : Double(correctLetters) / Double(judgedLetters)
    }

    init(correctLetters: Int, judgedLetters: Int, revealedLetters: Int = 0, rules: ScoringRules) {
        self.correctLetters = correctLetters
        self.judgedLetters = judgedLetters
        self.revealedLetters = revealedLetters
        let share = judgedLetters == 0 ? 1 : Double(correctLetters) / Double(judgedLetters)
        if share >= rules.threeBallThreshold {
            yarnBalls = 3
        } else if share >= rules.twoBallThreshold {
            yarnBalls = 2
        } else if share >= rules.oneBallThreshold {
            yarnBalls = 1
        } else {
            yarnBalls = 0
        }
        passed = share >= rules.passThreshold
    }
}
