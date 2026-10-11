/// Everything the game remembers about a player between launches.
///
/// A plain value type with no saving logic: `ProgressStore` reads and writes
/// it, and the app decides when. That keeps the rules here (what a hint
/// costs, what a pass awards) testable without any files.
public struct PlayerProgress: Codable, Equatable, Sendable {
    /// The save format this code writes. Bump it when a field changes meaning,
    /// so an older save can be recognised and converted.
    public static let currentVersion = 1

    public var version: Int
    /// The level the player plays next, starting at 1.
    public var levelNumber: Int
    /// Cat helpers: each reveals one letter.
    public var hints: Int
    /// Grandma helpers: each solves one word.
    public var grandmas: Int
    /// The yarn bag: balls owned per colour. A missing colour means none.
    public var yarn: [YarnColor: Int]

    public init(version: Int = currentVersion, levelNumber: Int, hints: Int, grandmas: Int, yarn: [YarnColor: Int]) {
        self.version = version
        self.levelNumber = levelNumber
        self.hints = hints
        self.grandmas = grandmas
        self.yarn = yarn
    }

    /// What a brand-new player starts with.
    public static let newPlayer = PlayerProgress(levelNumber: 1, hints: 4, grandmas: 1, yarn: [:])

    public func yarnCount(of color: YarnColor) -> Int {
        yarn[color, default: 0]
    }

    public var totalYarn: Int {
        yarn.values.reduce(0, +)
    }

    // MARK: - Changes

    /// Uses one cat hint if there is one. Returns whether it did, so the
    /// caller can't reveal a letter the player hasn't paid for.
    public mutating func spendHint() -> Bool {
        guard hints > 0 else { return false }
        hints -= 1
        return true
    }

    /// Uses one grandma if there is one. Returns whether it did.
    public mutating func spendGrandma() -> Bool {
        guard grandmas > 0 else { return false }
        grandmas -= 1
        return true
    }

    /// Records a submitted level. A pass awards yarn and moves the player on;
    /// a fail changes nothing, because the level is simply played again.
    ///
    /// - Returns: the yarn balls awarded, in the order they were drawn (the
    ///   result screen shows them in this order).
    public mutating func record<Generator: RandomNumberGenerator>(
        _ result: LevelResult,
        dropper: YarnDropper = YarnDropper(),
        using generator: inout Generator
    ) -> [YarnColor] {
        guard result.passed else { return [] }
        let balls = dropper.draw(result.yarnBalls, given: yarn, using: &generator)
        for color in balls {
            yarn[color, default: 0] += 1
        }
        levelNumber += 1
        return balls
    }
}
