/// Thresholds that turn a submitted board into stars and pass/fail.
///
/// These are placeholders until playtesting. In the app they come from remote
/// config, which is why they're a value passed in rather than constants.
public struct ScoringRules: Sendable, Equatable {
    /// Minimum share of correct letters to pass the level.
    public var passThreshold: Double = 0.8
    /// Minimum share of correct letters for 3, 2 and 1 stars.
    public var threeStarThreshold: Double = 1.0
    public var twoStarThreshold: Double = 0.9
    public var oneStarThreshold: Double = 0.8

    public init() {}

    public static let standard = ScoringRules()
}

/// The outcome of submitting a full board.
public struct LevelResult: Sendable, Equatable {
    /// Letters the player supplied that are correct. Revealed letters count
    /// as correct, because using the cat or grandma doesn't cost stars.
    public let correctLetters: Int
    /// Letters the player had to supply: every letter cell except starter
    /// letters, which would otherwise inflate the score.
    public let judgedLetters: Int
    public let stars: Int
    public let passed: Bool

    public var share: Double {
        judgedLetters == 0 ? 1 : Double(correctLetters) / Double(judgedLetters)
    }

    init(correctLetters: Int, judgedLetters: Int, rules: ScoringRules) {
        self.correctLetters = correctLetters
        self.judgedLetters = judgedLetters
        let share = judgedLetters == 0 ? 1 : Double(correctLetters) / Double(judgedLetters)
        if share >= rules.threeStarThreshold {
            stars = 3
        } else if share >= rules.twoStarThreshold {
            stars = 2
        } else if share >= rules.oneStarThreshold {
            stars = 1
        } else {
            stars = 0
        }
        passed = share >= rules.passThreshold
    }
}
