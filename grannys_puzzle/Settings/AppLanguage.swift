import Foundation

/// The game's language, chosen inside the game (Settings → Language).
///
/// Why not iOS's own per-app language setting: changing that sends the
/// player out to the Settings app and restarts the game. Players who enjoy
/// both languages switch often, so the switch belongs in the game and takes
/// effect at once: the text, grandma's lines, and the puzzles with that
/// language's own progress.
///
/// How it reaches the text, in two ways:
/// - SwiftUI `Text` views look strings up in the `locale` from the
///   environment, which the app root sets from this.
/// - Strings built in code (`String(localized:)`) don't see the environment,
///   so they pass `bundle: .appLanguage` (and `locale:` for numbers).
///
/// Things iOS draws itself (the tracking prompt, Google's consent form)
/// still follow the device language; the game can't change those.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    /// Where the choice is saved. A device preference, like the sound
    /// switches, so it lives in UserDefaults rather than the progress file.
    static let storageKey = "appLanguage"

    /// The language's own name, the way language pickers list them, so a
    /// player can find theirs whatever language is showing now.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// The language the game is set to: the saved choice, or on first
    /// launch the device's language if the game has it, else English.
    static var current: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: storageKey), let language = AppLanguage(rawValue: saved) {
            return language
        }
        return deviceDefault
    }

    private static var deviceDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
            if let match = allCases.first(where: { $0.rawValue == code }) {
                return match
            }
        }
        return .english
    }

    /// The compiled translations for this language (the app's `xx.lproj`
    /// folder), for strings looked up in code. Falls back to the main bundle
    /// if the folder is missing, which only a broken build would cause.
    var bundle: Bundle {
        Bundle.main.path(forResource: rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

extension Bundle {
    /// The translations for the language the game is set to.
    static var appLanguage: Bundle { AppLanguage.current.bundle }
}

extension Locale {
    /// The locale for the language the game is set to, for formatting
    /// numbers and percentages the way that language writes them.
    static var appLanguage: Locale { AppLanguage.current.locale }
}
