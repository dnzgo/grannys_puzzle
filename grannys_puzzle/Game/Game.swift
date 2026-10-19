import Foundation
import Observation
import os
import AdKit
import ArrowwordCore
import GameServices
import NotifyKit

/// The running game: the player's saved progress, the level pack, and which
/// screen is showing.
///
/// It's the one place that changes `PlayerProgress`, and it saves after
/// every change. Saving right away (not on app exit) matters because iOS can
/// end a backgrounded app without warning; a helper spent or a reward earned
/// must already be on disk by then.
@Observable
final class Game {
    enum Screen {
        case home
        case level(LevelViewModel)
    }

    /// The current language's puzzles; replaced when the language changes.
    private(set) var pack: LevelPack
    let catalog: KnittingCatalog
    /// Nil in previews (no ads there).
    let ads: AdsController?
    /// Grandma's reminders; nil in previews.
    let reminders: Reminders?
    /// The lesson's board in the current language. Nil only if it failed
    /// to load, a build problem that the tests catch; the game then simply
    /// plays without it.
    private(set) var tutorial: Level?
    /// The daily puzzles in the current language; nil if they failed to
    /// load, and then the home screen has no daily button.
    private(set) var dailyPack: LevelPack?
    private(set) var progress: PlayerProgress
    private(set) var screen: Screen = .home
    /// The tunable numbers: the defaults, until the server's values are
    /// loaded at launch (see `loadRemoteTuning`).
    private(set) var tuning = GameTuning.standard

    /// Nil in previews, so previews never touch the real save file.
    @ObservationIgnored private let store: ProgressStore?
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()
    @ObservationIgnored private let logger = Logger(subsystem: "grannys_puzzle", category: "progress")
    /// Stands in for the game while the lesson plays (see TutorialHost).
    /// Kept here because levels only hold their host weakly.
    @ObservationIgnored private let tutorialHost = TutorialHost()
    /// Stands in for the game while the daily puzzle plays (see DailyHost).
    @ObservationIgnored private let dailyHost = DailyHost()
    /// The language the content was loaded for. Not always `pack.language`:
    /// a language whose pack isn't written yet plays the English one.
    @ObservationIgnored private var contentLanguage: String
    /// Loads another language's content; nil in previews.
    @ObservationIgnored private let loadContent: ((String) throws -> GameContent)?
    /// When an ad break between levels is due (this session only).
    @ObservationIgnored private var adBreaks = AdBreakSchedule()
    /// True from tapping Next until the break's ad has closed, so a second
    /// tap can't open two levels or ask for two ads.
    @ObservationIgnored private var isTakingAdBreak = false
    /// Analytics and remote values; nil without Firebase and in previews.
    @ObservationIgnored private let events: EventLogger?
    @ObservationIgnored private let remoteValues: (any RemoteValueSource)?
    /// When the current level (or its retry) started, for `level_end`'s time.
    @ObservationIgnored private var attemptStartedAt: ContinuousClock.Instant?
    /// Whether the lesson now playing was finished, to tell a skip apart.
    @ObservationIgnored private var lessonFinished = false

    init(
        pack: LevelPack,
        tutorial: Level? = nil,
        daily: LevelPack? = nil,
        language: String? = nil,
        store: ProgressStore?,
        ads: AdsController? = nil,
        reminders: Reminders? = nil,
        catalog: KnittingCatalog = .standard,
        services: AppServices = .none,
        loadContent: ((String) throws -> GameContent)? = nil
    ) {
        self.pack = pack
        self.events = services.events
        self.remoteValues = services.remoteValues
        self.contentLanguage = language ?? pack.language
        self.loadContent = loadContent
        self.ads = ads
        self.reminders = reminders
        self.tutorial = tutorial
        self.dailyPack = daily
        self.catalog = catalog
        self.store = store
        self.progress = .newPlayer
        if let store {
            progress = loadProgress(from: store)
        }
        // Level and saved board are kept per language; play the pack's.
        progress.activeLanguage = pack.language
        tutorialHost.game = self
        dailyHost.game = self
        apply(tuning)
    }

    // MARK: - What the home screen shows

    /// The level the Play button starts, if the pack has one left.
    var nextLevelNumber: Int? {
        pack.levels.indices.contains(progress.levelNumber - 1) ? progress.levelNumber : nil
    }

    /// True when the player can afford at least one item they don't own yet;
    /// the home screen uses it to nudge them toward the yarn bag.
    var canKnitSomething: Bool {
        catalog.items.contains(where: progress.canKnit)
    }

    /// True when a finished set's jar is waiting in the wardrobe; the home
    /// screen uses it to nudge them toward the wardrobe.
    var hasSetJarWaiting: Bool {
        catalog.items.contains { progress.hasSetJarWaiting(for: $0, in: catalog) }
    }

    // MARK: - Tuning

    /// Switches to the numbers the server set (downloaded on an earlier
    /// launch), then downloads new ones for the next launch.
    ///
    /// Safe to run while the home screen shows: a level takes its rules when
    /// it opens, so one already open keeps the rules it started with.
    func loadRemoteTuning() async {
        guard let remoteValues else { return }
        await remoteValues.activateFetched()
        // Read every key up front, so the tuning code works on plain values.
        var values: [String: Double] = [:]
        for key in GameTuning.Key.allCases {
            values[key.rawValue] = remoteValues.number(forKey: key.rawValue)
        }
        let resolved = GameTuning.resolved { values[$0] }
        if !resolved.ignored.isEmpty {
            // A console mistake: the defaults stand in, but it should be fixed.
            let keys = resolved.ignored.map(\.rawValue).joined(separator: ", ")
            Logger(subsystem: "grannys_puzzle", category: "tuning")
                .error("Ignored unusable remote values: \(keys, privacy: .public)")
        }
        apply(resolved.tuning)
        // Arrives a moment after launch (longer on the very first run), so
        // its timing helps when a value seems not to have taken effect.
        let fromServer = values.count - resolved.ignored.count
        Logger(subsystem: "grannys_puzzle", category: "tuning")
            .notice("Remote tuning applied: \(fromServer, privacy: .public) value(s) from the server")
        await remoteValues.fetchForNextLaunch()
    }

    /// Hands the numbers to the parts that use them. Also called at
    /// launch, so the tuning's defaults are the one source of truth for the
    /// ads package's time rules too.
    private func apply(_ newTuning: GameTuning) {
        tuning = newTuning
        adBreaks.firstLevel = newTuning.adBreakFirstLevel
        adBreaks.levelsBetween = newTuning.adBreakLevelsBetween
        ads?.setInterstitialGaps(
            minimum: .seconds(newTuning.adBreakMinimumSeconds),
            afterRewarded: .seconds(newTuning.adBreakSecondsAfterRewarded)
        )
    }

    // MARK: - Knitting

    /// What knitting an item led to.
    struct KnitReport {
        /// This item was the last colour of its garment: the set is done,
        /// and its jar is waiting in the wardrobe.
        let completedSet: Bool
    }

    /// Knits an item if the player can afford it, and saves at once, before
    /// any animation plays. Nil if it wasn't knitted.
    func knit(_ item: KnitItem) -> KnitReport? {
        var outcome = PlayerProgress.KnitOutcome.alreadyOwned
        var completedSet = false
        update { progress in
            outcome = progress.knit(item)
            completedSet = outcome == .knitted && catalog.isSetComplete(for: item, in: progress)
        }
        guard outcome == .knitted else { return nil }
        events?.log(.itemKnitted(item))
        if completedSet { events?.log(.setCompleted(item)) }
        return KnitReport(completedSet: completedSet)
    }

    /// Collects a finished set's jar in the wardrobe (any item of the set
    /// names it), unopened, and saves at once. Nil if there's none waiting.
    ///
    /// It holds the daily jar's big reward: four items is a real
    /// achievement, and this way one remotely tuned number covers both.
    func collectSetJar(for item: KnitItem) -> Jar? {
        var jar: Jar?
        update { jar = $0.collectSetJar(for: item, in: catalog, reward: tuning.jar.bigReward) }
        return jar
    }

    // MARK: - Jars

    /// Whether today's daily jar is waiting to be collected.
    func canCollectDailyJar(today: Int) -> Bool {
        progress.canCollectDailyJar(today: today)
    }

    /// Collects the daily jar for `today` (a `JarDay` number), unopened, and
    /// saves at once. Nil if today's was already collected.
    func collectDailyJar(today: Int) -> Jar? {
        var jar: Jar?
        update { jar = $0.collectDailyJar(today: today, rules: tuning.jar, using: &generator) }
        if let jar { events?.log(.jarCollected(jar)) }
        return jar
    }

    /// Opens the oldest unopened jar and saves at once, before the prize
    /// flies to the counters on screen. Nil when there's none.
    func openJar() -> Jar? {
        var jar: Jar?
        update { jar = $0.openJar() }
        if let jar { events?.log(.jarOpened(jar, stillUnopened: progress.jars.count)) }
        return jar
    }

    // MARK: - Reminders

    /// Re-plans grandma's reminders from where the player is now (their jar,
    /// streak and yarn), replacing whatever was scheduled before. Nothing is
    /// sent unless they said yes and the switch in Settings is on; NotifyKit
    /// checks both.
    ///
    /// Called whenever the app opens, goes inactive or goes to the
    /// background, not only when it leaves: a player who swipes the app away
    /// from the app switcher kills it before it ever reaches the background.
    /// Keeping the schedule fresh all the time means a killed app always
    /// leaves a correct one behind. While the game is open, iOS doesn't show
    /// them (see ReminderTapRelay), and the next re-plan replaces them.
    func refreshReminders() async {
        guard let reminders else { return }
        // The player may have changed it in iOS Settings since last time.
        await reminders.refreshPermission()
        let now = Date.now
        // Picking a line moves that kind's rotation on even if the reminder
        // is cancelled before it shows (the player came back first). Fine:
        // the point is that the lines that do show vary.
        let candidates = GrannyReminders.candidates(
            progress: progress, catalog: catalog, hasDailyChallenge: dailyPack != nil, now: now
        ) { lines, kind in
            reminders.line(from: lines, kind: kind)
        }
        await reminders.schedule(candidates, now: now)
    }

    /// Whether grandma may ask about reminders now (see HomeView for when).
    /// Her own question, before iOS's one-time prompt. Not until the player
    /// has passed a few real levels: straight after the lesson they don't
    /// yet know what they'd be reminded of, and iOS only asks once.
    var mayAskAboutReminders: Bool {
        guard levelsPassed >= tuning.reminderAskMinLevels else { return false }
        return reminders?.canOfferSoftAsk() ?? false
    }

    /// Real levels passed; the lesson isn't one. `levelNumber` is the next
    /// level to play, so one less have been passed.
    private var levelsPassed: Int { progress.levelNumber - 1 }

    /// Asks iOS whether notifications are allowed, before deciding whether
    /// grandma may ask: at launch the game hasn't heard yet.
    func refreshReminderPermission() async {
        await reminders?.refreshPermission()
    }

    /// The player answered grandma's question.
    func answerReminderQuestion(yes: Bool) async {
        guard let reminders else { return }
        if yes {
            let allowed = await reminders.requestPermission()
            events?.log(.reminderPermission(allowed: allowed))
            // Plan straight away: the player may close the app without it
            // ever going to the background in a way we hear about.
            if allowed { await refreshReminders() }
        } else {
            reminders.declineSoftAsk()
            events?.log(.reminderAskDeclined)
        }
    }

    /// A tapped reminder opened the game: which kinds bring players back is
    /// how the lines and timing get tuned.
    func reminderOpened(kind: String) {
        events?.log(.reminderOpened(kind: kind))
    }

    // MARK: - Language

    /// Switches to another language's puzzles at once: its pack, its lesson,
    /// and its own level and saved board. The player lands on the home
    /// screen; a level they were in is already saved, under its language.
    func switchLanguage(to language: String) {
        guard language != contentLanguage, let loadContent else { return }
        do {
            let content = try loadContent(language)
            pack = content.pack
            tutorial = content.tutorial
            dailyPack = content.daily
            contentLanguage = language
            progress.activeLanguage = pack.language
            screen = .home
            events?.log(.languageSwitched(to: language))
        } catch {
            // Only a broken build gets here; staying in the current language
            // is better than a game with no puzzles.
            logger.error("Couldn't load \(language, privacy: .public) puzzles: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Tutorial

    /// Opens the lesson if the player hasn't been through it. Called once at
    /// launch, rather than from `init`, so creating a `Game` (in a preview,
    /// say) never changes the screen by itself.
    func startTutorialIfNeeded() {
        if !progress.tutorialDone { startTutorial() }
    }

    /// Plays the lesson: on first launch, or again from Settings.
    func startTutorial() {
        guard let tutorial else { return }
        guard let script = TutorialScript.standard(for: tutorial.answerLanguage),
              let coach = TutorialCoach(script: script, level: tutorial)
        else {
            // The script names a word the board lacks; a test checks this,
            // so it can only happen with a mismatched build.
            logger.error("Tutorial script doesn't fit the tutorial board; skipping it")
            return
        }
        lessonFinished = false
        screen = .level(LevelViewModel(
            puzzle: PuzzleState(level: tutorial),
            levelNumber: 0,
            host: tutorialHost,
            coach: coach
        ))
        events?.log(.tutorialBegin)
    }

    /// The lesson's board was solved: its yarn, the first time only.
    func completeTutorial() -> [YarnColor] {
        var earned: [YarnColor] = []
        update { earned = $0.completeTutorial(using: &generator) }
        lessonFinished = true
        events?.log(.tutorialComplete)
        return earned
    }

    /// Leaving the lesson, finished or skipped. Either way it's done: a
    /// player who skipped chose not to see it, so it doesn't come back
    /// (Settings has it if they change their mind).
    func leaveTutorial() {
        if !lessonFinished {
            events?.log(.tutorialSkip)
        }
        if !progress.tutorialDone {
            update { $0.tutorialDone = true }
        }
        screen = .home
    }

    // MARK: - Daily puzzle

    /// The puzzle for `day` (a DailyDay number), if there are daily puzzles.
    func dailyLevel(day: Int) -> Level? {
        guard let dailyPack, let index = DailyDay.puzzleIndex(forDay: day, count: dailyPack.levels.count) else {
            return nil
        }
        return dailyPack.levels[index]
    }

    func dailyStatus(today: Int) -> DailyStatus {
        progress.dailyStatus(today: today)
    }

    /// Opens today's daily puzzle on a fresh board with a fresh clock, every
    /// time until it's submitted (see DailyAttempt for why).
    func playDaily() {
        let today = DailyDay.number()
        guard let level = dailyLevel(day: today) else { return }
        var attempt: DailyAttempt?
        update { attempt = $0.startDaily(today: today, levelID: level.id, now: .now) }
        // Nil once today's is submitted (the button is disabled by then).
        guard let attempt else { return }
        screen = .level(LevelViewModel(
            puzzle: PuzzleState(level: level),
            levelNumber: 0,
            host: dailyHost,
            scoringRules: tuning.scoring,
            dailyStartedAt: attempt.startedAt
        ))
    }

    /// The daily board was submitted: its result and time, saved at once.
    /// Submitting it counts as a day solved for the streak, whatever the
    /// score: there's no Try again to pass it on.
    func finishDaily(_ result: LevelResult) -> DailyResult? {
        var finished: DailyResult?
        update { progress in
            finished = progress.finishDaily(result, now: .now)
            if finished != nil { progress.recordStreakDay(today: JarDay.number()) }
        }
        return finished
    }

    // MARK: - Play streak

    func streakStatus(today: Int) -> StreakStatus {
        progress.streakStatus(today: today)
    }

    /// A video is loaded to save a streak with. Not limited by the daily
    /// cap on helper videos: losing a long streak is the moment a player is
    /// most likely to give up on the game, and this is the one way back.
    var canWatchAdToSaveStreak: Bool {
        ads?.isRewardedReady ?? false
    }

    /// Plays a rewarded video and, if it's watched to the end, saves the
    /// streak that missed yesterday. Returns whether it was saved.
    func watchAdToSaveStreak() async -> Bool {
        guard let ads, case .canSave(let days) = progress.streakStatus(today: JarDay.number()) else { return false }
        let earned = await ads.showRewarded()
        events?.log(.streakSaveVideo(days: days, earned: earned))
        guard earned else { return false }
        // The day is read again: the video may have run past midnight.
        var saved = false
        update { saved = $0.saveStreak(today: JarDay.number()) }
        return saved
    }

    func declineStreakSave() {
        update { $0.declineStreakSave(today: JarDay.number()) }
    }

    /// Back home from the daily. Unsubmitted, the go is thrown away.
    func leaveDaily() {
        update { $0.leaveDaily() }
        screen = .home
    }

    // MARK: - Navigation

    /// Opens the player's next level, picking up where they left it if they
    /// left it halfway.
    func play() {
        guard let number = nextLevelNumber else { return }
        let level = pack.levels[number - 1]
        if adBreaks.wantsAdsLoaded(forLevel: number) {
            ads?.prepareInterstitials()
        }
        let puzzle = startingPuzzle(for: level)
        // Read after `startingPuzzle`, which drops a saved board that no
        // longer fits: only a board actually restored counts as resumed.
        let resumed = progress.board != nil
        screen = .level(LevelViewModel(
            puzzle: puzzle,
            levelNumber: number,
            host: self,
            // The level keeps these rules even if new tuning arrives.
            scoringRules: tuning.scoring
        ))
        attemptStartedAt = .now
        events?.log(.levelStart(level: number, language: pack.language, resumed: resumed))
    }

    /// The level as the player left it, or fresh if there's no saved board
    /// for it (or the saved one no longer fits, e.g. the pack was regenerated).
    private func startingPuzzle(for level: Level) -> PuzzleState {
        guard let saved = progress.board else { return PuzzleState(level: level) }
        if let restored = PuzzleState.restored(level: level, from: saved) {
            return restored
        }
        // Expected after a pack update; anything else is worth knowing about.
        logger.notice("Saved board didn't fit level \(level.id, privacy: .public); starting fresh")
        update { $0.board = nil }
        return PuzzleState(level: level)
    }

    // MARK: - Saving

    private func update(_ change: (inout PlayerProgress) -> Void) {
        change(&progress)
        save()
    }

    private func save() {
        guard let store else { return }
        do {
            try store.save(progress)
        } catch {
            // Rare (a full disk) and nothing the player can fix from here.
            // The game keeps going with the progress in memory, and the next
            // successful save writes all of it.
            logger.error("Saving progress failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadProgress(from store: ProgressStore) -> PlayerProgress {
        do {
            return try store.load()
        } catch {
            // A damaged or too-new save. Starting over is the only way to
            // keep playing, but the old file is moved aside, not overwritten,
            // so it can still be recovered.
            logger.error("Saved progress unreadable, starting fresh: \(error.localizedDescription, privacy: .public)")
            do {
                try store.setAsideDamagedFile()
            } catch {
                logger.error("Couldn't set the damaged save aside: \(error.localizedDescription, privacy: .public)")
            }
            return .newPlayer
        }
    }
}

// MARK: - LevelHost

extension Game: LevelHost {
    var hints: Int { progress.hints }
    var grandmas: Int { progress.grandmas }

    func spendHint() -> Bool {
        var spent = false
        update { spent = $0.spendHint() }
        if spent { events?.log(.helperUsed(.cat, level: progress.levelNumber)) }
        return spent
    }

    func spendGrandma() -> Bool {
        var spent = false
        update { spent = $0.spendGrandma() }
        if spent { events?.log(.helperUsed(.grandma, level: progress.levelNumber)) }
        return spent
    }

    func record(_ result: LevelResult) -> LevelReward {
        // The level being judged; `record` below moves the number on.
        let level = progress.levelNumber
        let before = progress
        if result.passed {
            adBreaks.levelPassed(number: level)
        }
        var earned: [YarnColor] = []
        update {
            earned = $0.record(result, using: &generator)
            // Judged boards are finished: a pass moves on, a fail starts over.
            $0.board = nil
            // A pass is a day solved; a fail isn't, until it's passed.
            if result.passed { $0.recordStreakDay(today: JarDay.number()) }
        }

        let now = ContinuousClock.now
        let seconds = attemptStartedAt.map { Int((now - $0).components.seconds) } ?? 0
        // A retry after a fail is timed from here.
        attemptStartedAt = now
        events?.log(.levelEnd(level: level, language: pack.language, result: result, yarn: earned.count, seconds: seconds))
        return LevelReward(yarn: earned, newlyKnittable: catalog.newlyKnittable(before: before, after: progress))
    }

    /// An ad is loaded and today's videos aren't used up. (The day is read
    /// when asked; past midnight the next change on screen picks it up.)
    var canWatchAdForHelper: Bool {
        guard let ads, ads.isRewardedReady else { return false }
        return progress.rewardedAdsLeft(today: JarDay.number(), perDay: tuning.rewardedAdsPerDay) > 0
    }

    func amount(of reward: HelperAdReward) -> Int {
        reward.amount(in: tuning)
    }

    var rewardedVideosLeftToday: Int {
        progress.rewardedAdsLeft(today: JarDay.number(), perDay: tuning.rewardedAdsPerDay)
    }

    /// Kept on the device, like the settings switches: it's about this phone
    /// having shown the prompt, not about the player's progress.
    private static let lastReviewAskKey = "reviewPrompt.lastAskedAt"

    func mayAskForReview() -> Bool {
        let lastAsked = UserDefaults.standard.object(forKey: Self.lastReviewAskKey) as? Date
        return tuning.review.mayAsk(levelsPassed: levelsPassed, lastAsked: lastAsked, now: .now)
    }

    func reviewAsked(_ moment: ReviewMoment) {
        UserDefaults.standard.set(Date.now, forKey: Self.lastReviewAskKey)
        // Only that the game asked; iOS doesn't say whether it showed.
        events?.log(.reviewPromptRequested(moment))
    }

    /// Helper videos watched today (the streak-save video isn't one).
    private var helperVideosToday: Int {
        let perDay = tuning.rewardedAdsPerDay
        return perDay - progress.rewardedAdsLeft(today: JarDay.number(), perDay: perDay)
    }

    func adOfferOpened(outOf helper: HelperAdReward) {
        events?.log(.adOffer(outOf: helper, level: progress.levelNumber, videosToday: helperVideosToday))
    }

    func adOfferCancelled(outOf helper: HelperAdReward) {
        events?.log(.adOfferCancel(outOf: helper, level: progress.levelNumber))
    }

    func watchAd(for reward: HelperAdReward, amount: Int, outOf helper: HelperAdReward) async -> Bool {
        guard let ads, progress.rewardedAdsLeft(today: JarDay.number(), perDay: tuning.rewardedAdsPerDay) > 0 else {
            return false
        }
        let level = progress.levelNumber
        // Granted only when the ad reports the reward as earned, and saved
        // right away like every other change.
        let earned = await ads.showRewarded()
        if earned {
            let today = JarDay.number()
            update { progress in
                switch reward {
                case .catHints: progress.hints += amount
                case .grandma: progress.grandmas += amount
                }
                progress.recordRewardedAd(today: today)
            }
        }
        // Logged after the save, so `videos_today` includes this video when
        // it counted.
        events?.log(.rewardedVideo(reward, outOf: helper, earned: earned, level: level, videosToday: helperVideosToday))
        return earned
    }

    func saveBoard(_ board: SavedBoard?) {
        // Each change writes the progress file. It's a few kilobytes, so this
        // is cheap, and it means even a crash or a force-quit keeps the board.
        update { $0.board = board }
    }

    /// Next level, with an ad break first when one is due. The result
    /// screen stays up under the ad and the next level opens once it
    /// closes; if no ad shows (too soon, none loaded), it opens at once.
    func continueToNextLevel() {
        guard !isTakingAdBreak else { return }
        guard adBreaks.isBreakDue, let ads else {
            openNextLevel()
            return
        }
        isTakingAdBreak = true
        Task {
            if await ads.showInterstitial() {
                adBreaks.breakTaken()
                // The level just passed; `record` already moved the number on.
                events?.log(.adBreak(afterLevel: progress.levelNumber - 1))
            }
            isTakingAdBreak = false
            openNextLevel()
        }
    }

    private func openNextLevel() {
        // After the last level in the pack, home shows that more are coming.
        if nextLevelNumber != nil {
            play()
        } else {
            screen = .home
        }
    }

    func goHome() {
        screen = .home
    }
}

// MARK: - Previews

extension Game {
    /// A game for SwiftUI previews: the bundled pack, a made-up bag, no saving.
    static func preview() -> Game? {
        guard let pack = try? LevelLoader.firstPack(for: LevelLoader.fallbackLanguage) else { return nil }
        let game = Game(pack: pack, store: nil)
        game.progress = PlayerProgress(
            levelNumber: 7, hints: 3, grandmas: 1,
            yarn: [.red: 8, .blue: 2, .green: 1],
            wardrobe: ["cat.scarf.yellow"]
        )
        return game
    }
}
