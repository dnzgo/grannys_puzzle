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
    /// Ids of the items grandma has knitted (see `KnitItem.id`).
    public var wardrobe: Set<String>
    /// The current level as the player left it, if they left it halfway.
    public var board: SavedBoard?
    /// The streak day of the last jar opened (0 before the first one).
    public var jarStreak: Int
    /// `JarDay` number of the last jar opened, nil before the first one.
    public var lastJarDay: Int?
    /// Whether the first-time lesson is behind the player (finished or
    /// skipped). Until it is, the app opens on the lesson.
    public var tutorialDone: Bool

    public init(
        version: Int = currentVersion,
        levelNumber: Int,
        hints: Int,
        grandmas: Int,
        yarn: [YarnColor: Int],
        wardrobe: Set<String> = [],
        board: SavedBoard? = nil,
        jarStreak: Int = 0,
        lastJarDay: Int? = nil,
        tutorialDone: Bool = false
    ) {
        self.version = version
        self.levelNumber = levelNumber
        self.hints = hints
        self.grandmas = grandmas
        self.yarn = yarn
        self.wardrobe = wardrobe
        self.board = board
        self.jarStreak = jarStreak
        self.lastJarDay = lastJarDay
        self.tutorialDone = tutorialDone
    }

    // MARK: - Saving format

    private enum CodingKeys: String, CodingKey {
        case version, levelNumber, hints, grandmas, yarn, wardrobe, board, jarStreak, lastJarDay, tutorialDone
    }

    /// Written by hand rather than generated, for one reason: saves from
    /// before knitting existed have no `wardrobe`, and the generated decoder
    /// would reject them as damaged. A missing wardrobe simply means empty.
    /// This is the pattern for every field added later: decode it with
    /// `decodeIfPresent` and a sensible default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        levelNumber = try container.decode(Int.self, forKey: .levelNumber)
        hints = try container.decode(Int.self, forKey: .hints)
        grandmas = try container.decode(Int.self, forKey: .grandmas)
        yarn = try container.decode([YarnColor: Int].self, forKey: .yarn)
        wardrobe = try container.decodeIfPresent(Set<String>.self, forKey: .wardrobe) ?? []
        board = try container.decodeIfPresent(SavedBoard.self, forKey: .board)
        jarStreak = try container.decodeIfPresent(Int.self, forKey: .jarStreak) ?? 0
        lastJarDay = try container.decodeIfPresent(Int.self, forKey: .lastJarDay)
        // Saves from before the tutorial existed: someone past level 1 has
        // clearly learnt to play and shouldn't be sent back to the lesson.
        tutorialDone = try container.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? (levelNumber > 1)
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
    /// (The saved board is the caller's to clear: either way the board that
    /// was submitted is finished with.)
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
        addYarn(balls)
        levelNumber += 1
        return balls
    }

    // MARK: - Tutorial

    /// Yarn for finishing the lesson: a full reward, so the first thing the
    /// player sees is how solving fills grandma's bag.
    public static let tutorialYarn = 3

    /// Marks the lesson done and gives its yarn, the first time only.
    /// Replaying it later (from Settings) gives nothing, or it would be a
    /// free yarn tap. Skipping just sets `tutorialDone`, with no yarn.
    ///
    /// - Returns: the balls given, empty on a replay.
    public mutating func completeTutorial<Generator: RandomNumberGenerator>(
        dropper: YarnDropper = YarnDropper(),
        using generator: inout Generator
    ) -> [YarnColor] {
        guard !tutorialDone else { return [] }
        tutorialDone = true
        let balls = dropper.draw(Self.tutorialYarn, given: yarn, using: &generator)
        addYarn(balls)
        return balls
    }

    private mutating func addYarn(_ balls: [YarnColor]) {
        for color in balls {
            yarn[color, default: 0] += 1
        }
    }

    // MARK: - Knitting

    /// Why a knit did or didn't happen.
    public enum KnitOutcome: Equatable, Sendable {
        case knitted
        case alreadyOwned
        case notEnoughYarn(missing: Int)
    }

    public func owns(_ item: KnitItem) -> Bool {
        wardrobe.contains(item.id)
    }

    public func canKnit(_ item: KnitItem) -> Bool {
        !owns(item) && yarnCount(of: item.color) >= item.cost
    }

    /// Spends the item's yarn and adds it to the wardrobe, if the player can
    /// afford it and doesn't own it yet. Each item is knitted only once.
    public mutating func knit(_ item: KnitItem) -> KnitOutcome {
        guard !owns(item) else { return .alreadyOwned }
        let have = yarnCount(of: item.color)
        guard have >= item.cost else { return .notEnoughYarn(missing: item.cost - have) }
        yarn[item.color] = have - item.cost
        wardrobe.insert(item.id)
        return .knitted
    }
}
