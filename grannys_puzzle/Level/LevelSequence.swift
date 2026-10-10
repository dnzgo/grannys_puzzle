import Foundation
import Observation
import ArrowwordCore

/// Plays a pack's levels in order: owns which level is current and creates
/// the next level's view model when the player passes one.
///
/// Why a separate object: `LevelViewModel` handles everything *inside* one
/// level and knows nothing about packs. Moving between levels is a different
/// job, so it lives here, and the view model just reports "passed" through
/// a callback.
@Observable
final class LevelSequence {
    let pack: LevelPack
    /// The current level's index in the pack.
    private(set) var position: Int
    /// The level being played; nil once every level in the pack is done.
    private(set) var current: LevelViewModel?

    init(pack: LevelPack, startingAt position: Int = 0) {
        self.pack = pack
        self.position = position
        self.current = nil
        // A fresh wallet for now; the progression phase replaces this with
        // the saved player profile.
        self.current = makeLevel(
            at: position,
            hints: LevelViewModel.startingHints,
            grandmas: LevelViewModel.startingGrandmas
        )
    }

    /// The number shown to the player ("LEVEL 12"): 1-based, not the index.
    /// With several packs this becomes the position across all of them.
    private func levelNumber(at position: Int) -> Int {
        position + 1
    }

    private func makeLevel(at position: Int, hints: Int, grandmas: Int) -> LevelViewModel? {
        guard pack.levels.indices.contains(position) else { return nil }
        return LevelViewModel(
            level: pack.levels[position],
            levelNumber: levelNumber(at: position),
            hints: hints,
            grandmas: grandmas,
            // `weak self`: the sequence owns the view model, and the view
            // model keeps this closure. A strong reference would form a
            // retain cycle and neither would ever be freed.
            onPassed: { [weak self] in self?.advance() }
        )
    }

    /// Moves to the next level, carrying the cat and grandma counts over so
    /// helpers used on one level stay used.
    private func advance() {
        guard let finished = current else { return }
        position += 1
        current = makeLevel(at: position, hints: finished.hints, grandmas: finished.grandmas)
    }
}
