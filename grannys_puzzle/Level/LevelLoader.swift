import Foundation
import os
import ArrowwordCore

/// What the game plays in one language.
struct GameContent {
    /// Pack 1 from the app bundle and any packs downloaded since.
    let levels: LevelLibrary
    let tutorial: Level?
    /// The daily puzzles: their own packs, apart from the levels.
    let daily: LevelLibrary?
}

/// Loads a language's content at launch: pack 1 of the levels and of the
/// dailies from the app bundle, followed by the packs downloaded on earlier
/// launches (DownloadedPacks). New packs arrive while playing, through
/// PackDownloader. Everything ends in `Level` / `LevelPack` validation, so
/// a level is checked the same way wherever it comes from.
enum LevelLoader {
    enum LoadError: Error, CustomStringConvertible {
        case missingFile(String)

        var description: String {
            switch self {
            case .missingFile(let name): return "No bundled file named \(name).json"
            }
        }
    }

    /// The language whose pack every build has, used when another
    /// language's pack isn't written yet.
    static let fallbackLanguage = "en"

    /// The bundled first pack of levels for a language, e.g. "tr-001".
    static func firstPackName(for language: String) -> String {
        PackKind.levels.fileName(language: language, number: 1)
    }

    /// The first-time lesson's hand-made board for a language, a pack of
    /// one level so it loads and is validated exactly like the real ones.
    static func tutorialPackName(for language: String) -> String {
        "tutorial-\(language)"
    }

    /// The bundled first pack of daily puzzles for a language, e.g.
    /// "daily-tr-001" (see DailyDay for which one is today's).
    static func dailyPackName(for language: String) -> String {
        PackKind.daily.fileName(language: language, number: 1)
    }

    /// Everything a language needs to play: its pack and its lesson board.
    /// The lesson is optional: a missing one is a build problem the tests
    /// catch, and not worth stopping the game for, so it's logged and the
    /// game plays without it.
    static func content(for language: String) throws -> GameContent {
        var levels = try LevelLibrary(packs: [firstPack(for: language)])
        DownloadedPacks.appendStored(.levels, to: &levels)
        let tutorial: Level?
        do {
            tutorial = try bundledPack(named: tutorialPackName(for: language)).levels.first
        } catch {
            Logger(subsystem: "grannys_puzzle", category: "tutorial")
                .error("Tutorial couldn't be loaded: \(String(describing: error), privacy: .public)")
            tutorial = nil
        }
        return GameContent(levels: levels, tutorial: tutorial, daily: dailyLibrary(for: language))
    }

    /// Optional like the lesson: without it the home screen simply has no
    /// daily button. A language without its own falls back to English's,
    /// like the levels.
    private static func dailyLibrary(for language: String) -> LevelLibrary? {
        do {
            let first: LevelPack
            do {
                first = try bundledPack(named: dailyPackName(for: language))
            } catch LoadError.missingFile where language != fallbackLanguage {
                first = try bundledPack(named: dailyPackName(for: fallbackLanguage))
            }
            var library = try LevelLibrary(packs: [first])
            DownloadedPacks.appendStored(.daily, to: &library)
            return library
        } catch {
            Logger(subsystem: "grannys_puzzle", category: "daily")
                .error("Daily puzzles couldn't be loaded: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The puzzle language's first pack, or English's if that language's
    /// pack isn't in this build yet (while its content is being written).
    static func firstPack(for language: String) throws -> LevelPack {
        do {
            return try bundledPack(named: firstPackName(for: language))
        } catch LoadError.missingFile where language != fallbackLanguage {
            return try bundledPack(named: firstPackName(for: fallbackLanguage))
        }
    }

    static func bundledPack(named name: String, in bundle: Bundle = .main) throws -> LevelPack {
        try LevelPack.decode(from: Data(contentsOf: bundledURL(named: name, in: bundle)))
    }

    private static func bundledURL(named name: String, in bundle: Bundle) throws -> URL {
        // Xcode may copy the file to the bundle root or keep its folder,
        // depending on project settings, so look in both places.
        let foundURL = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Levels")
        guard let url = foundURL else { throw LoadError.missingFile(name) }
        return url
    }
}
