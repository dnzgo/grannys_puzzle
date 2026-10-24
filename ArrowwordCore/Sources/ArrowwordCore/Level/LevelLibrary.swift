/// One language's levels across all of its packs, as a single numbered list.
///
/// Packs hold `packSize` levels each and come in order: pack 1 is levels
/// 1–100, pack 2 levels 101–200, and so on. Pack 1 ships in the app; the
/// rest are downloaded as the player nears the end of what they have.
///
/// A level's place is worked out from the pack size alone, never by adding
/// up how many levels earlier packs hold. Saved progress is a level number,
/// so level 150 must be the same puzzle on every phone, whichever packs it
/// has. That's also the rule for producing packs: a published pack keeps
/// its place and its size (fixing a clue inside one is fine), and new
/// levels only ever arrive as new packs at the end.
public struct LevelLibrary: Sendable {
    /// Levels in a full pack.
    public static let packSize = 100
    /// Played levels in the last pack after which the next one is fetched:
    /// 90%, leaving ten levels of play to cover a failed or slow download.
    public static let prefetchAfter = 90

    /// Why a pack can't join the library.
    public enum AppendError: Error, Equatable, Sendable {
        case languageMismatch(expected: String, found: String)
        /// More levels than a pack's place has room for: they'd spill into
        /// the next pack's numbers.
        case packTooLarge(id: String, levels: Int)
        /// A pack after one that isn't full would leave level numbers with
        /// no puzzle between them.
        case previousPackNotFull
    }

    public let language: String
    /// In order: `packs[0]` is pack 1.
    public private(set) var packs: [LevelPack]

    /// An empty library; packs are added with `append(_:)`.
    public init(language: String) {
        self.language = language
        self.packs = []
    }

    /// A library of these packs, in order.
    public init(packs: [LevelPack]) throws {
        guard let first = packs.first else { throw LevelPackError.noLevels }
        self.init(language: first.language)
        for pack in packs {
            try append(pack)
        }
    }

    /// Adds the next pack. Checked here rather than trusted, because a
    /// downloaded pack comes from outside the app.
    public mutating func append(_ pack: LevelPack) throws {
        guard pack.language == language else {
            throw AppendError.languageMismatch(expected: language, found: pack.language)
        }
        guard pack.levels.count <= Self.packSize else {
            throw AppendError.packTooLarge(id: pack.id, levels: pack.levels.count)
        }
        if let last = packs.last, last.levels.count < Self.packSize {
            throw AppendError.previousPackNotFull
        }
        packs.append(pack)
    }

    /// The number the next pack to download will have (1-based).
    public var nextPackNumber: Int { packs.count + 1 }

    /// How many levels can be played in a row from level 1: the full packs
    /// and whatever the last one holds.
    public var levelCount: Int {
        guard let last = packs.last else { return 0 }
        return (packs.count - 1) * Self.packSize + last.levels.count
    }

    /// Level `number` (1-based), or nil if no pack here holds it.
    public func level(number: Int) -> Level? {
        guard number >= 1 else { return nil }
        let packIndex = (number - 1) / Self.packSize
        let levelIndex = (number - 1) % Self.packSize
        guard packs.indices.contains(packIndex), packs[packIndex].levels.indices.contains(levelIndex) else {
            return nil
        }
        return packs[packIndex].levels[levelIndex]
    }

    /// Whether the next pack should be fetched, with level `nextNumber` the
    /// next to play: true once `prefetchAfter` levels of the last pack are
    /// behind the player, and from then on (also past the end, when the
    /// player ran out offline and the pack is still missing).
    public func wantsNextPack(nextNumber: Int) -> Bool {
        let played = nextNumber - 1
        let lastPackStart = max(0, packs.count - 1) * Self.packSize
        return played - lastPackStart >= Self.prefetchAfter
    }
}
