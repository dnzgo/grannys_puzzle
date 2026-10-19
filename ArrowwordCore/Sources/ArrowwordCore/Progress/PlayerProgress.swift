/// Everything the game remembers about a player between launches.
///
/// A plain value type with no saving logic: `ProgressStore` reads and writes
/// it, and the app decides when. That keeps the rules here (what a hint
/// costs, what a pass awards) testable without any files.
public struct PlayerProgress: Codable, Equatable, Sendable {
    /// The save format this code writes. Bump it when a field changes meaning,
    /// so an older save can be recognised and converted.
    ///
    /// 2: level and saved board are kept per language (`levelNumbers`,
    /// `boards`). Version 1 saves had a single `levelNumber` and `board`,
    /// which were always English, since that was the only pack.
    public static let currentVersion = 2

    /// The language a save from before per-language progress belongs to.
    public static let legacyLanguage = "en"

    public var version: Int
    /// The next level to play in each language's pack, by language code.
    /// A language not in here hasn't been played yet: it starts at level 1.
    /// Separate because each language has its own puzzles; a player at
    /// English level 40 hasn't solved Turkish level 39.
    public var levelNumbers: [String: Int]
    /// Cat helpers: each reveals one letter.
    public var hints: Int
    /// Grandma helpers: each solves one word.
    public var grandmas: Int
    /// The yarn bag: balls owned per colour. A missing colour means none.
    public var yarn: [YarnColor: Int]
    /// Ids of the items grandma has knitted (see `KnitItem.id`).
    public var wardrobe: Set<String>
    /// Sets whose prize jar has been collected from the wardrobe (see
    /// `KnitItem.setID`). Finishing a set doesn't hand the jar over by
    /// itself; the player collects it in the wardrobe, once.
    public var collectedSetJars: Set<String>
    /// Each language's level as the player left it, if they left it halfway.
    public var boards: [String: SavedBoard]
    /// The streak day of the last daily jar collected (0 before the first).
    /// Saved under its old meaning, "opened": until jars could be kept,
    /// collecting and opening were the same tap.
    public var jarStreak: Int
    /// `JarDay` number of the last daily jar collected, nil before the first.
    public var lastJarDay: Int?
    /// Jars earned and not opened yet, oldest first (see `Jar`).
    public var jars: [Jar]
    /// Whether the first-time lesson is behind the player (finished or
    /// skipped). Until it is, the app opens on the lesson. Shared by all
    /// languages: the rules of the game are the same in each.
    public var tutorialDone: Bool
    /// `JarDay` number of the last day a rewarded ad was watched, and how
    /// many were watched that day; the daily cap counts these (see
    /// RewardedAdLimit.swift). Saved, so restarting the app doesn't reset it.
    public var rewardedAdDay: Int?
    public var rewardedAdsThatDay: Int
    /// The latest daily puzzle the player started (see DailyPuzzle.swift).
    /// Shared by all languages: there's one daily a day, in the language
    /// being played when it's started.
    public var daily: DailyAttempt?
    /// The play streak (see PlayStreak.swift): days in a row with something
    /// solved, the last such day, and the day a save was turned down.
    public var streakDays: Int
    public var lastStreakDay: Int?
    public var streakSaveDeclinedDay: Int?

    /// The language being played. Not saved: the app sets it at launch
    /// from the pack it loads (which follows the device language), and
    /// `levelNumber` and `board` below read and write that language's entry.
    public var activeLanguage = PlayerProgress.legacyLanguage

    /// The next level in the active language, starting at 1.
    public var levelNumber: Int {
        get { levelNumbers[activeLanguage] ?? 1 }
        set { levelNumbers[activeLanguage] = newValue }
    }

    /// The active language's level as the player left it, if halfway.
    public var board: SavedBoard? {
        get { boards[activeLanguage] }
        set { boards[activeLanguage] = newValue }
    }

    public init(
        version: Int = currentVersion,
        levelNumber: Int,
        hints: Int,
        grandmas: Int,
        yarn: [YarnColor: Int],
        wardrobe: Set<String> = [],
        collectedSetJars: Set<String> = [],
        board: SavedBoard? = nil,
        jarStreak: Int = 0,
        lastJarDay: Int? = nil,
        jars: [Jar] = [],
        tutorialDone: Bool = false,
        rewardedAdDay: Int? = nil,
        rewardedAdsThatDay: Int = 0,
        daily: DailyAttempt? = nil,
        streakDays: Int = 0,
        lastStreakDay: Int? = nil,
        streakSaveDeclinedDay: Int? = nil,
        activeLanguage: String = PlayerProgress.legacyLanguage
    ) {
        self.version = version
        self.levelNumbers = [activeLanguage: levelNumber]
        self.hints = hints
        self.grandmas = grandmas
        self.yarn = yarn
        self.wardrobe = wardrobe
        self.collectedSetJars = collectedSetJars
        self.boards = board.map { [activeLanguage: $0] } ?? [:]
        self.jarStreak = jarStreak
        self.lastJarDay = lastJarDay
        self.jars = jars
        self.tutorialDone = tutorialDone
        self.rewardedAdDay = rewardedAdDay
        self.rewardedAdsThatDay = rewardedAdsThatDay
        self.daily = daily
        self.streakDays = streakDays
        self.lastStreakDay = lastStreakDay
        self.streakSaveDeclinedDay = streakSaveDeclinedDay
        self.activeLanguage = activeLanguage
    }

    // MARK: - Saving format

    private enum CodingKeys: String, CodingKey {
        case version, levelNumbers, hints, grandmas, yarn, wardrobe, collectedSetJars, boards, jarStreak, lastJarDay, jars, tutorialDone
        case rewardedAdDay, rewardedAdsThatDay, daily
        case streakDays, lastStreakDay, streakSaveDeclinedDay
        // Version 1 only; read when converting, never written.
        case levelNumber, board
    }

    /// Written by hand rather than generated, for one reason: older saves
    /// lack fields added since, and the generated decoder would reject them
    /// as damaged. This is the pattern for every field added later: decode
    /// it with `decodeIfPresent` and a sensible default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Whatever the file's version, it's converted to the current format
        // here, so the next save writes the current version.
        version = Self.currentVersion
        hints = try container.decode(Int.self, forKey: .hints)
        grandmas = try container.decode(Int.self, forKey: .grandmas)
        yarn = try container.decode([YarnColor: Int].self, forKey: .yarn)
        wardrobe = try container.decodeIfPresent(Set<String>.self, forKey: .wardrobe) ?? []
        // Empty for saves from before set jars were collected by hand. The
        // game isn't released, so the only saves that predate this are
        // testers', and a tester with a finished set simply gets its jar.
        collectedSetJars = try container.decodeIfPresent(Set<String>.self, forKey: .collectedSetJars) ?? []
        jarStreak = try container.decodeIfPresent(Int.self, forKey: .jarStreak) ?? 0
        lastJarDay = try container.decodeIfPresent(Int.self, forKey: .lastJarDay)
        jars = try container.decodeIfPresent([Jar].self, forKey: .jars) ?? []
        rewardedAdDay = try container.decodeIfPresent(Int.self, forKey: .rewardedAdDay)
        rewardedAdsThatDay = try container.decodeIfPresent(Int.self, forKey: .rewardedAdsThatDay) ?? 0
        daily = try container.decodeIfPresent(DailyAttempt.self, forKey: .daily)
        streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
        lastStreakDay = try container.decodeIfPresent(Int.self, forKey: .lastStreakDay)
        streakSaveDeclinedDay = try container.decodeIfPresent(Int.self, forKey: .streakSaveDeclinedDay)

        if let levelNumbers = try container.decodeIfPresent([String: Int].self, forKey: .levelNumbers) {
            self.levelNumbers = levelNumbers
            boards = try container.decodeIfPresent([String: SavedBoard].self, forKey: .boards) ?? [:]
        } else {
            // Version 1: one level and board, which were English.
            let level = try container.decode(Int.self, forKey: .levelNumber)
            levelNumbers = [Self.legacyLanguage: level]
            let board = try container.decodeIfPresent(SavedBoard.self, forKey: .board)
            boards = board.map { [Self.legacyLanguage: $0] } ?? [:]
        }

        // Saves from before the tutorial existed: someone past level 1 has
        // clearly learnt to play and shouldn't be sent back to the lesson.
        let playedOn = levelNumbers.values.contains { $0 > 1 }
        tutorialDone = try container.decodeIfPresent(Bool.self, forKey: .tutorialDone) ?? playedOn
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(levelNumbers, forKey: .levelNumbers)
        try container.encode(hints, forKey: .hints)
        try container.encode(grandmas, forKey: .grandmas)
        try container.encode(yarn, forKey: .yarn)
        try container.encode(wardrobe, forKey: .wardrobe)
        try container.encode(collectedSetJars, forKey: .collectedSetJars)
        try container.encode(boards, forKey: .boards)
        try container.encode(jarStreak, forKey: .jarStreak)
        try container.encodeIfPresent(lastJarDay, forKey: .lastJarDay)
        try container.encode(jars, forKey: .jars)
        try container.encode(tutorialDone, forKey: .tutorialDone)
        try container.encodeIfPresent(rewardedAdDay, forKey: .rewardedAdDay)
        try container.encode(rewardedAdsThatDay, forKey: .rewardedAdsThatDay)
        try container.encodeIfPresent(daily, forKey: .daily)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encodeIfPresent(lastStreakDay, forKey: .lastStreakDay)
        try container.encodeIfPresent(streakSaveDeclinedDay, forKey: .streakSaveDeclinedDay)
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
