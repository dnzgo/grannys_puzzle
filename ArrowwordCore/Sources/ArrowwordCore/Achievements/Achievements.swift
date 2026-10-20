/// The Game Center achievements, as rules over the saved progress.
///
/// An achievement here is only a target on one measure ("500 words"). How
/// far along the player is gets worked out from `PlayerProgress` whenever
/// it's asked, not counted up as things happen, so:
/// - it can't drift from the progress it describes;
/// - progress made offline or signed out of Game Center catches up the
///   next time it's reported (Game Center keeps the highest value);
/// - a new achievement on an existing measure is one more line in `all`.
///
/// The IDs are the ones entered in App Store Connect and can never change;
/// docs/Achievements.md lists them with their texts, and a test checks the
/// two agree.
public struct Achievement: Equatable, Sendable {
    /// What an achievement counts.
    public enum Measure: Equatable, Sendable {
        case wordsSolved
        /// In every language together.
        case levelsPassed
        case perfectBoards
        case levelsWithoutHelp
        case longestStreak
        case dailiesFinished
        case perfectDailies
        case itemsKnitted
        /// Garments knitted in every colour.
        case setsCompleted
        /// Languages with at least one level passed.
        case languagesPlayed
    }

    public let id: String
    public let measure: Measure
    public let target: Int

    public init(id: String, measure: Measure, target: Int) {
        self.id = id
        self.measure = measure
        self.target = target
    }
}

/// How far along one achievement is, ready to report.
public struct AchievementProgress: Equatable, Sendable {
    public let id: String
    /// 0–100, as Game Center wants it.
    public let percentComplete: Double
}

public enum Achievements {
    private static func make(_ group: String, _ name: String, _ measure: Achievement.Measure, _ target: Int) -> Achievement {
        Achievement(id: "grannyspuzzle.\(group).\(name)", measure: measure, target: target)
    }

    /// Every achievement, in the order App Store Connect shows them.
    public static let all: [Achievement] = [
        make("words", "10", .wordsSolved, 10),
        make("words", "100", .wordsSolved, 100),
        make("words", "500", .wordsSolved, 500),
        make("words", "1000", .wordsSolved, 1000),
        make("words", "5000", .wordsSolved, 5000),
        make("levels", "1", .levelsPassed, 1),
        make("levels", "10", .levelsPassed, 10),
        make("levels", "50", .levelsPassed, 50),
        make("levels", "100", .levelsPassed, 100),
        make("levels", "250", .levelsPassed, 250),
        make("levels", "500", .levelsPassed, 500),
        make("perfect", "1", .perfectBoards, 1),
        make("perfect", "10", .perfectBoards, 10),
        make("perfect", "50", .perfectBoards, 50),
        make("nohelp", "1", .levelsWithoutHelp, 1),
        make("nohelp", "25", .levelsWithoutHelp, 25),
        make("streak", "3", .longestStreak, 3),
        make("streak", "7", .longestStreak, 7),
        make("streak", "30", .longestStreak, 30),
        make("streak", "100", .longestStreak, 100),
        make("daily", "1", .dailiesFinished, 1),
        make("daily", "7", .dailiesFinished, 7),
        make("daily", "perfect", .perfectDailies, 1),
        make("knit", "1", .itemsKnitted, 1),
        make("knit", "set", .setsCompleted, 1),
        // The cat's whole wardrobe as it is now. A fixed number rather than
        // the catalog's size: an achievement means the same thing forever,
        // even once other family members bring more to knit.
        make("knit", "all", .itemsKnitted, 20),
        make("languages", "2", .languagesPlayed, 2),
    ]

    /// Every achievement's progress for this player. Untouched ones are
    /// left out: reporting 0% tells Game Center nothing.
    public static func progress(
        for player: PlayerProgress,
        catalog: KnittingCatalog,
        achievements: [Achievement] = all
    ) -> [AchievementProgress] {
        achievements.compactMap { achievement in
            let value = count(achievement.measure, for: player, catalog: catalog)
            guard value > 0, achievement.target > 0 else { return nil }
            let percent = min(100, Double(value) * 100 / Double(achievement.target))
            return AchievementProgress(id: achievement.id, percentComplete: percent)
        }
    }

    /// The player's current value on a measure.
    public static func count(_ measure: Achievement.Measure, for player: PlayerProgress, catalog: KnittingCatalog) -> Int {
        switch measure {
        case .wordsSolved: player.stats.wordsSolved
        // A language's next level, less the one not played yet.
        case .levelsPassed: player.levelNumbers.values.reduce(0) { $0 + max(0, $1 - 1) }
        case .perfectBoards: player.stats.perfectBoards
        case .levelsWithoutHelp: player.stats.levelsWithoutHelp
        case .longestStreak: player.stats.longestStreak
        case .dailiesFinished: player.stats.dailiesFinished
        case .perfectDailies: player.stats.perfectDailies
        case .itemsKnitted: player.wardrobe.count
        case .setsCompleted:
            Set(catalog.items.map(\.setID)).filter { set in
                catalog.items.filter { $0.setID == set }.allSatisfy(player.owns)
            }.count
        case .languagesPlayed: player.levelNumbers.values.filter { $0 > 1 }.count
        }
    }
}
