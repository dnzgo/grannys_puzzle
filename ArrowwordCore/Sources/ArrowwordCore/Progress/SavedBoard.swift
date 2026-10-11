/// A level left halfway: the letters the player placed and the ones the cat
/// or grandma revealed, so the level can pick up where they left off.
///
/// Starter letters aren't saved; they come from the level itself.
public struct SavedBoard: Codable, Equatable, Sendable {
    public struct Letter: Codable, Equatable, Sendable {
        public var row: Int
        public var column: Int
        /// One letter, as a string so the JSON stays readable.
        public var letter: String
        /// True for letters the cat or grandma filled in: they were paid for,
        /// so they come back as revealed (locked) letters, not typed ones.
        public var revealed: Bool

        public init(row: Int, column: Int, letter: String, revealed: Bool) {
            self.row = row
            self.column = column
            self.letter = letter
            self.revealed = revealed
        }
    }

    public var levelID: String
    /// `Level.fingerprint` when the board was saved. Regenerating a pack keeps
    /// level ids but can change the grid; a fingerprint mismatch means the
    /// saved letters belong to a different puzzle and must not be restored.
    public var levelFingerprint: String
    public var letters: [Letter]

    public init(levelID: String, levelFingerprint: String, letters: [Letter]) {
        self.levelID = levelID
        self.levelFingerprint = levelFingerprint
        self.letters = letters
    }
}

extension Level {
    /// A short, stable code for this level's grid: the same grid always gives
    /// the same code, on every launch and device.
    ///
    /// Swift's own `hashValue` can't be used for this: it's deliberately
    /// randomised per launch (the same trap as the Python generator's set
    /// order). This is FNV-1a, a tiny, well-known hash, over the grid as
    /// text. Clue texts aren't included, since rewording a clue doesn't move
    /// any letters.
    public var fingerprint: String {
        var text = "\(rows)x\(columns):"
        for row in 0..<rows {
            for column in 0..<columns {
                text.append(solution(at: Coordinate(row: row, column: column)) ?? "#")
            }
            text.append("/")
        }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return String(hash, radix: 16)
    }
}
