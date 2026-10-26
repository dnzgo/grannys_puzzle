import Foundation

/// A sound for one moment: which file (or files) and how loud.
///
/// Files are looked up by name in the app bundle, as .caf, .m4a or .wav, in
/// that order, so a placeholder .wav is replaced by dropping in a real file
/// with the same name. The names are listed in docs/Audio.md.
struct SoundEffect: Equatable {
    /// File names without the extension. More than one means variations of
    /// the same sound, rotated so the same one never plays twice in a row.
    let files: [String]
    /// 0 to 1: turns a file down (never up). The current files come
    /// already mixed against each other (docs/Audio.md), so they all play
    /// at 1; this is for adjusting one moment after trying it on a phone.
    let volume: Float

    init(_ name: String, volume: Float = 1) {
        files = [name]
        self.volume = volume
    }

    /// "letter-placed", 3 → letter-placed-1, letter-placed-2, letter-placed-3.
    init(_ name: String, variations: Int, volume: Float = 1) {
        files = (1...variations).map { "\(name)-\($0)" }
        self.volume = volume
    }
}

extension FeedbackEvent {
    /// How each moment sounds. The same idea as the haptics: the frequent
    /// little actions are quiet so the rare big moments stand out (a letter
    /// click as loud as a fanfare, fifty times a level, would wear anyone
    /// out). That balance is in the files themselves for now.
    ///
    /// Sounds that repeat quickly (typing, yarn landing three in a row) have
    /// variations: the ear notices an identical sound repeated much sooner
    /// than a slightly different one. A fanfare plays once, so one file is enough.
    var sound: SoundEffect {
        switch self {
        case .select: SoundEffect("select")
        case .letterPlaced: SoundEffect("letter-placed", variations: 4)
        case .letterErased: SoundEffect("letter-erased")
        case .reveal: SoundEffect("reveal")
        case .levelPassed: SoundEffect("level-passed")
        case .levelFailed: SoundEffect("level-failed")
        case .itemKnitted: SoundEffect("item-knitted")
        case .jarOpened: SoundEffect("jar-opened")
        case .helperEarned: SoundEffect("helper-earned")
        case .yarnLanded: SoundEffect("yarn-landed", variations: 3)
        case .jarShaken: SoundEffect("jar-shaken")
        case .prizeLanded: SoundEffect("prize-landed")
        case .submitted: SoundEffect("submit")
        case .cellsJudged: SoundEffect("cells-judged", variations: 4)
        }
    }
}

/// Picks which variation of a sound plays next: at random, but never the
/// one that played last time, which is what makes repeats noticeable.
struct VariationPicker {
    /// The index played last, per sound (keyed by its first file name).
    private var lastPlayed: [String: Int] = [:]

    /// `random` is injectable so the rule can be tested without luck.
    mutating func next(
        for effect: SoundEffect,
        random: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) -> String {
        let count = effect.files.count
        guard count > 1, let key = effect.files.first else { return effect.files[0] }
        var index = random(0..<count)
        if let last = lastPlayed[key] {
            // Draw from the other count - 1 and step over the last one, so
            // every other variation stays equally likely (redrawing until
            // it differs would also work, but this never loops).
            index = random(0..<(count - 1))
            if index >= last { index += 1 }
        }
        lastPlayed[key] = index
        return effect.files[index]
    }
}
