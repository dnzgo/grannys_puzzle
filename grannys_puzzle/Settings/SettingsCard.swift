import SwiftUI
import UIKit
import AdKit
import NotifyKit

/// Settings, as a card over the screen that opened it, drawn in the game's
/// own style like the other cards. Not a system sheet: its toolbar and
/// alerts would bring iOS's look (glass buttons, grey alerts) into a game
/// that has its own.
///
/// The same switches everywhere (music, sounds, haptics, grandma's notes),
/// then what belongs to where it was opened:
/// - from home: language, the lesson, achievements (when signed in to Game
///   Center), feedback, the legal pages, credits and the version;
/// - from a level: feedback and Restart, for this board. No language
///   switch, which would swap the board for the other language's level
///   mid-solve, and nothing about the app as a whole.
///
/// It reads and writes `UserDefaults` through `@AppStorage` and knows
/// nothing about `Game`: none of these settings is part of the player's
/// progress, and the level's actions arrive as closures.
///
/// "Privacy choices" reopens the ad consent form. It only appears where
/// consent applies (EU, UK, some US states), which the ads controller knows.
///
/// Still to come, when the things they control exist:
/// - "Save your progress" (Sign in with Apple), and "Delete account" once an
///   account is linked, which App Store rules require.
struct SettingsCard: View {
    /// Where the card was opened.
    enum Context {
        /// - Parameter onHowToPlay: replays grandma's lesson.
        case home(onHowToPlay: () -> Void)
        /// - Parameter restart: nil where restarting isn't possible (the
        ///   lesson, a judged board).
        case level(restart: LevelRestart?)
    }

    /// Restarting the open level.
    struct LevelRestart {
        /// The player has typed letters. Without any there's nothing to
        /// clear and the button is shown disabled (still there, so the
        /// player learns where it lives); with some, it asks first.
        let hasLettersToClear: Bool
        let action: () -> Void
    }

    let context: Context
    let onClose: () -> Void

    /// The card shows one page at a time, with a back button on the
    /// others. Pages rather than more cards on top, so there's only ever
    /// one card and one dimming.
    private enum Page {
        case main
        case language
        case credits
        case confirmRestart
    }

    @State private var page = Page.main
    /// Set when Mail couldn't open, so the player still gets the address.
    @State private var showsMailAddress = false

    @AppStorage(ToggleSetting.music.key) private var musicOn = ToggleSetting.music.defaultValue
    @AppStorage(ToggleSetting.sound.key) private var soundOn = ToggleSetting.sound.defaultValue
    @AppStorage(ToggleSetting.haptics.key) private var hapticsOn = ToggleSetting.haptics.defaultValue
    /// The game's language. The app root watches the same key and switches
    /// the text and the puzzles the moment it changes.
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.current.rawValue

    @Environment(\.openURL) private var openURL
    /// Nil in previews.
    @Environment(AdsController.self) private var ads: AdsController?
    /// Nil in previews.
    @Environment(Reminders.self) private var reminders: Reminders?
    /// Nil in previews.
    @Environment(GameCenter.self) private var gameCenter: GameCenter?

    private let buttonHeight: CGFloat = 50

    var body: some View {
        GameCard(title: title, onBack: page == .main ? nil : { page = .main }, onClose: onClose) {
            content
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        // The player may have changed it in iOS Settings since last time.
        .task { await reminders?.refreshPermission() }
    }

    private var title: LocalizedStringKey {
        switch page {
        case .main: "Settings"
        case .language: "Language"
        case .credits: "Acknowledgements"
        case .confirmRestart: "Restart this level?"
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var content: some View {
        switch page {
        case .main: mainPage
        case .language: languagePage
        case .credits: creditsPage
        case .confirmRestart: confirmRestartPage
        }
    }

    private var mainPage: some View {
        VStack(spacing: 14) {
            switches
            switch context {
            case .home(let onHowToPlay):
                SecondaryButton(title: "Language", height: buttonHeight) { page = .language }
                SecondaryButton(title: "How to play", height: buttonHeight) {
                    onClose()
                    onHowToPlay()
                }
                // Apple's own screen: Game Center's list can't be drawn by
                // the game. Only while signed in, since it can't open
                // otherwise (signing in happens in the Settings app then).
                if let gameCenter, gameCenter.isSignedIn {
                    SecondaryButton(title: "Achievements", height: buttonHeight) {
                        gameCenter.showAchievements()
                    }
                }
                feedbackButton
                legalLinks
                    .padding(.top, 4)
            case .level(let restart):
                feedbackButton
                if let restart {
                    PrimaryButton(title: "Restart level", height: buttonHeight) { page = .confirmRestart }
                        .disabled(!restart.hasLettersToClear)
                        .opacity(restart.hasLettersToClear ? 1 : 0.45)
                }
            }
        }
    }

    /// Languages are listed by their own names ("English", "Türkçe"), not
    /// translated, so a player can find theirs whatever is showing now.
    private var languagePage: some View {
        VStack(spacing: 12) {
            ForEach(AppLanguage.allCases) { language in
                LanguageRow(name: language.nativeName, isSelected: language.rawValue == languageCode) {
                    languageCode = language.rawValue
                    page = .main
                }
            }
            Text("Each language has its own puzzles and remembers your level.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private var creditsPage: some View {
        ScrollView {
            AcknowledgementsView()
        }
        // Long legal text: the card stays a card, and the text scrolls.
        .frame(maxHeight: 440)
    }

    private var confirmRestartPage: some View {
        VStack(spacing: 14) {
            Text("The letters you placed will be cleared. Starter letters and your helpers' letters stay.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
            PrimaryButton(title: "Restart", height: buttonHeight) {
                guard case .level(let restart?) = context else { return }
                // Closed first, so the player sees the board clear.
                onClose()
                restart.action()
            }
            SecondaryButton(title: "Cancel", height: buttonHeight) { page = .main }
        }
    }

    // MARK: - Pieces

    /// Music, sounds, haptics and grandma's notes as four tiles; tapping a
    /// tile turns it on or off.
    private var switches: some View {
        HStack(spacing: 8) {
            SettingTile(systemName: "music.note", label: "Music", isOn: musicOn) { musicOn.toggle() }
            SettingTile(systemName: "speaker.wave.2.fill", label: "Sounds", isOn: soundOn) { soundOn.toggle() }
            SettingTile(systemName: "iphone.radiowaves.left.and.right", label: "Haptics", isOn: hapticsOn) { hapticsOn.toggle() }
            if let reminders {
                SettingTile(systemName: "bell.fill", label: "Reminders", isOn: remindersOn(reminders)) {
                    tapReminders(reminders)
                }
            }
        }
    }

    /// On only when iOS allows them and the player hasn't turned them off.
    private func remindersOn(_ reminders: Reminders) -> Bool {
        reminders.permission == .allowed && reminders.isEnabled
    }

    /// Three cases, because the game's own switch and iOS's permission are
    /// separate: with permission it's a plain switch; before iOS has been
    /// asked, a tap asks (the player chose this, so no soft ask first); and
    /// once iOS says no, only the iOS Settings app can change it.
    private func tapReminders(_ reminders: Reminders) {
        switch reminders.permission {
        case .allowed:
            reminders.isEnabled.toggle()
        case .notAsked:
            Task { await reminders.requestPermission() }
        case .denied:
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
        }
    }

    private var feedbackButton: some View {
        let mail = SupportLinks.feedbackMail(systemVersion: UIDevice.current.systemVersion)
        return VStack(spacing: 6) {
            SecondaryButton(title: "Feedback", height: buttonHeight) {
                guard let mail else { return }
                // Fails when the player has no mail app set up; show the
                // address instead of the tap doing nothing.
                openURL(mail) { accepted in
                    if !accepted { showsMailAddress = true }
                }
            }
            .disabled(mail == nil)
            .opacity(mail == nil ? 0.45 : 1)

            // Only reachable when the address is set: the button is
            // disabled otherwise.
            if showsMailAddress, let address = SupportLinks.feedbackEmail {
                Text("You can write to us at \(address)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
        }
    }

    /// Small underlined links, then the version, at the foot of the card.
    private var legalLinks: some View {
        VStack(spacing: 10) {
            HStack(spacing: 24) {
                linkButton("Terms of Use", url: SupportLinks.termsOfUse)
                linkButton("Privacy Policy", url: SupportLinks.privacyPolicy)
            }
            HStack(spacing: 24) {
                if let ads, ads.isPrivacyOptionsRequired {
                    // Required by Google's consent rules wherever the form
                    // was shown: changing your mind must be as easy as the
                    // first choice.
                    textLink("Privacy choices") {
                        Task { await ads.presentPrivacyOptions() }
                    }
                }
                textLink("Acknowledgements") { page = .credits }
            }
            Text("Version \(AppVersion.displayText)")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.quietInk)
        }
    }

    /// A link to a page that may not exist yet (the website goes live
    /// later): shown greyed out and inactive until its address is set.
    private func linkButton(_ title: LocalizedStringKey, url: URL?) -> some View {
        textLink(title, isAvailable: url != nil) {
            if let url { openURL(url) }
        }
    }

    private func textLink(_ title: LocalizedStringKey, isAvailable: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .underline(isAvailable)
                .foregroundStyle(isAvailable ? Theme.secondaryInk : Theme.quietInk)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

/// One switch, as a tile that's the button itself: tap to turn it on or
/// off. No separate toggle, which would be a second control doing the
/// same thing. The state shows in two ways, so it doesn't rest on colour
/// alone: on, a white tile with a dark icon; off, a beige tile with a
/// greyed icon struck through.
private struct SettingTile: View {
    let systemName: String
    let label: LocalizedStringKey
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.ink : Theme.quietInk)
                    // A drawn slash when off, the same for every icon (SF
                    // Symbols has slashed versions of some but not all).
                    .overlay {
                        if !isOn {
                            Capsule()
                                .fill(Theme.quietInk)
                                .frame(width: 2.5, height: 34)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    .frame(height: 32)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.secondaryInk : Theme.quietInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 16).fill(isOn ? Theme.surface : Theme.disabledFill))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.cellBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(SettingTileStyle())
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// A slight press-in, so a tile feels like something to tap now that it
/// has no switch on it.
private struct SettingTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A language to pick: its own name, and a tick on the current one.
private struct LanguageRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(verbatim: name)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.primary : Theme.cellBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("From home") {
    SettingsCard(context: .home(onHowToPlay: {}), onClose: {})
}

#Preview("From a level") {
    SettingsCard(context: .level(restart: .init(hasLettersToClear: true, action: {})), onClose: {})
}
