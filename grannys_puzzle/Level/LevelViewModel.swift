import Foundation
import Observation
import ArrowwordCore

/// Connects the level screen to the game rules.
///
/// Responsibilities are split three ways:
/// - `PuzzleState` (in ArrowwordCore) knows what each action does to the board.
/// - This view model decides whether an action is allowed right now (does the
///   player have a hint?), calls the puzzle, and holds short-lived UI state
///   such as the cat animation and grandma's speech bubble.
/// - The views only read these properties and call these methods. They
///   contain no game rules, so they stay simple.
@Observable
final class LevelViewModel {
    enum Phase {
        case playing
        case readyToSubmit
        case finished(LevelResult)
    }

    let levelNumber: Int
    private(set) var puzzle: PuzzleState

    // A temporary in-memory wallet. The progression phase moves it into the
    // saved player profile so it carries across levels and app launches.
    private(set) var hints: Int
    private(set) var grandmas: Int

    /// The cell where the cat's head shows for a moment after a hint.
    private(set) var catCell: Coordinate?
    /// Grandma's speech bubble while it's on screen.
    private(set) var grandmaLine: String?

    // Internal bookkeeping the views never read, so SwiftUI needn't watch it.
    @ObservationIgnored private let scoringRules: ScoringRules
    /// Palette index per answer, worked out once per level.
    @ObservationIgnored private let clueColorIndices: [Int]
    @ObservationIgnored private var catTask: Task<Void, Never>?
    @ObservationIgnored private var grandmaTask: Task<Void, Never>?

    init(
        level: Level,
        levelNumber: Int,
        hints: Int = 4,
        grandmas: Int = 1,
        scoringRules: ScoringRules = .standard
    ) {
        self.levelNumber = levelNumber
        self.puzzle = PuzzleState(level: level)
        self.hints = hints
        self.grandmas = grandmas
        self.scoringRules = scoringRules
        self.clueColorIndices = ClueColors.assignments(for: level)
    }

    // MARK: - What the screen shows

    var level: Level { puzzle.level }

    var phase: Phase {
        if let result = puzzle.result { return .finished(result) }
        return puzzle.isBoardFull ? .readyToSubmit : .playing
    }

    /// The answer being worked on; none once the level is judged.
    var activeAnswer: Answer? {
        puzzle.isSubmitted ? nil : puzzle.activeAnswer
    }

    var progressText: String {
        "\(puzzle.filledCount)/\(level.letterCells.count)"
    }

    var progressFraction: Double {
        Double(puzzle.filledCount) / Double(level.letterCells.count)
    }

    var trayKeys: [TrayKey] {
        let counts = puzzle.remainingCounts()
        return level.trayLetters.map { letter in
            TrayKey(letter: letter, remaining: max(0, counts[letter] ?? 0))
        }
    }

    var canUseCat: Bool { hints > 0 }
    var canUseGrandma: Bool { grandmas > 0 }

    /// The palette index of an answer's colour.
    func colorIndex(ofAnswer answerID: Int) -> Int {
        clueColorIndices[answerID]
    }

    func clues(atClueCell cell: Coordinate) -> [ClueAppearance] {
        let activeID = activeAnswer?.id
        return level.answerIDs(atClueCell: cell).map { id in
            let answer = level.answers[id]
            return ClueAppearance(
                answerID: id,
                text: answer.clueText,
                arrow: answer.arrow,
                colorIndex: colorIndex(ofAnswer: id),
                isActive: id == activeID
            )
        }
    }

    func appearance(of cell: Coordinate) -> LetterCellAppearance {
        let entry = puzzle.entries[cell]
        let style: LetterCellAppearance.Style
        if puzzle.isWrong(cell) {
            style = .wrong
        } else if let answer = activeAnswer, let strength = highlightStrength(of: cell, in: answer) {
            style = .highlighted(colorIndex: colorIndex(ofAnswer: answer.id), strength: strength)
        } else {
            style = .normal
        }
        return LetterCellAppearance(
            letter: entry?.letter,
            style: style,
            isSelected: !puzzle.isSubmitted && cell == puzzle.selection,
            isRevealed: entry?.source == .revealed,
            showsCat: cell == catCell
        )
    }

    /// How strongly a cell of the active answer shows its colour: full on the
    /// selected cell, fading toward the end of the word, and the lowest step
    /// for cells already behind the cursor. Nil for cells outside the answer.
    private func highlightStrength(of cell: Coordinate, in answer: Answer) -> Double? {
        guard let cellIndex = answer.cells.firstIndex(of: cell),
              let selectedIndex = answer.cells.firstIndex(of: puzzle.selection)
        else { return nil }
        let steps = ClueColors.fadeSteps
        let distance = cellIndex - selectedIndex
        guard distance >= 0 else { return steps.last }
        return steps[min(distance, steps.count - 1)]
    }

    // MARK: - Player actions

    func tapCell(_ cell: Coordinate) {
        puzzle.select(cell)
    }

    func tapClue(answerID: Int) {
        puzzle.selectAnswer(answerID)
    }

    func showNextClue() {
        puzzle.selectNextAnswer()
    }

    func showPreviousClue() {
        puzzle.selectPreviousAnswer()
    }

    func type(_ letter: Character) {
        puzzle.place(letter)
    }

    func erase() {
        puzzle.erase()
    }

    /// The cat reveals one letter. The hint is only charged if a letter was
    /// actually revealed: that's why `revealLetter()` returns nil when
    /// there's nothing to fix.
    func useCat() {
        guard hints > 0, let cell = puzzle.revealLetter() else { return }
        hints -= 1
        showCat(at: cell)
    }

    /// Grandma solves the selected word, charged only if she changed something.
    func useGrandma() {
        guard grandmas > 0, let answer = puzzle.activeAnswer else { return }
        let revealed = puzzle.revealActiveAnswer()
        guard !revealed.isEmpty else { return }
        grandmas -= 1
        say(GrandmaLines.solved(answer.solution))
    }

    func submit() {
        puzzle.submit(rules: scoringRules)
    }

    /// After the result: a pass goes to the next level, a fail starts over.
    /// Only one level is bundled so far, so both replay it; the level list
    /// arrives with the home screen.
    func continueAfterResult() {
        puzzle.restart()
    }

    // MARK: - Short-lived UI state

    private func showCat(at cell: Coordinate) {
        catTask?.cancel()
        catCell = cell
        catTask = Task { [weak self] in
            // Sleep throws only when cancelled; a newer cat animation then
            // owns `catCell`, so this one must not clear it.
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            self?.catCell = nil
        }
    }

    private func say(_ line: String) {
        grandmaTask?.cancel()
        grandmaLine = line
        grandmaTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            self?.grandmaLine = nil
        }
    }
}

// MARK: - Display values

/// One key in the letter tray.
struct TrayKey: Identifiable, Equatable {
    let letter: Character
    let remaining: Int

    var id: Character { letter }
    var isUsedUp: Bool { remaining == 0 }
}

/// Everything a letter cell needs to draw itself.
struct LetterCellAppearance: Equatable {
    enum Style: Equatable {
        case normal
        /// Part of the active answer, in its clue's colour at this strength.
        case highlighted(colorIndex: Int, strength: Double)
        case wrong
    }

    let letter: Character?
    let style: Style
    let isSelected: Bool
    let isRevealed: Bool
    let showsCat: Bool
}

/// One clue inside a clue cell.
struct ClueAppearance: Identifiable, Equatable {
    let answerID: Int
    let text: String
    let arrow: ClueArrow
    let colorIndex: Int
    let isActive: Bool

    var id: Int { answerID }
}

/// Grandma's lines. They move into a data file (with Turkish versions and
/// triggers) when the home screen and mascot are built.
enum GrandmaLines {
    private static let solvedTemplates = [
        "Ah, that one's %@, dear.",
        "%@! I knew it before my tea went cold.",
        "Let me see… %@. Easy as purl.",
        "It's %@, sweetheart. Keep going!",
    ]

    static func solved(_ word: String) -> String {
        let template = solvedTemplates.randomElement() ?? "%@"
        return String(format: template, word)
    }
}
