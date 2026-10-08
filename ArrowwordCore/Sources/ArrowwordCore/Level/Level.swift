import Foundation

/// A validated level, ready to play.
///
/// A `Level` can only be created from a `LevelFile` that satisfies every rule
/// in `LevelRules`; otherwise creation throws a `LevelError`. The rest of the
/// game can therefore trust a `Level` without checking it again.
public struct Level: Sendable {
    public let id: String
    public let clueLanguage: String
    public let answerLanguage: String
    public let rows: Int
    public let columns: Int
    /// Every answer, in reading order (`Answer.id` is the index).
    public let answers: [Answer]
    /// Starter letters, filled in from the beginning and never editable.
    public let givens: Set<Coordinate>
    /// Every letter cell, left to right and top to bottom.
    public let letterCells: [Coordinate]
    /// The distinct answer letters in the tray's order (the alphabet's order).
    public let trayLetters: [Character]

    /// The solution, row by row; nil marks a clue cell.
    private let solutionGrid: [[Character?]]
    /// For each letter cell, the answer it belongs to in each direction.
    private let answerIDsByCell: [Coordinate: [Direction: Int]]
    /// For each clue cell, its answers, top clue first.
    private let answerIDsByClueCell: [Coordinate: [Int]]

    // MARK: - Loading

    /// Decodes a level from JSON and validates it.
    public static func decode(from data: Data, rules: LevelRules = .standard) throws -> Level {
        let file = try JSONDecoder().decode(LevelFile.self, from: data)
        return try Level(file: file, rules: rules)
    }

    /// Validates a level file and builds the lookups the game needs.
    /// Checks run in a fixed order, so a broken level always reports the same
    /// first problem.
    public init(file: LevelFile, rules: LevelRules = .standard) throws {
        guard file.formatVersion == rules.supportedFormatVersion else {
            throw LevelError.unsupportedFormatVersion(file.formatVersion)
        }
        guard Alphabet.letters(for: file.clueLanguage) != nil else {
            throw LevelError.unsupportedLanguage(file.clueLanguage)
        }
        guard let alphabet = Alphabet.letters(for: file.answerLanguage) else {
            throw LevelError.unsupportedLanguage(file.answerLanguage)
        }

        let grid = try Self.parseGrid(file.grid, alphabet: Set(alphabet), rules: rules)
        let rowCount = grid.count
        let columnCount = grid[0].count
        func isInside(_ cell: Coordinate) -> Bool {
            (0..<rowCount).contains(cell.row) && (0..<columnCount).contains(cell.column)
        }

        var letterCells: [Coordinate] = []
        for row in 0..<rowCount {
            for column in 0..<columnCount where grid[row][column] != nil {
                letterCells.append(Coordinate(row: row, column: column))
            }
        }
        guard !letterCells.isEmpty else { throw LevelError.noLetterCells }

        let runs = try Self.buildRuns(file.clues, grid: grid, rules: rules, isInside: isInside)

        // Number the answers in reading order and index them by cell. An
        // answer is "overlapping" when a cell already belongs to another
        // answer in the same direction: the player couldn't tell which one
        // they're typing into.
        var answers: [Answer] = []
        var answerIDsByCell: [Coordinate: [Direction: Int]] = [:]
        var answerIDsByClueCell: [Coordinate: [Int]] = [:]
        for (id, run) in runs.enumerated() {
            let direction = run.clue.arrow.direction
            for cell in run.cells {
                if answerIDsByCell[cell]?[direction] != nil {
                    throw LevelError.overlappingAnswers(at: cell, direction)
                }
                answerIDsByCell[cell, default: [:]][direction] = id
            }
            answerIDsByClueCell[run.clueCell, default: []].append(id)
            answers.append(Answer(
                id: id,
                clueCell: run.clueCell,
                arrow: run.clue.arrow,
                clueText: run.clue.text,
                cells: run.cells,
                solution: String(run.cells.compactMap { grid[$0.row][$0.column] })
            ))
        }

        if let uncovered = letterCells.first(where: { answerIDsByCell[$0] == nil }) {
            throw LevelError.letterCellWithoutAnswer(uncovered)
        }

        let distinctLetters = Set(letterCells.compactMap { grid[$0.row][$0.column] })
        guard distinctLetters.count <= rules.maxDistinctLetters else {
            throw LevelError.tooManyDistinctLetters(distinctLetters.count)
        }

        for given in file.givens where !isInside(given) || grid[given.row][given.column] == nil {
            throw LevelError.givenNotOnLetterCell(given)
        }

        // In a split clue cell the right-exiting clue goes on top.
        let numberedAnswers = answers
        let stackedClues = answerIDsByClueCell.mapValues { ids in
            ids.sorted { first, second in
                !numberedAnswers[first].arrow.exitsBottom && numberedAnswers[second].arrow.exitsBottom
            }
        }

        self.id = file.id
        self.clueLanguage = file.clueLanguage
        self.answerLanguage = file.answerLanguage
        self.rows = rowCount
        self.columns = columnCount
        self.answers = numberedAnswers
        self.givens = Set(file.givens)
        self.letterCells = letterCells
        self.trayLetters = alphabet.filter { distinctLetters.contains($0) }
        self.solutionGrid = grid
        self.answerIDsByCell = answerIDsByCell
        self.answerIDsByClueCell = stackedClues
    }

    // MARK: - Queries

    public func contains(_ cell: Coordinate) -> Bool {
        (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
    }

    public func isClueCell(_ cell: Coordinate) -> Bool {
        contains(cell) && solutionGrid[cell.row][cell.column] == nil
    }

    public func isLetterCell(_ cell: Coordinate) -> Bool {
        solution(at: cell) != nil
    }

    /// The correct letter for a cell, or nil for clue cells and cells outside the grid.
    public func solution(at cell: Coordinate) -> Character? {
        contains(cell) ? solutionGrid[cell.row][cell.column] : nil
    }

    /// The answer a letter cell belongs to in the given direction, if any.
    public func answerID(at cell: Coordinate, direction: Direction) -> Int? {
        answerIDsByCell[cell]?[direction]
    }

    /// The answers clued in a clue cell, top clue first.
    public func answerIDs(atClueCell cell: Coordinate) -> [Int] {
        answerIDsByClueCell[cell] ?? []
    }

    /// The correct letter for a cell that's known to be a letter cell.
    /// Asking for a clue cell is a bug in the caller, so it stops the program
    /// rather than returning a value that could hide the mistake.
    func letter(at cell: Coordinate) -> Character {
        guard let letter = solution(at: cell) else {
            preconditionFailure("\(cell) is not a letter cell")
        }
        return letter
    }

    // MARK: - Validation helpers

    private static func parseGrid(
        _ lines: [String],
        alphabet: Set<Character>,
        rules: LevelRules
    ) throws -> [[Character?]] {
        let characterRows = lines.map { Array($0) }
        let columnCount = characterRows.first?.count ?? 0
        guard rules.rows.contains(characterRows.count), rules.columns.contains(columnCount) else {
            throw LevelError.gridSizeOutOfRange(rows: characterRows.count, columns: columnCount)
        }

        var grid: [[Character?]] = []
        for (rowIndex, characters) in characterRows.enumerated() {
            guard characters.count == columnCount else { throw LevelError.raggedGrid(row: rowIndex) }
            var row: [Character?] = []
            for (columnIndex, character) in characters.enumerated() {
                if character == LevelFile.clueMarker {
                    row.append(nil)
                    continue
                }
                guard alphabet.contains(character) else {
                    throw LevelError.letterNotInAlphabet(character, at: Coordinate(row: rowIndex, column: columnIndex))
                }
                row.append(character)
            }
            grid.append(row)
        }
        return grid
    }

    /// A clue with the cells its answer covers, before numbering.
    private struct Run {
        let clue: LevelFile.ClueEntry
        let clueCell: Coordinate
        let cells: [Coordinate]
    }

    /// Follows each clue's arrow to find its answer cells, then sorts the
    /// answers into reading order.
    private static func buildRuns(
        _ clues: [LevelFile.ClueEntry],
        grid: [[Character?]],
        rules: LevelRules,
        isInside: (Coordinate) -> Bool
    ) throws -> [Run] {
        var runs: [Run] = []
        var cluesPerCell: [Coordinate: Int] = [:]
        // An answer needs at least one cell even if the rules allowed 0,
        // because the reading-order sort reads each answer's first cell.
        let minimumLength = max(1, rules.minAnswerLength)

        for clue in clues {
            let clueCell = Coordinate(row: clue.row, column: clue.column)
            guard isInside(clueCell) else { throw LevelError.clueOutsideGrid(clueCell) }
            guard grid[clueCell.row][clueCell.column] == nil else { throw LevelError.clueNotOnClueCell(clueCell) }

            cluesPerCell[clueCell, default: 0] += 1
            guard cluesPerCell[clueCell, default: 0] <= rules.maxCluesPerCell else {
                throw LevelError.tooManyClues(at: clueCell)
            }

            let cells = answerCells(from: clueCell, arrow: clue.arrow, grid: grid)
            guard cells.count >= minimumLength else { throw LevelError.answerTooShort(clueAt: clueCell) }
            runs.append(Run(clue: clue, clueCell: clueCell, cells: cells))
        }

        // Reading order: across answers by row then column, then down answers
        // by column then row.
        func orderKey(_ run: Run) -> (Int, Int, Int) {
            let start = run.cells[0]
            return run.clue.arrow.direction == .across
                ? (0, start.row, start.column)
                : (1, start.column, start.row)
        }
        return runs.sorted { orderKey($0) < orderKey($1) }
    }

    /// The cells from the arrow's first cell up to the next clue cell or the grid edge.
    private static func answerCells(from clueCell: Coordinate, arrow: ClueArrow, grid: [[Character?]]) -> [Coordinate] {
        let step = arrow.direction.step
        var cell = clueCell.moved(rows: arrow.startOffset.rows, columns: arrow.startOffset.columns)
        var cells: [Coordinate] = []
        while cell.row < grid.count, cell.column < grid[0].count, grid[cell.row][cell.column] != nil {
            cells.append(cell)
            cell = cell.moved(rows: step.rows, columns: step.columns)
        }
        return cells
    }
}
