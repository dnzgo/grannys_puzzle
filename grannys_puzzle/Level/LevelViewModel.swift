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
/// - The `LevelHost` (the `Game`) owns the player's saved helpers and yarn,
///   and decides where to go after the level.
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
    /// Grandma's lesson, when this level is the tutorial; nil for real levels.
    private(set) var coach: TutorialCoach?
    /// The yarn balls this level earned, shown on the result panel.
    private(set) var earnedYarn: [YarnColor] = []

    /// The cell where the cat's head shows for a moment after a hint.
    private(set) var catCell: Coordinate?
    /// The latest haptic to play; the level screen turns it into a vibration.
    private(set) var haptic: HapticSignal?
    let speech = GrandmaSpeech()

    // Internal bookkeeping the views never read, so SwiftUI needn't watch it.
    @ObservationIgnored private let scoringRules: ScoringRules
    /// Palette index per answer, worked out once per level.
    @ObservationIgnored private let clueColorIndices: [Int]
    @ObservationIgnored private var catTask: Task<Void, Never>?
    @ObservationIgnored private var hapticCount = 0
    /// Weak because the host (the Game) owns this view model through its
    /// current screen; a strong reference back would be a retain cycle.
    @ObservationIgnored private weak var host: LevelHost?

    /// - Parameters:
    ///   - puzzle: the board to start from: fresh, or restored from a save
    ///     when the player left this level halfway.
    ///   - coach: set for the tutorial. It decides which actions are allowed;
    ///     the host (a `TutorialHost`) decides what they cost.
    init(
        puzzle: PuzzleState,
        levelNumber: Int,
        host: LevelHost?,
        coach: TutorialCoach? = nil,
        scoringRules: ScoringRules = .standard
    ) {
        self.levelNumber = levelNumber
        self.puzzle = puzzle
        self.coach = coach
        self.host = host
        self.scoringRules = scoringRules
        self.clueColorIndices = ClueColors.assignments(for: puzzle.level)
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

    var hints: Int { host?.hints ?? 0 }
    var grandmas: Int { host?.grandmas ?? 0 }

    /// Out of cat hints, but more can be earned by watching a short ad.
    var catOffersAd: Bool { hints == 0 && canWatchAd }
    var grandmaOffersAd: Bool { grandmas == 0 && canWatchAd }
    var canUseCat: Bool { !isWatchingAd && (hints > 0 || catOffersAd) }
    var canUseGrandma: Bool { !isWatchingAd && (grandmas > 0 || grandmaOffersAd) }

    /// The "watch a video, pick a treat" card is up.
    private(set) var isOfferingAd = false
    /// True while a rewarded ad is on screen, so a second tap can't start
    /// another one.
    private(set) var isWatchingAd = false

    private var canWatchAd: Bool { host?.canWatchAdForHelper ?? false }

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
    //
    // During the lesson every action first asks the coach, and reports back
    // after it's done. Actions the lesson never uses (tapping a cell,
    // erasing, the clue bar's arrows) are simply off until it's over.

    func tapCell(_ cell: Coordinate) {
        guard !isCoaching else { return }
        puzzle.select(cell)
        feel(.select)
    }

    func tapClue(answerID: Int) {
        let action = TutorialAction.selectClue(answerID: answerID)
        guard coachAllows(action) else { return }
        puzzle.selectAnswer(answerID)
        feel(.select)
        coachSaw(action)
    }

    func showNextClue() {
        guard !isCoaching else { return }
        puzzle.selectNextAnswer()
        feel(.select)
    }

    func showPreviousClue() {
        guard !isCoaching else { return }
        puzzle.selectPreviousAnswer()
        feel(.select)
    }

    func type(_ letter: Character) {
        guard coachAllows(.type(letter)) else { return }
        // Only a letter that actually landed clicks; a refused one stays silent.
        if puzzle.place(letter) {
            feel(.letterPlaced)
            boardChanged()
            coachSaw(.type(letter))
        }
    }

    func erase() {
        guard !isCoaching else { return }
        if puzzle.erase() {
            feel(.letterErased)
            boardChanged()
        }
    }

    /// The cat reveals one letter. The hint is only charged if a letter was
    /// actually revealed: that's why `revealLetter()` returns nil when
    /// there's nothing to fix.
    func useCat() {
        if hints == 0 {
            offerAd()
            return
        }
        guard coachAllows(.useCat), let cell = puzzle.revealLetter() else { return }
        _ = host?.spendHint()
        showCat(at: cell)
        feel(.reveal)
        boardChanged()
        coachSaw(.useCat)
    }

    /// Grandma solves the selected word, charged only if she changed something.
    func useGrandma() {
        if grandmas == 0 {
            offerAd()
            return
        }
        guard coachAllows(.useGrandma), let answer = puzzle.activeAnswer else { return }
        let revealed = puzzle.revealActiveAnswer()
        guard !revealed.isEmpty else { return }
        _ = host?.spendGrandma()
        // In the lesson grandma is already talking in her card; a second
        // bubble would compete with it.
        if !isTutorial {
            speech.say(GrandmaLines.solved(answer.solution))
        }
        feel(.reveal)
        boardChanged()
        coachSaw(.useGrandma)
    }

    func submit() {
        guard coachAllows(.submit) else { return }
        // `submit` returns nil if the board was already judged. Using its
        // return value (not `puzzle.result`) makes a double tap on Submit
        // record the level once, not award yarn twice and skip a level.
        guard let result = puzzle.submit(rules: scoringRules) else { return }
        earnedYarn = host?.record(result) ?? []
        feel(result.passed ? .levelPassed : .levelFailed)
        coachSaw(.submit)
    }

    /// After the result: a pass moves on (the host decides where), a fail
    /// starts this level over with a cleared board.
    func continueAfterResult() {
        guard let result = puzzle.result else { return }
        if result.passed {
            host?.continueToNextLevel()
        } else {
            earnedYarn = []
            puzzle.restart()
        }
    }

    /// Back to the home screen. The board is already saved (every letter
    /// change saves it), so coming back picks up where the player left off.
    func goHome() {
        host?.goHome()
    }

    // MARK: - Helpers from ads

    /// Out of a helper: offers a video, with a choice of reward (three cats
    /// or one grandma) whichever button was tapped. The reward goes to the
    /// player's helpers rather than being used at once, so they decide when
    /// and where to spend it.
    private func offerAd() {
        guard !isWatchingAd, !isCoaching, canWatchAd else { return }
        isOfferingAd = true
    }

    /// How many helpers a video gives for this choice (the offer card shows it).
    func adRewardAmount(_ reward: HelperAdReward) -> Int {
        host?.amount(of: reward) ?? 0
    }

    func cancelAdOffer() {
        isOfferingAd = false
    }

    func watchAd(for reward: HelperAdReward) {
        guard isOfferingAd, !isWatchingAd else { return }
        isOfferingAd = false
        isWatchingAd = true
        Task { [weak self] in
            guard let self else { return }
            let earned = await self.host?.watchAd(for: reward) ?? false
            self.isWatchingAd = false
            guard earned else { return }
            self.feel(.helperEarned)
            self.speech.say(GrandmaLines.adReward(reward, amount: self.adRewardAmount(reward)))
        }
    }

    // MARK: - Tutorial

    var isTutorial: Bool { coach != nil }

    /// What grandma is saying; nil outside the lesson and once it's over
    /// (the result screen is the normal one).
    var tutorialLine: TutorialLine? { coach?.line }

    /// Whether her card shows a Next button (she's explaining).
    var tutorialWaitsForNext: Bool { coach?.waitsForNext ?? false }

    /// The one thing the player can tap now.
    var tutorialTarget: TutorialTarget? { coach?.target(on: puzzle) }

    /// The cells to keep lit (not dimmed) so the player sees letters land.
    var tutorialLitCells: [Coordinate] {
        guard let id = coach?.litAnswerID(on: puzzle) else { return [] }
        return level.answers[id].cells
    }

    /// The clue to keep lit with those cells.
    var tutorialLitClue: TutorialTarget? {
        coach?.litAnswerID(on: puzzle).map { TutorialTarget.clue(answerID: $0) }
    }

    func tutorialNext() {
        guard coachAllows(.next) else { return }
        coachSaw(.next)
    }

    /// Leaves the lesson. The tutorial's host marks it done and goes home.
    func skipTutorial() {
        host?.goHome()
    }

    /// True while the lesson is running (not before or after).
    private var isCoaching: Bool {
        coach.map { !$0.isFinished } ?? false
    }

    /// Always true on a real level; in the lesson, only for its current step.
    private func coachAllows(_ action: TutorialAction) -> Bool {
        guard isCoaching, let coach else { return true }
        return coach.allows(action, on: puzzle)
    }

    /// Tells the lesson what just happened, with the board as it is now.
    private func coachSaw(_ action: TutorialAction) {
        guard isCoaching else { return }
        coach?.didPerform(action, on: puzzle)
    }

    // MARK: - Short-lived UI state

    /// Hands the board to the host to keep. Only letter changes call this:
    /// moving the selection around isn't worth a save.
    private func boardChanged() {
        host?.saveBoard(puzzle.savedBoard())
    }

    private func feel(_ event: HapticEvent) {
        hapticCount += 1
        haptic = HapticSignal(event: event, id: hapticCount)
    }

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
