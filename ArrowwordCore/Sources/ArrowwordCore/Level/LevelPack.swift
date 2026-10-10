import Foundation

/// A level pack exactly as the content pipeline writes it: one JSON file
/// holding a batch of levels in play order.
///
/// Like `LevelFile` vs `Level`, the storage format and the validated model
/// are separate types: this one is decoded as-is, `LevelPack` is checked.
public struct LevelPackFile: Codable, Sendable, Equatable {
    public var formatVersion: Int
    public var packId: String
    /// The pack's answer language, e.g. "en".
    public var language: String
    public var levels: [LevelFile]

    public init(formatVersion: Int, packId: String, language: String, levels: [LevelFile]) {
        self.formatVersion = formatVersion
        self.packId = packId
        self.language = language
        self.levels = levels
    }
}

/// Why a level pack was rejected while loading.
public enum LevelPackError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(Int)
    case noLevels
    /// A level broke a level rule. Carries its position and id so the broken
    /// level can be found in the file, plus the level's own error.
    case invalidLevel(index: Int, id: String, LevelError)
    case languageMismatch(levelID: String, expected: String, found: String)
    /// Level ids will key saved progress, so two levels must never share one.
    case duplicateLevelID(String)
}

/// A validated pack: every level in it has passed `Level` validation.
///
/// The whole pack is validated when it's loaded, not level by level as the
/// player reaches them. A broken level then shows up at launch, in testing,
/// instead of in front of a player at level 73.
public struct LevelPack: Sendable {
    /// The pack file format this code understands. Separate from the level
    /// format version: the wrapper and the levels inside can change
    /// independently.
    public static let supportedFormatVersion = 1

    public let id: String
    public let language: String
    /// The levels in play order.
    public let levels: [Level]

    public static func decode(from data: Data, rules: LevelRules = .standard) throws -> LevelPack {
        let file = try JSONDecoder().decode(LevelPackFile.self, from: data)
        return try LevelPack(file: file, rules: rules)
    }

    public init(file: LevelPackFile, rules: LevelRules = .standard) throws {
        guard file.formatVersion == Self.supportedFormatVersion else {
            throw LevelPackError.unsupportedFormatVersion(file.formatVersion)
        }
        guard !file.levels.isEmpty else { throw LevelPackError.noLevels }

        var levels: [Level] = []
        var seenIDs: Set<String> = []
        for (index, levelFile) in file.levels.enumerated() {
            guard seenIDs.insert(levelFile.id).inserted else {
                throw LevelPackError.duplicateLevelID(levelFile.id)
            }
            guard levelFile.answerLanguage == file.language else {
                throw LevelPackError.languageMismatch(
                    levelID: levelFile.id, expected: file.language, found: levelFile.answerLanguage
                )
            }
            do {
                levels.append(try Level(file: levelFile, rules: rules))
            } catch let error as LevelError {
                throw LevelPackError.invalidLevel(index: index, id: levelFile.id, error)
            }
        }

        self.id = file.packId
        self.language = file.language
        self.levels = levels
    }
}
