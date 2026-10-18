import SwiftUI
import os
import AdKit
import ArrowwordCore
import NotifyKit

/// The app's root: loads the game once, then hands over to `GameView`.
struct ContentView: View {
    /// Hears taps on grandma's reminders. Made by the App at launch (a tap
    /// that opens the app arrives before any screen exists), handed here so
    /// the taps reach the game once it's loaded.
    let reminderTaps: ReminderTapRelay

    @State private var startup = Startup.load()
    @Environment(\.scenePhase) private var scenePhase
    /// The in-game language choice (Settings → Language). Changing it here
    /// swaps the text at once (through the environment's locale) and the
    /// puzzles (through the game).
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.current.rawValue

    var body: some View {
        switch startup {
        case .ready(let game):
            GameView(game: game)
                // Views that show ads (the banner, Settings' privacy row)
                // read the controller from here instead of through Game.
                .environment(game.ads)
                // Settings' reminder switch reads it the same way.
                .environment(game.reminders)
                // Every `Text` below looks its words up in this locale.
                .environment(\.locale, (AppLanguage(rawValue: languageCode) ?? .english).locale)
                .onChange(of: languageCode) { _, newCode in
                    game.switchLanguage(to: newCode)
                }
                // Once per launch: the server's numbers, if any.
                .task { await game.loadRemoteTuning() }
                // Re-plan grandma's reminders on every change (opening, going
                // inactive, going to the background), so whatever the player
                // does, even swiping the app away, a fresh schedule is left
                // behind. `initial` also runs it for the launch itself.
                .onChange(of: scenePhase, initial: true) { _, _ in
                    Task { await game.refreshReminders() }
                }
                .onAppear {
                    // Also delivers a tap that launched the app, held until now.
                    reminderTaps.onTap = { kind in game.reminderOpened(kind: kind) }
                }
        case .failed(let message):
            // A bundled pack failing to load is a bug in the build, but the
            // app should say so instead of crashing.
            ContentUnavailableView(
                "The puzzles couldn't be loaded",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}

/// Switches between the home screen and a level.
struct GameView: View {
    let game: Game

    var body: some View {
        ZStack {
            switch game.screen {
            case .home:
                HomeView(game: game)
                    .transition(.opacity)
            case .level(let model):
                LevelScreen(model: model)
                    // A new identity per level, so SwiftUI starts the next
                    // level's views fresh instead of reusing the last one's.
                    .id(model.level.id)
                    .transition(.opacity)
            }
        }
    }
}

private enum Startup {
    case ready(Game)
    case failed(String)

    static func load() -> Startup {
        // First, before the ads controller exists: Google's consent check
        // (which the home screen starts) must find Firebase running.
        let services = ServicesSetup.start()
        do {
            let language = AppLanguage.current.rawValue
            let content = try LevelLoader.content(for: language)
            let game = Game(
                pack: content.pack,
                tutorial: content.tutorial,
                daily: content.daily,
                language: language,
                store: progressStore(),
                ads: AdsSetup.makeController(),
                reminders: Reminders(scheduler: SystemReminderScheduler()),
                services: services,
                loadContent: LevelLoader.content(for:)
            )
            game.startTutorialIfNeeded()
            return .ready(game)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// If even the save folder can't be found, play without saving rather
    /// than not at all, and log why.
    private static func progressStore() -> ProgressStore? {
        do {
            return try ProgressStore.standard()
        } catch {
            Logger(subsystem: "grannys_puzzle", category: "progress")
                .error("No save folder, progress won't be kept: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

#Preview {
    if let game = Game.preview() {
        GameView(game: game)
    }
}
