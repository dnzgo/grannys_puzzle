import Foundation

/// An on/off preference the player sets in Settings, saved in `UserDefaults`.
///
/// Each one is a key plus its default, declared once here. The Settings
/// screen and whatever obeys the setting (the feedback modifier for haptics
/// and sounds, ContentView for the music) both read it through `@AppStorage` with these
/// values, so they can never disagree about the key's spelling or the
/// default.
///
/// These live in `UserDefaults`, not in `PlayerProgress`, on purpose: they
/// describe this device ("my phone is on silent at work"), not the player's
/// game, so they shouldn't follow the player to another device when
/// accounts arrive.
struct ToggleSetting {
    let key: String
    let defaultValue: Bool

    /// Background music (MusicPlayer).
    static let music = ToggleSetting(key: "musicEnabled", defaultValue: true)
    /// Letter clicks, jingles and the other short sounds (SoundPlayer).
    static let sound = ToggleSetting(key: "soundEnabled", defaultValue: true)
    static let haptics = ToggleSetting(key: "hapticsEnabled", defaultValue: true)
}

/// The app's version as players and support see it, e.g. "1.0 (12)".
enum AppVersion {
    static var displayText: String {
        let info = Bundle.main.infoDictionary
        // Both are always set by Xcode; the fallback only guards against a
        // broken build setting, and "?" makes that visible instead of hiding it.
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Where the Settings links go.
///
/// The game's pages on dengolabs.com. Each is optional: a nil one shows
/// greyed out and inactive in Settings. The same privacy policy URL goes
/// into App Store Connect and AdMob's consent message.
enum SupportLinks {
    /// The address Feedback writes to: support@, so players' reports are
    /// kept apart from general mail (hello@) and can later go to a group.
    /// The website's help page should name the same address.
    static let feedbackEmail: String? = "support@dengolabs.com"
    static let termsOfUse = URL(string: "https://dengolabs.com/games/grannys-puzzle/terms/")
    static let privacyPolicy = URL(string: "https://dengolabs.com/games/grannys-puzzle/privacy/")

    /// A ready-to-send email with the app and iOS versions filled in, so a
    /// bug report says which build it's about without the player having to.
    static func feedbackMail(systemVersion: String) -> URL? {
        guard let feedbackEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Granny's Puzzle feedback"),
            URLQueryItem(
                name: "body",
                value: "\n\n\n—\nApp \(AppVersion.displayText), iOS \(systemVersion)"
            ),
        ]
        return components.url
    }
}
