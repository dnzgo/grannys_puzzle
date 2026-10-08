/// A level exactly as it's stored in a JSON level pack.
///
/// This is deliberately separate from `Level`:
/// - `LevelFile` is the *storage format*: plain data, decoded as-is, versioned
///   with `formatVersion` so the format can change later.
/// - `Level` is the *game's model*: validated, with lookups precomputed.
/// Decoding and validating then become two clear steps, and a format change
/// only touches the conversion between them, not the game logic.
public struct LevelFile: Codable, Sendable, Equatable {
    public struct ClueEntry: Codable, Sendable, Equatable {
        public var row: Int
        public var column: Int
        public var arrow: ClueArrow
        public var text: String

        public init(row: Int, column: Int, arrow: ClueArrow, text: String) {
            self.row = row
            self.column = column
            self.arrow = arrow
            self.text = text
        }
    }

    public var formatVersion: Int
    public var id: String
    /// Language codes such as "tr" or "en". They're stored separately so a
    /// future learning mode (Turkish clues, English answers) needs no
    /// format migration.
    public var clueLanguage: String
    public var answerLanguage: String
    /// One string per row. "#" marks a clue cell; every other character is
    /// that cell's solution letter, already uppercased by the generator.
    /// (Uppercasing is language-sensitive, as with Turkish i → İ, so the app
    /// never does it.)
    public var grid: [String]
    public var clues: [ClueEntry]
    /// Starter letters shown filled in from the beginning.
    public var givens: [Coordinate]

    public init(
        formatVersion: Int,
        id: String,
        clueLanguage: String,
        answerLanguage: String,
        grid: [String],
        clues: [ClueEntry],
        givens: [Coordinate]
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.clueLanguage = clueLanguage
        self.answerLanguage = answerLanguage
        self.grid = grid
        self.clues = clues
        self.givens = givens
    }

    /// The character that marks a clue cell in `grid`.
    static let clueMarker: Character = "#"
}
