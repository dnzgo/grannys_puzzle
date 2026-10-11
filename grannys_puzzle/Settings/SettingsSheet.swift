import SwiftUI
import UIKit

/// Settings: the music, sound and haptics switches, language, feedback,
/// the legal pages, credits and the version.
///
/// It's a sheet over whatever screen opened it (home or a level), so the
/// player comes back exactly where they were. It reads and writes
/// `UserDefaults` through `@AppStorage` and knows nothing about `Game`:
/// none of these settings is part of the player's progress.
///
/// Still to come, when the things they control exist:
/// - "Privacy choices": the ad consent form (Google's UMP), added with ads.
///   It's only required where consent applies, and UMP says when.
/// - "Save your progress" (Sign in with Apple), and "Delete account" once an
///   account is linked, which App Store rules require.
struct SettingsSheet: View {
    /// Replays grandma's lesson. Only the home screen offers it: from inside
    /// a level it would mean leaving the level, which is a surprise.
    var onHowToPlay: (() -> Void)? = nil

    @AppStorage(ToggleSetting.music.key) private var musicOn = ToggleSetting.music.defaultValue
    @AppStorage(ToggleSetting.sound.key) private var soundOn = ToggleSetting.sound.defaultValue
    @AppStorage(ToggleSetting.haptics.key) private var hapticsOn = ToggleSetting.haptics.defaultValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Set when Mail couldn't open, so the player still gets the address.
    @State private var showsMailFallback = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $musicOn) { Label("Music", systemImage: "music.note") }
                    Toggle(isOn: $soundOn) { Label("Sound effects", systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $hapticsOn) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
                }

                if Self.hasSeveralLanguages {
                    Section {
                        languageRow
                    } footer: {
                        Text("Changes the app's language in the iPhone Settings app.")
                    }
                }

                if let onHowToPlay {
                    Section {
                        Button {
                            dismiss()
                            onHowToPlay()
                        } label: {
                            Label("How to play", systemImage: "questionmark.circle")
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }

                Section {
                    feedbackRow
                    linkRow("Terms of Use", systemImage: "doc.text", url: SupportLinks.termsOfUse)
                    linkRow("Privacy Policy", systemImage: "hand.raised", url: SupportLinks.privacyPolicy)
                    NavigationLink {
                        AcknowledgementsView()
                    } label: {
                        Label("Acknowledgements", systemImage: "heart.text.square")
                    }
                }

                Section {
                    LabeledContent("Version", value: AppVersion.displayText)
                        .monospacedDigit()
                }
            }
            .tint(Theme.primary)
            .foregroundStyle(Theme.ink)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Couldn't open Mail", isPresented: $showsMailFallback) {
                Button("OK", role: .cancel) {}
            } message: {
                // Only reachable when the address is set: the row is
                // disabled otherwise.
                Text("You can write to us at \(SupportLinks.feedbackEmail ?? "")")
            }
        }
        // Like the rest of the app, light only until the art has a dark version.
        .preferredColorScheme(.light)
    }

    // MARK: - Rows

    /// iOS keeps each app's language in the Settings app (iPhone Settings →
    /// Granny's Puzzle → Language) and restarts the app when it changes, so
    /// the app doesn't need its own picker; this row just takes the player
    /// there. iOS only shows that option when the app ships more than one
    /// language, which is why the row is hidden until Turkish is added.
    private var languageRow: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            LabeledContent {
                Text(Self.currentLanguageName)
            } label: {
                Label("Language", systemImage: "globe")
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private var feedbackRow: some View {
        let mail = SupportLinks.feedbackMail(systemVersion: UIDevice.current.systemVersion)
        return Button {
            guard let mail else { return }
            // Fails when the player has no mail app set up; tell them the
            // address instead of the tap doing nothing.
            openURL(mail) { accepted in
                if !accepted { showsMailFallback = true }
            }
        } label: {
            rowLabel("Send feedback", systemImage: "envelope", isAvailable: mail != nil)
        }
        .disabled(mail == nil)
    }

    private func linkRow(_ title: LocalizedStringKey, systemImage: String, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            rowLabel(title, systemImage: systemImage, isAvailable: url != nil)
        }
        .disabled(url == nil)
    }

    /// A row's label, with "Coming soon" while its link isn't set yet.
    private func rowLabel(_ title: LocalizedStringKey, systemImage: String, isAvailable: Bool) -> some View {
        LabeledContent {
            if !isAvailable { Text("Coming soon") }
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(isAvailable ? Theme.ink : Theme.quietInk)
        }
    }

    // MARK: - Language

    /// True when the app is translated into more than one language. "Base"
    /// is Xcode's development folder, not a language a player can choose.
    private static var hasSeveralLanguages: Bool {
        Bundle.main.localizations.filter { $0 != "Base" }.count > 1
    }

    /// The language the app is showing, named in that language ("English",
    /// "Türkçe"), the way iOS lists languages.
    private static var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.localizedCapitalized ?? code
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { SettingsSheet() }
}
