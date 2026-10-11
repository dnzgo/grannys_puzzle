/// What grandma is saying at a tutorial step. The app turns each one into
/// her words (and translations); the rules here only need to know which.
public enum TutorialLine: String, Sendable, CaseIterable {
    case welcome
    case clueBox
    case typeWord
    case tapClue
    case catHelps
    case finishWord
    case askGrandma
    case submit
}

/// The one thing the player can tap during a tutorial step.
public enum TutorialTarget: Hashable, Sendable {
    /// The clue of an answer (by `Answer.id`).
    case clue(answerID: Int)
    /// A letter key in the tray.
    case key(Character)
    case cat
    case grandma
    case submit
}

/// What the player did, as the tutorial sees it. Actions with no case here
/// (tapping a cell, erasing, the clue bar's arrows) are never part of a
/// lesson, so they're simply not allowed while it runs.
public enum TutorialAction: Equatable, Sendable {
    /// Tapped the Next button under grandma's words.
    case next
    case selectClue(answerID: Int)
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
        /// Tap the clue of this word.
        case selectClue(of: String)
        /// Type this word's missing letters, guided key by key.
        case fill(String)
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

    /// For grannys_puzzle/Levels/tutorial-en.json: CAT across, TEA down
    /// from CAT's T, and HAT across through TEA's A. A test plays each script
    /// on its file, so a change to either that breaks the other fails there.
    public static let english = lesson(first: "CAT", second: "TEA")

    /// For tutorial-tr.json, the same shape: ÇAY across, YÜN down from
    /// ÇAY's Y, and ANA across through YÜN's N.
    public static let turkish = lesson(first: "ÇAY", second: "YÜN")

    /// Every language's lesson has the same steps on the same board shape,
    /// so only the two words the steps point at differ. (The third word is
    /// the one grandma solves; the selection moves onto it by itself.)
    private static func lesson(first: String, second: String) -> TutorialScript {
        TutorialScript(steps: [
            Step(.welcome, .read(pointingAt: nil)),
            Step(.clueBox, .read(pointingAt: first)),
            Step(.typeWord, .fill(first)),
            Step(.tapClue, .selectClue(of: second)),
            // The second word's first letter is already there from the
            // first word: the cat reveals the next one, ...
            Step(.catHelps, .useCat),
            // ... the player types the last, ...
            Step(.finishWord, .fill(second)),
            // ... and the selection has moved on to the third word, which
            // grandma solves.
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
        case selectClue(answerID: Int)
        case fill(answerID: Int)
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
    /// it has twice: either way the lesson couldn't point at the right thing.
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
            case .selectClue(of: let word):
                guard let id = answerID(of: word) else { return nil }
                goal = .selectClue(answerID: id)
            case .fill(let word):
                guard let id = answerID(of: word) else { return nil }
                goal = .fill(answerID: id)
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

    /// What the player should tap now, or nil while grandma is explaining.
    public func target(on puzzle: PuzzleState) -> TutorialTarget? {
        switch currentGoal {
        case .selectClue(let id): return .clue(answerID: id)
        case .fill(let id): return expectedLetter(for: id, on: puzzle).map(TutorialTarget.key)
        case .useCat: return .cat
        case .useGrandma: return .grandma
        case .submit: return .submit
        case .read, nil: return nil
        }
    }

    /// The answer whose clue and cells stay lit during this step, so the
    /// player sees the letters land: the word being explained or filled, or
    /// the word the cat or grandma is about to help with.
    public func litAnswerID(on puzzle: PuzzleState) -> Int? {
        switch currentGoal {
        case .read(let id): return id
        case .fill(let id): return id
        case .useCat, .useGrandma: return puzzle.activeAnswerID
        case .selectClue, .submit, nil: return nil
        }
    }

    // MARK: - Following along

    /// Whether the player may do this now. Anything outside the current
    /// step's goal is refused, so the lesson can't be wandered off from;
    /// the Skip button is the way out.
    public func allows(_ action: TutorialAction, on puzzle: PuzzleState) -> Bool {
        switch (currentGoal, action) {
        case (.read, .next): return true
        case (.selectClue(let id), .selectClue(let tapped)): return tapped == id
        case (.fill(let id), .type(let letter)): return letter == expectedLetter(for: id, on: puzzle)
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
        case .useCat: return action == .useCat
        case .useGrandma: return action == .useGrandma
        case .selectClue, .fill, .submit: return isAlreadyDone(goal, on: puzzle)
        }
    }

    /// Goals that are a fact about the board, rather than an action taken.
    private func isAlreadyDone(_ goal: Goal, on puzzle: PuzzleState) -> Bool {
        switch goal {
        case .selectClue(let id): return puzzle.activeAnswerID == id
        case .fill(let id): return level.answers[id].cells.allSatisfy { isCorrect($0, on: puzzle) }
        case .submit: return puzzle.isSubmitted
        case .read, .useCat, .useGrandma: return false
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
