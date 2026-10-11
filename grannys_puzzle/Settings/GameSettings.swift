import Foundation

/// An on/off preference the player sets in Settings, saved in `UserDefaults`.
///
/// Each one is a key plus its default, declared once here. The Settings
/// screen and whatever obeys the setting (the haptics modifier, later the
/// music and sound players) both read it through `@AppStorage` with these
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

    /// Background music. No music plays yet; the player will read this.
    static let music = ToggleSetting(key: "musicEnabled", defaultValue: true)
    /// Taps, letter clicks and jingles. No sounds play yet either.
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
/// TODO: Fill these in before release. They're nil until the real addresses
/// exist, and Settings shows their rows as "Coming soon" while they are.
/// The App Store also asks for the privacy policy URL in App Store Connect,
/// so it has to exist before the first submission anyway.
enum SupportLinks {
    /// The address "Send feedback" writes to, e.g. "hello@example.com".
    static let feedbackEmail: String? = nil
    static let termsOfUse: URL? = nil
    static let privacyPolicy: URL? = nil

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
