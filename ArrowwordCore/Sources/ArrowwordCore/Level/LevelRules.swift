/// The limits every level must respect.
///
/// This is the app's copy of the level format spec. The level generator
/// enforces the same numbers before a level ships; the app checks again when
/// loading, to catch corrupted downloads or packs newer than the app. If the
/// two copies ever disagree, both checks "pass" while contradicting each
/// other, so change them together. (Later, both can read one shared spec
/// file.)
public struct LevelRules: Sendable {
    public var supportedFormatVersion = 1
    public var rows: ClosedRange<Int> = 5...12
    public var columns: ClosedRange<Int> = 5...10
    /// The letter tray has 8 columns × 3 rows.
    public var maxDistinctLetters = 24
    /// A clue cell is split in two at most.
    public var maxCluesPerCell = 2
    /// At most this share of a board's cells may be gaps (see LevelFile):
    /// enough for the generator to leave awkward spots empty, not so many
    /// that the board looks moth-eaten.
    public var maxGapShare = 0.12
    /// The same for a shaped board (a circle, a diamond, an H: see
    /// `LevelFile.shape`), counting the cells its shape leaves out. The app
    /// doesn't know the shapes, so it can't tell those from other gaps; the
    /// generator keeps the 12% on the shape's own cells.
    public var maxShapeGapShare = 0.45
    public var minAnswerLength = 2

    public init() {}

    public static let standard = LevelRules()
}

/// The answer alphabets the game supports, in the order the letter tray
/// shows them.
///
/// The order can't come from sorting characters: Unicode puts Ç, Ğ, İ, Ö, Ş
/// and Ü after Z, but Turkish players expect them next to C, G, I, O, S, U.
public enum Alphabet {
    static let orderedLetters: [String: [Character]] = [
        "en": Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        "tr": Array("ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"),
    ]

    /// The alphabet for a language code, or nil if the game doesn't support it.
    public static func letters(for language: String) -> [Character]? {
        orderedLetters[language]
    }
}
