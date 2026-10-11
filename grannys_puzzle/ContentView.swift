import SwiftUI
import os
import AdKit
import ArrowwordCore

/// The app's root: loads the game once, then hands over to `GameView`.
struct ContentView: View {
    @State private var startup = Startup.load()

    var body: some View {
        switch startup {
        case .ready(let game):
            GameView(game: game)
                // Views that show ads (the banner, Settings' privacy row)
                // read the controller from here instead of through Game.
                .environment(game.ads)
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
        do {
            let pack = try LevelLoader.bundledPack(named: LevelLoader.firstPackName)
            let game = Game(
                pack: pack,
                tutorial: tutorialLevel(),
                store: progressStore(),
                ads: AdsSetup.makeController()
            )
            game.startTutorialIfNeeded()
            return .ready(game)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// Unlike the level pack, a missing lesson isn't worth stopping the
    /// game for: players can still play, so log it and go on without.
    private static func tutorialLevel() -> Level? {
        do {
            return try LevelLoader.bundledPack(named: LevelLoader.tutorialPackName).levels.first
        } catch {
            Logger(subsystem: "grannys_puzzle", category: "tutorial")
                .error("Tutorial couldn't be loaded: \(String(describing: error), privacy: .public)")
            return nil
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
