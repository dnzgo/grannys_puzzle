/// The state of one level being played: what's on the board, which cell is
/// selected, and the result once submitted.
///
/// It's a value type with no UI, ads or wallet inside it. That keeps it fully
/// unit-testable and keeps responsibilities apart:
/// - deciding *whether* the player may use the cat or grandma (wallet, ads)
///   is the economy's job;
/// - `PuzzleState` only knows *what happens on the board* when they do.
/// The SwiftUI layer wraps it in an observable view model.
public struct PuzzleState: Sendable {
    public enum Source: Sendable, Equatable {
        /// A starter letter from the level.
        case given
        /// Typed by the player; the only kind they can change.
        case placed
        /// Filled in by the cat or grandma; always correct.
        case revealed
    }

    public struct Entry: Sendable, Equatable {
        public let letter: Character
        public let source: Source
    }

    public let level: Level
    public private(set) var entries: [Coordinate: Entry]
    public private(set) var selection: Coordinate
    public private(set) var direction: Direction
    /// Set once the board is submitted; the board is locked after that.
    public private(set) var result: LevelResult?

    public init(level: Level) {
        self.level = level
        var entries: [Coordinate: Entry] = [:]
        for cell in level.givens {
            entries[cell] = Entry(letter: level.letter(at: cell), source: .given)
        }
        self.entries = entries
        // Placeholders until `selectFirstEmptyCell` below, which needs `self`
        // to exist. A validated level always has letter cells.
        self.selection = level.letterCells[0]
        self.direction = .across
        self.result = nil
        selectFirstEmptyCell()
    }

    /// Selects the first cell without a letter (reading order), in a
    /// direction that has an answer. Used when a level opens, fresh or
    /// restored from a saved board.
    private mutating func selectFirstEmptyCell() {
        let start = level.letterCells.first(where: { entries[$0] == nil }) ?? level.letterCells[0]
        selection = start
        direction = level.answerID(at: start, direction: .across) != nil ? .across : .down
    }

    // MARK: - Reading the board

    public var isSubmitted: Bool { result != nil }

    public var filledCount: Int {
        level.letterCells.filter { entries[$0] != nil }.count
    }

    public var isBoardFull: Bool { filledCount == level.letterCells.count }

    /// Whether the player has typed any letter, i.e. whether clearing
    /// their letters would lose them anything.
    public var hasPlacedLetters: Bool {
        entries.values.contains { $0.source == .placed }
    }

    /// The answer the player is working on: the selected cell's answer in the
    /// current direction, or in the other direction if there's none this way.
    public var activeAnswerID: Int? {
        level.answerID(at: selection, direction: direction)
            ?? level.answerID(at: selection, direction: direction.other)
    }

    public var activeAnswer: Answer? {
        activeAnswerID.map { level.answers[$0] }
    }

    /// How many tiles of each letter are left in the tray.
    ///
    /// Derived from the board every time rather than stored. With one source
    /// of truth, placing, erasing and revealing can never drift out of sync
    /// with the tray. The bag is every non-starter answer letter, minus every
    /// non-starter letter on the board.
    public func remainingCounts() -> [Character: Int] {
        var counts: [Character: Int] = [:]
        for cell in level.letterCells where !level.givens.contains(cell) {
            counts[level.letter(at: cell), default: 0] += 1
            if let entry = entries[cell] {
                counts[entry.letter, default: 0] -= 1
            }
        }
        return counts
    }

    public func remaining(_ letter: Character) -> Int {
        remainingCounts()[letter] ?? 0
    }

    /// Whether a cell's letter is wrong. Only answered after submitting, so
    /// the score measures what the player knew, not what the app told them.
    public func isWrong(_ cell: Coordinate) -> Bool {
        guard isSubmitted, let entry = entries[cell] else { return false }
        return entry.letter != level.letter(at: cell)
    }

    // MARK: - Selecting

    /// Selects a letter cell. Tapping the selected cell again switches
    /// direction, but only if the cell has an answer that way.
    ///
    /// A new cell keeps the direction being typed, so tapping around a word
    /// stays in it, with one exception: the first letter of a word selects
    /// that word, whichever way it reads. Tapping where a word begins is
    /// almost always meant as "this word", like tapping its clue. Where an
    /// across and a down word both begin, the direction stays, since
    /// either could be meant (a second tap turns, as anywhere).
    public mutating func select(_ cell: Coordinate) {
        guard !isSubmitted, level.isLetterCell(cell) else { return }
        if cell == selection {
            if level.answerID(at: cell, direction: direction.other) != nil {
                direction = direction.other
            }
            return
        }
        selection = cell
        let startingHere = Direction.allCases.filter { way in
            level.answerID(at: cell, direction: way).map { level.answers[$0].cells.first == cell } ?? false
        }
        if startingHere.count == 1, let way = startingHere.first {
            direction = way
        } else if level.answerID(at: cell, direction: direction) == nil {
            direction = direction.other
        }
    }

    /// Jumps to an answer (tapping its clue):
    /// its first empty cell, or its first cell if it's full.
    public mutating func selectAnswer(_ answerID: Int) {
        guard !isSubmitted, level.answers.indices.contains(answerID) else { return }
        let answer = level.answers[answerID]
        selection = answer.cells.first(where: { entries[$0] == nil }) ?? answer.cells[0]
        direction = answer.direction
    }

    // MARK: - Editing

    /// Places a letter from the tray in the selected cell and moves on.
    /// Returns false when nothing changed: the cell isn't editable, no tile
    /// of that letter is left, or the board is submitted.
    @discardableResult
    public mutating func place(_ letter: Character) -> Bool {
        guard !isSubmitted, isEditable(selection) else { return false }
        // Take the old letter off first, so its tile is back in the tray
        // before checking whether the new letter is available.
        let previous = entries.removeValue(forKey: selection)
        guard remaining(letter) > 0 else {
            entries[selection] = previous
            return false
        }
        entries[selection] = Entry(letter: letter, source: .placed)
        moveToNextEmptyCell(after: selection)
        return true
    }

    /// Removes the player's letter from the selected cell. On a cell with
    /// nothing to erase it behaves like a keyboard's backspace: it steps back
    /// one cell in the answer and erases that cell's letter.
    @discardableResult
    public mutating func erase() -> Bool {
        guard !isSubmitted else { return false }
        if entries[selection]?.source == .placed {
            entries[selection] = nil
            return true
        }
        guard let answer = activeAnswer,
              let index = answer.cells.firstIndex(of: selection),
              index > 0
        else { return false }
        let previousCell = answer.cells[index - 1]
        selection = previousCell
        direction = answer.direction
        if entries[previousCell]?.source == .placed {
            entries[previousCell] = nil
        }
        return true
    }

    // MARK: - Helpers (cat and grandma)

    /// The cat: reveals one correct letter. Targets the selected cell if it
    /// needs help, otherwise the first cell of the active answer that does,
    /// otherwise the first such cell on the board. Returns the revealed cell,
    /// or nil when every letter is already correct.
    @discardableResult
    public mutating func revealLetter() -> Coordinate? {
        guard !isSubmitted else { return nil }
        let answerCells = activeAnswer?.cells ?? []
        let target: Coordinate?
        if needsHelp(selection) {
            target = selection
        } else {
            target = answerCells.first(where: { needsHelp($0) })
                ?? level.letterCells.first(where: { needsHelp($0) })
        }
        guard let target else { return nil }
        reveal(target)
        moveToNextEmptyCell(after: target)
        return target
    }

    /// Grandma: reveals every letter of the active answer that's empty or
    /// wrong. Returns the revealed cells (empty if the answer was already
    /// correct, so the caller knows not to charge for it).
    @discardableResult
    public mutating func revealActiveAnswer() -> [Coordinate] {
        guard !isSubmitted, let answer = activeAnswer else { return [] }
        let targets = answer.cells.filter { needsHelp($0) }
        // One cell at a time: each reveal may pull a misplaced copy off the
        // board, which changes what's available for the next cell.
        for cell in targets {
            reveal(cell)
        }
        if let lastCell = answer.cells.last {
            selection = lastCell
            direction = answer.direction
            moveToNextEmptyCell(after: lastCell)
        }
        return targets
    }

    // MARK: - Submitting

    /// Judges a full board. Returns nil if the board isn't full yet or was
    /// already submitted.
    @discardableResult
    public mutating func submit(rules: ScoringRules = .standard) -> LevelResult? {
        guard !isSubmitted, isBoardFull else { return nil }
        let judgedCells = level.letterCells.filter { entries[$0]?.source != .given }
        let correctCount = judgedCells.filter { entries[$0]?.letter == level.letter(at: $0) }.count
        let revealedCount = judgedCells.filter { entries[$0]?.source == .revealed }.count
        let outcome = LevelResult(
            correctLetters: correctCount,
            judgedLetters: judgedCells.count,
            revealedLetters: revealedCount,
            rules: rules
        )
        result = outcome
        return outcome
    }

    /// Starts the level over from its starter letters (used for "Try again").
    public mutating func restart() {
        self = PuzzleState(level: level)
    }

    /// Clears every letter the player typed, mid-level (Restart in the
    /// level's settings). Letters from the cat and grandma stay, unlike
    /// `restart()`: the player paid a hint for each, and taking them away
    /// would make them pay again for the same help.
    public mutating func clearPlacedLetters() {
        guard !isSubmitted else { return }
        entries = entries.filter { $0.value.source != .placed }
        selectFirstEmptyCell()
    }

    // MARK: - Private

    private func isEditable(_ cell: Coordinate) -> Bool {
        guard let entry = entries[cell] else { return true }
        return entry.source == .placed
    }

    /// A cell needs help when it's empty or holds a wrong letter the player placed.
    private func needsHelp(_ cell: Coordinate) -> Bool {
        guard let entry = entries[cell] else { return true }
        return entry.source == .placed && entry.letter != level.letter(at: cell)
    }

    /// Puts the correct letter in a cell.
    ///
    /// If no tile of that letter is left, every copy is already on the board.
    /// Since this cell still needs one, at least one copy must sit in a wrong
    /// cell: starter letters aren't in the tray, and revealed letters are
    /// always correct, so the wrong copy is one the player placed. That copy
    /// goes back: one cell becomes empty and this cell becomes correct.
    private mutating func reveal(_ cell: Coordinate) {
        let correct = level.letter(at: cell)
        entries[cell] = nil
        if remaining(correct) <= 0 {
            let misplacedCell = level.letterCells.first { other in
                guard let entry = entries[other] else { return false }
                return entry.source == .placed && entry.letter == correct && level.letter(at: other) != correct
            }
            if let misplacedCell {
                entries[misplacedCell] = nil
            } else {
                // Unreachable if the reasoning above holds. In debug builds
                // this stops at the bug; in release the letter is still placed
                // so the player isn't stuck.
                assertionFailure("No misplaced \(correct) to take back; tray counts are out of sync")
            }
        }
        entries[cell] = Entry(letter: correct, source: .revealed)
    }

    /// Moves to the next empty cell in the active answer after `cell`, or
    /// else to the nearest unfinished answer. Stays put when the board is full.
    ///
    /// "Nearest" is measured from `cell` to the first empty cell of each
    /// unfinished answer (where the selection would land), and ties go to
    /// the earlier answer in reading order so the choice is predictable.
    /// Reading order alone, used before, could send the player across the
    /// board on a big level that only shows part of it; the nearest answer
    /// is usually already in view, and often crosses the word just finished.
    private mutating func moveToNextEmptyCell(after cell: Coordinate) {
        guard let answerID = activeAnswerID else { return }
        let answer = level.answers[answerID]
        if let index = answer.cells.firstIndex(of: cell),
           let next = answer.cells[(index + 1)...].first(where: { entries[$0] == nil }) {
            selection = next
            direction = answer.direction
            return
        }
        let unfinished = level.answers.compactMap { candidate -> (answer: Answer, empty: Coordinate)? in
            candidate.cells.first(where: { entries[$0] == nil }).map { (candidate, $0) }
        }
        // min(by:) keeps the first of equal elements, which is the tie rule.
        guard let nearest = unfinished.min(by: { squaredDistance(cell, $0.empty) < squaredDistance(cell, $1.empty) })
        else { return }
        selection = nearest.empty
        direction = nearest.answer.direction
    }

    /// Squared straight-line distance in cells; squaring keeps it in whole
    /// numbers and doesn't change which is nearer.
    private func squaredDistance(_ first: Coordinate, _ second: Coordinate) -> Int {
        let rows = first.row - second.row
        let columns = first.column - second.column
        return rows * rows + columns * columns
    }
}

// MARK: - Saving a level left halfway

extension PuzzleState {
    /// The board to save, or nil when there's nothing worth keeping: no
    /// letters added yet, or the level already judged.
    public func savedBoard() -> SavedBoard? {
        guard !isSubmitted else { return nil }
        let letters = level.letterCells.compactMap { cell -> SavedBoard.Letter? in
            guard let entry = entries[cell], entry.source != .given else { return nil }
            return SavedBoard.Letter(
                row: cell.row, column: cell.column,
                letter: String(entry.letter), revealed: entry.source == .revealed
            )
        }
        guard !letters.isEmpty else { return nil }
        return SavedBoard(levelID: level.id, levelFingerprint: level.fingerprint, letters: letters)
    }

    /// The level with a saved board put back, or nil if the board doesn't fit
    /// this level. The caller then starts the level fresh.
    ///
    /// A save file can be stale (the pack was regenerated) or damaged, so
    /// every letter is checked rather than trusted: right level, a letter
    /// cell that isn't a starter, no cell twice, revealed letters correct,
    /// and never more of a letter than the tray holds.
    public static func restored(level: Level, from saved: SavedBoard) -> PuzzleState? {
        guard saved.levelID == level.id, saved.levelFingerprint == level.fingerprint else { return nil }

        var state = PuzzleState(level: level)
        for item in saved.letters {
            let cell = Coordinate(row: item.row, column: item.column)
            guard item.letter.count == 1, let letter = item.letter.first,
                  level.isLetterCell(cell),
                  !level.givens.contains(cell),
                  state.entries[cell] == nil
            else { return nil }
            if item.revealed, letter != level.letter(at: cell) { return nil }
            state.entries[cell] = Entry(letter: letter, source: item.revealed ? .revealed : .placed)
        }
        // A letter the tray never had (or too many of one) leaves a count
        // below zero; the board can't have been made by playing this level.
        guard state.remainingCounts().values.allSatisfy({ $0 >= 0 }) else { return nil }

        state.selectFirstEmptyCell()
        return state
    }
}
