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
    /// When the daily puzzle's clock started; nil on other levels. The top
    /// bar counts up from here.
    let dailyStartedAt: Date?
    private(set) var puzzle: PuzzleState
    /// Grandma's lesson, when this level is the tutorial; nil for real levels.
    private(set) var coach: TutorialCoach?
    /// The yarn balls this level earned, shown on the result panel.
    private(set) var earnedYarn: [YarnColor] = []
    /// An item this level's yarn made affordable for the first time;
    /// grandma mentions it in the celebration.
    private(set) var newlyKnittable: KnitItem?
    /// The celebration has played through (or was tapped past), so the
    /// buttons are up and nothing else is animating.
    private(set) var celebrationFinished = false
    /// The judged board lighting up green and red after Submit, before the
    /// level-end card. Nil until Submit, and again after Try again.
    private(set) var judging: Judging?
    /// The daily puzzle's result once submitted, for its stats card.
    private(set) var dailyResult: DailyResult?

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
    @ObservationIgnored private var judgingTask: Task<Void, Never>?
    /// The wave the previous board used, so the next one is different.
    /// Static because each level gets a new view model; it only has to last
    /// as long as the app is open, since a repeat across launches is unnoticeable.
    private static var lastWave: JudgingWave?
    @ObservationIgnored private var hapticCount = 0
    /// Weak because the host (the Game) owns this view model through its
    /// current screen; a strong reference back would be a retain cycle.
    @ObservationIgnored private weak var host: LevelHost?

    /// - Parameters:
    ///   - puzzle: the board to start from: fresh, or restored from a save
    ///     when the player left this level halfway.
    ///   - coach: set for the tutorial. It decides which actions are allowed;
    ///     the host (a `TutorialHost`) decides what they cost.
    ///   - dailyStartedAt: set for the daily puzzle (its host is a DailyHost).
    init(
        puzzle: PuzzleState,
        levelNumber: Int,
        host: LevelHost?,
        coach: TutorialCoach? = nil,
        scoringRules: ScoringRules = .standard,
        dailyStartedAt: Date? = nil
    ) {
        self.levelNumber = levelNumber
        self.dailyStartedAt = dailyStartedAt
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
    /// Whether a helper button looks available (lit, with its glow): there
    /// are some left, or a video can earn more. At 0 with no video it looks
    /// used up, but stays tappable so grandma can say why (`canTapHelpers`).
    var canUseCat: Bool { !isWatchingAd && (hints > 0 || catOffersAd) }
    var canUseGrandma: Bool { !isWatchingAd && (grandmas > 0 || grandmaOffersAd) }
    /// Helper buttons respond to taps except while a video is playing.
    var canTapHelpers: Bool { !isWatchingAd }

    /// Set once when a perfect board may lead to Apple's rating prompt; the
    /// level screen shows it a moment after the result.
    private(set) var asksForReview = false

    /// The rating prompt waits until the celebration is over: a system
    /// dialog over flying yarn would cut the best moment short.
    var readyForReviewPrompt: Bool { asksForReview && celebrationFinished }

    func celebrationDidFinish() {
        celebrationFinished = true
    }

    /// The level screen is requesting the rating prompt now.
    func reviewPromptRequested() {
        host?.reviewAsked(.perfectBoard)
    }

    /// The "watch a video, pick a treat" card is up.
    private(set) var isOfferingAd = false
    /// True while a rewarded ad is on screen, so a second tap can't start
    /// another one.
    private(set) var isWatchingAd = false
    /// The amounts the open offer promised; see `offerAd()`.
    @ObservationIgnored private var offeredAmounts: [HelperAdReward: Int] = [:]

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
        if puzzle.isSubmitted {
            // Green or red only once the wave reaches the cell. Starter
            // letters are never in the wave, so they stay plain.
            if judging?.isLit(cell) == true {
                style = puzzle.isWrong(cell) ? .wrong : .correct
            } else {
                style = .normal
            }
        } else if let answer = activeAnswer, let strength = highlightStrength(of: cell, in: answer) {
            style = .highlighted(colorIndex: colorIndex(ofAnswer: answer.id), strength: strength)
        } else {
            style = .normal
        }
        return LetterCellAppearance(
            letter: entry?.letter,
            style: style,
            isSelected: !puzzle.isSubmitted && cell == puzzle.selection,
            // Starter letters and the helpers' letters alike: anything the
            // player didn't place can't be erased, so it looks different.
            // Only while playing; the judged board is about right and wrong.
            isLocked: !puzzle.isSubmitted && (entry.map { $0.source != .placed } ?? false),
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
    // erasing) are simply off until it's over.

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
            if canWatchAd { offerAd() } else { explainNoVideo() }
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
            if canWatchAd { offerAd() } else { explainNoVideo() }
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
        let reward = host?.record(result) ?? LevelReward()
        earnedYarn = reward.yarn
        newlyKnittable = reward.newlyKnittable
        if let dailyStartedAt {
            // The host's saved result; worked out here only if it couldn't
            // be saved (a daily replaced mid-play), so the card still shows.
            dailyResult = reward.daily ?? DailyResult(
                correctLetters: result.correctLetters,
                judgedLetters: result.judgedLetters,
                seconds: max(0, Int(Date.now.timeIntervalSince(dailyStartedAt)))
            )
        }
        // The pass or fail haptic waits for the card (finishJudging), so it
        // lands with the verdict instead of before the board has shown it.
        startJudging(result)
        coachSaw(.submit)
        // Every letter right: a happy moment, if the rules allow asking now.
        let isPerfect = result.passed && result.correctLetters == result.judgedLetters
        if isPerfect, !isTutorial, host?.mayAskForReview() == true {
            asksForReview = true
        }
    }

    /// After the result: a pass moves on (the host decides where), a fail
    /// starts this level over with a cleared board. The daily has one go,
    /// so it always moves on.
    func continueAfterResult() {
        guard let result = puzzle.result else { return }
        if result.passed || isDaily {
            host?.continueToNextLevel()
        } else {
            earnedYarn = []
            newlyKnittable = nil
            judgingTask?.cancel()
            judging = nil
            puzzle.restart()
        }
    }

    // MARK: - Lighting up the judged board

    /// The level-end card is up: the board is judged and has finished
    /// lighting up.
    var showsLevelEnd: Bool { judging?.isFinished == true }

    /// The board is lighting up right now; a tap anywhere skips ahead.
    var isJudging: Bool { judging.map { !$0.isFinished } ?? false }

    /// Lights the rest of the board at once and brings up the card. Players
    /// see this after every level, so it must never become a wait.
    func skipJudging() {
        guard let result = puzzle.result else { return }
        finishJudging(result)
    }

    /// Lights the judged cells group by group in a random wave, then shows
    /// the card after a short pause, long enough to take in the whole board.
    private func startJudging(_ result: LevelResult) {
        // Starter letters were never the player's to get right, so they
        // aren't judged and stay plain.
        let judgedCells = level.letterCells.filter { puzzle.entries[$0]?.source != .given }
        var generator = SystemRandomNumberGenerator()
        let wave = JudgingWave.random(after: Self.lastWave, using: &generator)
        Self.lastWave = wave
        let groups = wave.groups(of: judgedCells, rows: level.rows, columns: level.columns)
        judging = Judging(groups: groups)

        let interval = JudgingTiming.interval(forGroups: groups.count)
        judgingTask?.cancel()
        judgingTask = Task { [weak self] in
            for _ in groups.indices {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                self.judging?.litGroups += 1
                self.feel(.cellsJudged)
            }
            try? await Task.sleep(for: JudgingTiming.pauseBeforeCard)
            guard !Task.isCancelled, let self else { return }
            self.finishJudging(result)
        }
    }

    /// Ends the wave, played through or skipped. Safe to call twice: only
    /// the first call lights the board and plays the verdict haptic.
    private func finishJudging(_ result: LevelResult) {
        guard var finished = judging, !finished.isFinished else { return }
        judgingTask?.cancel()
        finished.litGroups = finished.groupCount
        finished.isFinished = true
        judging = finished
        feel(result.passed ? .levelPassed : .levelFailed)
    }

    // MARK: - Restart (from the level's settings)

    /// Restart is offered: not in the lesson, where the coach expects its
    /// board, and not once the board is judged (Try again does that).
    var canRestart: Bool { !isTutorial && !puzzle.isSubmitted }

    /// The player has typed letters for Restart to clear.
    var hasLettersToClear: Bool { puzzle.hasPlacedLetters }

    /// Clears the player's letters, keeping starter letters and the
    /// helpers' ones (see PuzzleState.clearPlacedLetters), and saves.
    func restartBoard() {
        guard canRestart else { return }
        puzzle.clearPlacedLetters()
        feel(.letterErased)
        speech.say(GrandmaLines.freshStart)
        boardChanged()
    }

    /// Back to the home screen. The board is already saved (every letter
    /// change saves it), so coming back picks up where the player left off.
    /// Not so the daily, which starts over: leaving it mid-way asks first.
    func goHome() {
        if isDaily, !puzzle.isSubmitted {
            confirmsLeavingDaily = true
            return
        }
        host?.goHome()
    }

    /// The "Leave? Your time and board will reset" card is up.
    private(set) var confirmsLeavingDaily = false

    func keepPlayingDaily() {
        confirmsLeavingDaily = false
    }

    /// Confirmed on the card: the daily's go is thrown away (see DailyHost).
    func leaveDaily() {
        confirmsLeavingDaily = false
        host?.goHome()
    }

    // MARK: - Helpers from ads

    /// Out of a helper: offers a video, with a choice of reward (three cats
    /// or one grandma) whichever button was tapped. The reward goes to the
    /// player's helpers rather than being used at once, so they decide when
    /// and where to spend it.
    private func offerAd() {
        guard !isWatchingAd, !isCoaching, canWatchAd else { return }
        // The card is a promise: the amounts are fixed now and the same ones
        // are granted after the video. Asking the host again later could give
        // a different answer, e.g. if server tuning arrives during the video.
        offeredAmounts = Dictionary(uniqueKeysWithValues: HelperAdReward.allCases.map { reward in
            (reward, host?.amount(of: reward) ?? 0)
        })
        isOfferingAd = true
    }

    /// What each choice on the open offer gives (the card shows these).
    func offeredAmount(_ reward: HelperAdReward) -> Int {
        offeredAmounts[reward] ?? 0
    }

    /// Out of a helper and no video to offer: instead of a dead button,
    /// grandma says why. Either today's videos are used up (and the jar is
    /// where tomorrow's help comes from), or none happened to be ready.
    private func explainNoVideo() {
        // In the lesson helpers never run out, and grandma's card is talking.
        guard !isTutorial else { return }
        let limitReached = (host?.rewardedVideosLeftToday ?? 0) == 0
        speech.say(limitReached ? GrandmaLines.noMoreVideosToday : GrandmaLines.noVideoReady)
    }

    func cancelAdOffer() {
        isOfferingAd = false
    }

    func watchAd(for reward: HelperAdReward) {
        guard isOfferingAd, !isWatchingAd else { return }
        let amount = offeredAmount(reward)
        isOfferingAd = false
        isWatchingAd = true
        Task { [weak self] in
            guard let self else { return }
            let earned = await self.host?.watchAd(for: reward, amount: amount) ?? false
            self.isWatchingAd = false
            guard earned else { return }
            self.feel(.helperEarned)
            self.speech.say(GrandmaLines.adReward(reward, amount: amount))
        }
    }

    // MARK: - Tutorial

    var isTutorial: Bool { coach != nil }

    var isDaily: Bool { dailyStartedAt != nil }

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

/// The judged board lighting up, group by group (see JudgingWave).
struct Judging {
    /// Which group each judged cell lights with.
    private let groupOfCell: [Coordinate: Int]
    let groupCount: Int
    /// How many groups have lit so far.
    var litGroups = 0
    /// Every group has lit and the pause after them is over: time for the card.
    var isFinished = false

    init(groups: [[Coordinate]]) {
        var groupOfCell: [Coordinate: Int] = [:]
        for (index, group) in groups.enumerated() {
            for cell in group { groupOfCell[cell] = index }
        }
        self.groupOfCell = groupOfCell
        self.groupCount = groups.count
    }

    func isLit(_ cell: Coordinate) -> Bool {
        guard let group = groupOfCell[cell] else { return false }
        return group < litGroups
    }
}

/// How fast the judged board lights up.
enum JudgingTiming {
    /// Every wave takes about this long, whatever its shape: a diagonal
    /// sweep has twice the steps of a row sweep, and both should feel the
    /// same length.
    static let totalSeconds = 0.9
    /// …but a wave with few steps (a ripple on a small board) shouldn't crawl.
    static let longestStepSeconds = 0.12
    /// The whole board lit, before the card covers it.
    static let pauseBeforeCard: Duration = .seconds(0.45)

    static func interval(forGroups count: Int) -> Duration {
        guard count > 0 else { return .zero }
        return .seconds(min(longestStepSeconds, totalSeconds / Double(count)))
    }
}

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
        /// Judged right after Submit (revealed letters included).
        case correct
        case wrong
    }

    /// Lit green or red by the judging wave.
    var isJudged: Bool { style == .correct || style == .wrong }

    let letter: Character?
    let style: Style
    let isSelected: Bool
    /// A letter the player can't erase: a starter letter, or one the cat
    /// or grandma filled in.
    let isLocked: Bool
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
