import Foundation
import Observation
import os
import ArrowwordCore

/// The running game: the player's saved progress, the level pack, and which
/// screen is showing.
///
/// It's the one place that changes `PlayerProgress`, and it saves after
/// every change. Saving right away (not on app exit) matters because iOS can
/// end a backgrounded app without warning; a helper spent or a reward earned
/// must already be on disk by then.
@Observable
final class Game {
    enum Screen {
        case home
        case level(LevelViewModel)
    }

    let pack: LevelPack
    let catalog: KnittingCatalog
    private(set) var progress: PlayerProgress
    private(set) var screen: Screen = .home

    /// Nil in previews, so previews never touch the real save file.
    @ObservationIgnored private let store: ProgressStore?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "progress")

    init(pack: LevelPack, store: ProgressStore?, catalog: KnittingCatalog = .standard) {
        self.pack = pack
        self.catalog = catalog
        self.store = store
        self.progress = .newPlayer
        if let store {
            progress = loadProgress(from: store)
        }
    }

    // MARK: - What the home screen shows

    /// The level the Play button starts, if the pack has one left.
    var nextLevelNumber: Int? {
        pack.levels.indices.contains(progress.levelNumber - 1) ? progress.levelNumber : nil
    }

    /// True when the player can afford at least one item they don't own yet;
    /// the home screen uses it to nudge them toward the yarn bag.
    var canKnitSomething: Bool {
        catalog.items.contains(where: progress.canKnit)
    }

    // MARK: - Knitting

    /// Knits an item if the player can afford it, and saves at once, before
    /// any animation plays. Returns whether it was knitted.
    func knit(_ item: KnitItem) -> Bool {
        var outcome = PlayerProgress.KnitOutcome.alreadyOwned
        update { outcome = $0.knit(item) }
        return outcome == .knitted
    }

    // MARK: - Navigation

    /// Opens the player's next level. The board always starts fresh: a level
    /// left halfway isn't resumed yet (that needs saving the board too).
    func play() {
        guard let number = nextLevelNumber else { return }
        screen = .level(LevelViewModel(level: pack.levels[number - 1], levelNumber: number, host: self))
    }

    // MARK: - Saving

    private func update(_ change: (inout PlayerProgress) -> Void) {
        change(&progress)
        save()
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(progress)
        } catch {
            // Rare (a full disk) and nothing the player can fix from here.
            // The game keeps going with the progress in memory, and the next
            // successful save writes all of it.
            logger.error("Saving progress failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadProgress(from store: ProgressStore) -> PlayerProgress {
        do {
            return try store.load()
        } catch {
            // A damaged or too-new save. Starting over is the only way to
            // keep playing, but the old file is moved aside, not overwritten,
            // so it can still be recovered.
            logger.error("Saved progress unreadable, starting fresh: \(error.localizedDescription, privacy: .public)")
            do {
                try store.setAsideDamagedFile()
            } catch {
                logger.error("Couldn't set the damaged save aside: \(error.localizedDescription, privacy: .public)")
            }
            return .newPlayer
        }
    }
}

// MARK: - LevelHost

extension Game: LevelHost {
    var hints: Int { progress.hints }
    var grandmas: Int { progress.grandmas }

    func spendHint() -> Bool {
        var spent = false
        update { spent = $0.spendHint() }
        return spent
    }

    func spendGrandma() -> Bool {
        var spent = false
        update { spent = $0.spendGrandma() }
        return spent
    }

    func record(_ result: LevelResult) -> [YarnColor] {
        var earned: [YarnColor] = []
        update { earned = $0.record(result, using: &generator) }
        return earned
    }

    func continueToNextLevel() {
        // After the last level in the pack, home shows that more are coming.
        if nextLevelNumber != nil {
            play()
        } else {
            screen = .home
        }
    }

    func goHome() {
        screen = .home
    }
}

// MARK: - Previews

extension Game {
    /// A game for SwiftUI previews: the bundled pack, a made-up bag, no saving.
    static func preview() -> Game? {
        guard let pack = try? LevelLoader.bundledPack(named: LevelLoader.firstPackName) else { return nil }
        let game = Game(pack: pack, store: nil)
        game.progress = PlayerProgress(
            levelNumber: 7, hints: 3, grandmas: 1,
            yarn: [.red: 8, .blue: 2, .green: 1],
            wardrobe: ["cat.scarf.yellow"]
        )
        return game
    }
}
