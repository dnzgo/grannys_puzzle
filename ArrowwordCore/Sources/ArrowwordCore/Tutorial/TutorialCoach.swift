/// What grandma is saying at a tutorial step. The app turns each one into
/// her words (and translations); the rules here only need to know which.
public enum TutorialLine: String, Sendable, CaseIterable {
    case zoomOut
    case zoomIn
    case clueBox
    case typeWord
    case switchDirection
    case catHelps
    case askGrandma
    case submit
}

/// The one thing the player should act on during a tutorial step.
public enum TutorialTarget: Hashable, Sendable {
    /// The board, pinched to see all of it.
    case zoomOut
    /// The board, pinched to look closer.
    case zoomIn
    /// The clue of an answer (by `Answer.id`).
    case clue(answerID: Int)
    /// A letter cell on the board, tapped until it switches direction.
    case cell(Coordinate)
    /// A letter key in the tray.
    case key(Character)
    case cat
    case grandma
    case submit
}

/// What the player did, as the tutorial sees it. Actions with no case here
/// (erasing, Restart) are never part of a lesson, so they're simply not
/// allowed while it runs.
public enum TutorialAction: Equatable, Sendable {
    /// Tapped the Next button under grandma's words.
    case next
    /// A pinch ended showing the whole board.
    case zoomOut
    /// A pinch ended close enough to read.
    case zoomIn
    case selectClue(answerID: Int)
    case selectCell(Coordinate)
    case type(Character)
    case useCat
    case useGrandma
    case submit
}

/// The lesson as a list of steps, written against answer *words* rather
/// than answer ids, so the script reads like the lesson ("fill CAT") and
/// doesn't silently break if the board's answers are renumbered.
public struct TutorialScript: Sendable {
    public enum Goal: Equatable, Sendable {
        /// Grandma explains and the player taps Next. If a word is given, its
        /// clue and cells are lit up while she talks about them.
        case read(pointingAt: String?)
        /// Pinch the board out to see all of it, then back in. The board
        /// itself says when a pinch counts (the rules here know nothing of
        /// zoom levels); these only wait for it.
        case zoomOut
        case zoomIn
        /// Tap the clue of this word.
        case selectClue(of: String)
        /// Type this word's missing letters, guided key by key.
        case fill(String)
        /// Tap the square the two words share until the second one is
        /// selected: once to select it, once more to turn. The lessons
        /// use an empty square, so the cat then fills the one selected.
        case switchDirection(from: String, to: String)
        case useCat
        case useGrandma
        case submit
    }

    public struct Step: Equatable, Sendable {
        public let line: TutorialLine
        public let goal: Goal

        public init(_ line: TutorialLine, _ goal: Goal) {
            self.line = line
            self.goal = goal
        }
    }

    public let steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    /// The lesson for a language, or nil if there's none for it.
    public static func standard(for language: String) -> TutorialScript? {
        switch language {
        case "en": english
        case "tr": turkish
        default: nil
        }
    }

    /// For grannys_puzzle/Levels/tutorial-en.json. A test plays each script
    /// on its file, so a change to either that breaks the other fails there.
    public static let english = lesson(typed: "TEA", turningFrom: "GIRL", into: "BITE")

    /// For tutorial-tr.json, the same steps on its own board.
    public static let turkish = lesson(typed: "OYA", turningFrom: "ŞAPKA", into: "HIRKA")

    /// Every language's lesson has the same steps, so only the words the
    /// steps point at differ. The board does the rest: its starter letters
    /// leave exactly the gaps the steps fill, and its shape decides where
    /// the selection lands after each one (the tests check both).
    ///
    /// - Parameters:
    ///   - typed: the word the player types; it reads across.
    ///   - turningFrom, into: an across and a down word sharing the one
    ///     empty square left after typing. The player taps it twice to turn
    ///     from the first to the second, and the cat fills it, the selected
    ///     square. The selection then moves on by itself to the last
    ///     unfinished word, which grandma solves.
    private static func lesson(typed: String, turningFrom across: String, into down: String) -> TutorialScript {
        TutorialScript(steps: [
            Step(.zoomOut, .zoomOut),
            Step(.zoomIn, .zoomIn),
            Step(.clueBox, .selectClue(of: typed)),
            Step(.typeWord, .fill(typed)),
            Step(.switchDirection, .switchDirection(from: across, to: down)),
            Step(.catHelps, .useCat),
            Step(.askGrandma, .useGrandma),
            Step(.submit, .submit),
        ])
    }
}

/// Runs a tutorial script: which step the player is on, what they may do,
/// and what to point at.
///
/// It's a plain value with no UI, like `PuzzleState`, and it never changes
/// the board itself. The level's view model asks `allows` before every
/// action, performs it on the puzzle as usual, then reports it with
/// `didPerform`. Keeping the "may I?" and "what happened" questions here
/// means the lesson's rules can be tested by playing it, without a screen.
public struct TutorialCoach: Sendable {
    /// A script step with its words looked up on the board.
    private enum Goal: Equatable, Sendable {
        case read(answerID: Int?)
        case zoomOut
        case zoomIn
        case selectClue(answerID: Int)
        case fill(answerID: Int)
        /// Turn at `cell` into `answerID`.
        case switchDirection(cell: Coordinate, answerID: Int)
        case useCat
        case useGrandma
        case submit
    }

    private struct Step: Sendable {
        let line: TutorialLine
        let goal: Goal
    }

    private let level: Level
    private let steps: [Step]
    /// The step the player is on; equal to `steps.count` once it's finished.
    public private(set) var stepIndex = 0

    /// Fails (nil) if the script names a word the board doesn't have, or one
    /// it has twice, or asks to switch between words that don't cross:
    /// either way the lesson couldn't point at the right thing.
    public init?(script: TutorialScript, level: Level) {
        func answerID(of word: String) -> Int? {
            let matches = level.answers.filter { $0.solution == word }
            return matches.count == 1 ? matches[0].id : nil
        }

        var steps: [Step] = []
        for step in script.steps {
            let goal: Goal
            switch step.goal {
            case .read(pointingAt: .none):
                goal = .read(answerID: nil)
            case .read(pointingAt: let word?):
                guard let id = answerID(of: word) else { return nil }
                goal = .read(answerID: id)
            case .zoomOut: goal = .zoomOut
            case .zoomIn: goal = .zoomIn
            case .selectClue(of: let word):
                guard let id = answerID(of: word) else { return nil }
                goal = .selectClue(answerID: id)
            case .fill(let word):
                guard let id = answerID(of: word) else { return nil }
                goal = .fill(answerID: id)
            case .switchDirection(from: let first, to: let second):
                guard let firstID = answerID(of: first), let secondID = answerID(of: second) else { return nil }
                // Two words cross in one cell at most, since each reads in a
                // straight line; none means they don't cross at all.
                let shared = Set(level.answers[firstID].cells).intersection(level.answers[secondID].cells)
                guard let cell = shared.first else { return nil }
                goal = .switchDirection(cell: cell, answerID: secondID)
            case .useCat: goal = .useCat
            case .useGrandma: goal = .useGrandma
            case .submit: goal = .submit
            }
            steps.append(Step(line: step.line, goal: goal))
        }
        self.level = level
        self.steps = steps
    }

    // MARK: - Where the lesson is

    public var isFinished: Bool { stepIndex >= steps.count }

    private var currentGoal: Goal? {
        isFinished ? nil : steps[stepIndex].goal
    }

    /// What grandma is saying now; nil once the lesson is over.
    public var line: TutorialLine? {
        isFinished ? nil : steps[stepIndex].line
    }

    /// Whether this step ends with the Next button (grandma is explaining).
    public var waitsForNext: Bool {
        if case .read = currentGoal { return true }
        return false
    }

    /// What the player should act on now, or nil while grandma is explaining.
    public func target(on puzzle: PuzzleState) -> TutorialTarget? {
        switch currentGoal {
        case .zoomOut: return .zoomOut
        case .zoomIn: return .zoomIn
        case .selectClue(let id): return .clue(answerID: id)
        case .fill(let id): return expectedLetter(for: id, on: puzzle).map(TutorialTarget.key)
        case .switchDirection(let cell, _): return .cell(cell)
        case .useCat: return .cat
        case .useGrandma: return .grandma
        case .submit: return .submit
        case .read, nil: return nil
        }
    }

    /// The answer whose clue and cells stay lit during this step, so the
    /// player sees the letters land: the word being explained or filled,
    /// the word about to be switched to, or the word the cat or grandma is
    /// about to help with.
    public func litAnswerID(on puzzle: PuzzleState) -> Int? {
        switch currentGoal {
        case .read(let id): return id
        case .fill(let id): return id
        case .switchDirection(_, let id): return id
        case .useCat, .useGrandma: return puzzle.activeAnswerID
        case .zoomOut, .zoomIn, .selectClue, .submit, nil: return nil
        }
    }

    // MARK: - Following along

    /// Whether the player may do this now. Anything outside the current
    /// step's goal is refused, so the lesson can't be wandered off from;
    /// the Skip button is the way out.
    public func allows(_ action: TutorialAction, on puzzle: PuzzleState) -> Bool {
        switch (currentGoal, action) {
        case (.read, .next): return true
        case (.zoomOut, .zoomOut), (.zoomIn, .zoomIn): return true
        case (.selectClue(let id), .selectClue(let tapped)): return tapped == id
        case (.fill(let id), .type(let letter)): return letter == expectedLetter(for: id, on: puzzle)
        case (.switchDirection(let cell, _), .selectCell(let tapped)): return tapped == cell
        case (.useCat, .useCat), (.useGrandma, .useGrandma), (.submit, .submit): return true
        default: return false
        }
    }

    /// Moves the lesson on after the view model has performed an allowed
    /// action on the puzzle. `puzzle` is the board *after* the action.
    public mutating func didPerform(_ action: TutorialAction, on puzzle: PuzzleState) {
        guard let goal = currentGoal, isComplete(goal, after: action, on: puzzle) else { return }
        stepIndex += 1
        // A step can already be done when it starts: say the cat happened to
        // reveal the last missing letter of the word the next step asks for.
        // Waiting on it would leave the player with nothing they're allowed
        // to tap, so steps that are already true are passed over.
        while let next = currentGoal, isAlreadyDone(next, on: puzzle) {
            stepIndex += 1
        }
    }

    // MARK: - Private

    private func isComplete(_ goal: Goal, after action: TutorialAction, on puzzle: PuzzleState) -> Bool {
        switch goal {
        case .read: return action == .next
        case .zoomOut: return action == .zoomOut
        case .zoomIn: return action == .zoomIn
        case .useCat: return action == .useCat
        case .useGrandma: return action == .useGrandma
        case .selectClue, .fill, .switchDirection, .submit: return isAlreadyDone(goal, on: puzzle)
        }
    }

    /// Goals that are a fact about the board, rather than an action taken.
    private func isAlreadyDone(_ goal: Goal, on puzzle: PuzzleState) -> Bool {
        switch goal {
        case .selectClue(let id): return puzzle.activeAnswerID == id
        case .fill(let id): return level.answers[id].cells.allSatisfy { isCorrect($0, on: puzzle) }
        // The square selected, reading the new way: the first tap only
        // selects it (in the direction already being typed), the second turns.
        case .switchDirection(let cell, let id): return puzzle.selection == cell && puzzle.activeAnswerID == id
        case .submit: return puzzle.isSubmitted
        case .read, .zoomOut, .zoomIn, .useCat, .useGrandma: return false
        }
    }

    /// The letter for the selected cell, if that cell is an unfinished part
    /// of the word being filled. The puzzle moves the selection along the
    /// word after each letter, so following this spells the word in order.
    private func expectedLetter(for answerID: Int, on puzzle: PuzzleState) -> Character? {
        let cell = puzzle.selection
        guard level.answers[answerID].cells.contains(cell), !isCorrect(cell, on: puzzle) else { return nil }
        return level.solution(at: cell)
    }

    private func isCorrect(_ cell: Coordinate, on puzzle: PuzzleState) -> Bool {
        puzzle.entries[cell]?.letter == level.solution(at: cell)
    }
}
