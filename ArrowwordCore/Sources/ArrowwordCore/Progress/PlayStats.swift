/// Running totals of how the player has played, kept for the achievements
/// (see Achievements.swift) and nothing else: no rule of the game reads them.
///
/// Only what can't be worked out from the rest of the progress is counted
/// here. Levels passed, languages played and items knitted are already
/// there (`levelNumbers`, `wardrobe`), so they aren't counted twice.
public struct PlayStats: Codable, Equatable, Sendable {
    /// Words solved on passed levels and on dailies (`LevelResult.solvedWords`).
    public var wordsSolved = 0
    /// Levels passed with every letter right.
    public var perfectBoards = 0
    /// Levels passed without the cat or grandma.
    public var levelsWithoutHelp = 0
    /// Daily challenges submitted, and those with every letter right.
    public var dailiesFinished = 0
    public var perfectDailies = 0
    /// The longest play streak reached, so a streak lost later doesn't
    /// take its achievements away.
    public var longestStreak = 0

    public init() {}

    /// A submitted level. Only a pass counts: a failed board is played
    /// again, and counting both tries would count its words twice.
    mutating func recordLevel(_ result: LevelResult) {
        guard result.passed else { return }
        wordsSolved += result.solvedWords
        if result.isPerfect { perfectBoards += 1 }
        if result.revealedLetters == 0 { levelsWithoutHelp += 1 }
    }

    /// A submitted daily: one go a day, pass or not, so it always counts.
    mutating func recordDaily(_ result: LevelResult) {
        wordsSolved += result.solvedWords
        dailiesFinished += 1
        if result.isPerfect { perfectDailies += 1 }
    }

    // MARK: - Saving format

    private enum CodingKeys: String, CodingKey {
        case wordsSolved, perfectBoards, levelsWithoutHelp, dailiesFinished, perfectDailies, longestStreak
    }

    /// By hand, like PlayerProgress's, so a total added later reads as 0
    /// from a save that doesn't have it yet.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wordsSolved = try container.decodeIfPresent(Int.self, forKey: .wordsSolved) ?? 0
        perfectBoards = try container.decodeIfPresent(Int.self, forKey: .perfectBoards) ?? 0
        levelsWithoutHelp = try container.decodeIfPresent(Int.self, forKey: .levelsWithoutHelp) ?? 0
        dailiesFinished = try container.decodeIfPresent(Int.self, forKey: .dailiesFinished) ?? 0
        perfectDailies = try container.decodeIfPresent(Int.self, forKey: .perfectDailies) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
    }
}
