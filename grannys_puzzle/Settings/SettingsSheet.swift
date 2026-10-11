import SwiftUI
import UIKit
import AdKit

/// Settings: the music, sound and haptics switches, the game's language
/// (switched here, in the game, without a restart), feedback,
/// the legal pages, credits and the version.
///
/// It's a sheet over whatever screen opened it (home or a level), so the
/// player comes back exactly where they were. It reads and writes
/// `UserDefaults` through `@AppStorage` and knows nothing about `Game`:
/// none of these settings is part of the player's progress.
///
/// "Privacy choices" reopens the ad consent form. It only appears where
/// consent applies (EU, UK, some US states), which the ads controller knows.
///
/// Still to come, when the things they control exist:
/// - "Save your progress" (Sign in with Apple), and "Delete account" once an
///   account is linked, which App Store rules require.
struct SettingsSheet: View {
    /// Replays grandma's lesson. Only the home screen offers it: from inside
    /// a level it would mean leaving the level, which is a surprise.
    var onHowToPlay: (() -> Void)? = nil

    @AppStorage(ToggleSetting.music.key) private var musicOn = ToggleSetting.music.defaultValue
    @AppStorage(ToggleSetting.sound.key) private var soundOn = ToggleSetting.sound.defaultValue
    @AppStorage(ToggleSetting.haptics.key) private var hapticsOn = ToggleSetting.haptics.defaultValue
    /// The game's language. The app root watches the same key and switches
    /// the text and the puzzles the moment it changes.
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.current.rawValue

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Nil in previews.
    @Environment(AdsController.self) private var ads: AdsController?

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

                Section {
                    languagePicker
                } footer: {
                    Text("Each language has its own puzzles and remembers your level.")
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
                    if let ads, ads.isPrivacyOptionsRequired {
                        // Required by Google's consent rules wherever the
                        // form was shown: changing your mind must be as easy
                        // as the first choice.
                        Button {
                            Task { await ads.presentPrivacyOptions() }
                        } label: {
                            Label("Privacy choices", systemImage: "checkmark.shield")
                        }
                        .foregroundStyle(Theme.ink)
                    }
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

    /// Languages are listed by their own names ("English", "Türkçe"), not
    /// translated, so a player can find theirs whatever is showing now.
    private var languagePicker: some View {
        Picker(selection: $languageCode) {
            ForEach(AppLanguage.allCases) { language in
                Text(verbatim: language.nativeName).tag(language.rawValue)
            }
        } label: {
            Label("Language", systemImage: "globe")
        }
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

}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { SettingsSheet() }
}
