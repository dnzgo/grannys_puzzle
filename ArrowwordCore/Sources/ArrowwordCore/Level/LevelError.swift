/// Why a level was rejected while loading.
///
/// These are *expected* failures (bad or too-new data from a pack), not
/// programming errors, so they're thrown rather than crashing the app. Each
/// case carries enough detail to find the broken level in a log.
public enum LevelError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(Int)
    case unsupportedLanguage(String)
    case gridSizeOutOfRange(rows: Int, columns: Int)
    case raggedGrid(row: Int)
    case letterNotInAlphabet(Character, at: Coordinate)
    case noLetterCells
    /// More gaps than `LevelRules.maxGapShare` allows.
    case tooManyGaps(Int)
    case clueOutsideGrid(Coordinate)
    case clueNotOnClueCell(Coordinate)
    case answerTooShort(clueAt: Coordinate)
    case tooManyClues(at: Coordinate)
    case overlappingAnswers(at: Coordinate, Direction)
    case letterCellWithoutAnswer(Coordinate)
    case tooManyDistinctLetters(Int)
    case givenNotOnLetterCell(Coordinate)
}
