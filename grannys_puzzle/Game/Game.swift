import Foundation
import Observation
import os
import AdKit
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
    /// Nil in previews (no ads there).
    let ads: AdsController?
    /// The lesson's board. Nil only if it failed to load, a build problem
    /// that the tests catch; the game then simply plays without it.
    let tutorial: Level?
    private(set) var progress: PlayerProgress
    private(set) var screen: Screen = .home

    /// Nil in previews, so previews never touch the real save file.
    @ObservationIgnored private let store: ProgressStore?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "progress")
    /// Stands in for the game while the lesson plays (see TutorialHost).
    /// Kept here because levels only hold their host weakly.
    @ObservationIgnored private let tutorialHost = TutorialHost()

    init(
        pack: LevelPack,
        tutorial: Level? = nil,
        store: ProgressStore?,
        ads: AdsController? = nil,
        catalog: KnittingCatalog = .standard
    ) {
        self.pack = pack
        self.ads = ads
        self.tutorial = tutorial
        self.catalog = catalog
        self.store = store
        self.progress = .newPlayer
        if let store {
            progress = loadProgress(from: store)
        }
        tutorialHost.game = self
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

    // MARK: - Daily jar

    /// Opens the jar for `today` (a `JarDay` number) and saves at once, before
    /// any animation. Nil if it was already opened today.
    func openJar(today: Int) -> JarOpening? {
        var opening: JarOpening?
        update { opening = $0.openJar(today: today, using: &generator) }
        return opening
    }

    // MARK: - Tutorial

    /// Opens the lesson if the player hasn't been through it. Called once at
    /// launch, rather than from `init`, so creating a `Game` (in a preview,
    /// say) never changes the screen by itself.
    func startTutorialIfNeeded() {
        if !progress.tutorialDone { startTutorial() }
    }

    /// Plays the lesson: on first launch, or again from Settings.
    func startTutorial() {
        guard let tutorial else { return }
        guard let coach = TutorialCoach(script: .standard, level: tutorial) else {
            // The script names a word the board lacks; a test checks this,
            // so it can only happen with a mismatched build.
            logger.error("Tutorial script doesn't fit the tutorial board; skipping it")
            return
        }
        screen = .level(LevelViewModel(
            puzzle: PuzzleState(level: tutorial),
            levelNumber: 0,
            host: tutorialHost,
            coach: coach
        ))
    }

    /// The lesson's board was solved: its yarn, the first time only.
    func completeTutorial() -> [YarnColor] {
        var earned: [YarnColor] = []
        update { earned = $0.completeTutorial(using: &generator) }
        return earned
    }

    /// Leaving the lesson, finished or skipped. Either way it's done: a
    /// player who skipped chose not to see it, so it doesn't come back
    /// (Settings has it if they change their mind).
    func leaveTutorial() {
        if !progress.tutorialDone {
            update { $0.tutorialDone = true }
        }
        screen = .home
    }

    // MARK: - Navigation

    /// Opens the player's next level, picking up where they left it if they
    /// left it halfway.
    func play() {
        guard let number = nextLevelNumber else { return }
        let level = pack.levels[number - 1]
        screen = .level(LevelViewModel(puzzle: startingPuzzle(for: level), levelNumber: number, host: self))
    }

    /// The level as the player left it, or fresh if there's no saved board
    /// for it (or the saved one no longer fits, e.g. the pack was regenerated).
    private func startingPuzzle(for level: Level) -> PuzzleState {
        guard let saved = progress.board else { return PuzzleState(level: level) }
        if let restored = PuzzleState.restored(level: level, from: saved) {
            return restored
        }
        // Expected after a pack update; anything else is worth knowing about.
        logger.notice("Saved board didn't fit level \(level.id, privacy: .public); starting fresh")
        update { $0.board = nil }
        return PuzzleState(level: level)
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
        update {
            earned = $0.record(result, using: &generator)
            // Judged boards are finished: a pass moves on, a fail starts over.
            $0.board = nil
        }
        return earned
    }

    var canWatchAdForHelper: Bool {
        ads?.isRewardedReady ?? false
    }

    func watchAd(for reward: HelperAdReward) async -> Bool {
        // Granted only when the ad reports the reward as earned, and saved
        // right away like every other change.
        guard let ads, await ads.showRewarded() else { return false }
        update { progress in
            switch reward {
            case .catHints: progress.hints += reward.amount
            case .grandma: progress.grandmas += reward.amount
            }
        }
        return true
    }

    func saveBoard(_ board: SavedBoard?) {
        // Each change writes the progress file. It's a few kilobytes, so this
        // is cheap, and it means even a crash or a force-quit keeps the board.
        update { $0.board = board }
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
