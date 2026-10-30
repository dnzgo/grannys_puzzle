import SwiftUI
import Combine
import StoreKit
import AdKit
import ArrowwordCore

/// The home screen: grandma in her armchair with the cat, the yarn bag and
/// any unopened treat jars around her, the daily treats button, and the
/// Play button.
///
/// Each character is its own small view (`GrannyView`, `CatBedView`, …) so
/// that adding animation later only changes what's inside that view, not
/// this layout. Today they're still images.
struct HomeView: View {
    let game: Game

    @State private var speech = GrandmaSpeech()
    @State private var showsYarnBag = false
    @State private var showsWardrobe = false
    /// An item of the set the wardrobe opens on, when it's opened for one
    /// (after finishing that set); nil lets the wardrobe choose.
    @State private var wardrobeItem: KnitItem?
    @State private var showsSettings = false
    /// The item whose knitting moment is playing, if any.
    @State private var knittingItem: KnitItem?
    /// A finished set's moment, waiting for the knitting moment to end.
    @State private var pendingSetPrize: SetPrize?
    /// The finished set's moment being shown, if any.
    @State private var setPrize: SetPrize?
    /// A finished wardrobe's moment, waiting for the set's moment to end
    /// (the last item of a wardrobe always finishes a set too).
    @State private var pendingWardrobeDone: FamilyMember?
    /// The finished wardrobe whose moment is showing, if any.
    @State private var wardrobeDone: FamilyMember?
    /// Increased to play the wardrobe's swap: out to the right, and back
    /// in for the next member.
    @State private var wardrobeSwaps = 0
    /// The daily treats card is up.
    @State private var showsStreak = false
    /// The card offering to save a streak that missed yesterday is up.
    @State private var showsStreakSave = false
    /// Its video is playing.
    @State private var isSavingStreak = false
    /// Its last try had no video to show.
    @State private var streakVideoMissing = false
    /// An opened jar's helpers on their way to the counters.
    @State private var flight: PrizeFlight?
    /// Helpers from a jar that haven't landed yet, by kind. The counters
    /// show that many fewer than the player has (the prize is already
    /// saved), so each one counts up as it arrives.
    @State private var unlanded: [HelperFace: Int] = [:]
    /// Landings so far by kind; each one bumps that counter.
    @State private var landings: [HelperFace: Int] = [:]
    /// Increased to shake the jar.
    @State private var jarShakes = 0
    /// Between the tap and the prize appearing, so a second tap waits.
    @State private var isOpeningJar = false
    /// The jar shows open (lid off) from the shake until the helpers have
    /// landed. Kept apart from the jar count, which drops the moment the jar
    /// opens: the last jar must stay on the table, open, until then.
    @State private var jarIsOpen = false
    /// Where the jar and the counters are, for the prize's flight.
    @State private var jarFrame = CGRect.zero
    /// Where grandma and the wardrobe are, for knitting on the stage.
    @State private var grannyFrame = CGRect.zero
    @State private var wardrobeFrame = CGRect.zero
    /// Grandma rocks while she knits (the start of KnittingOnStage).
    @State private var isKnitting = false
    @State private var counterFrames: [HelperFace: CGRect] = [:]
    @State private var feedback: FeedbackSignal?
    @State private var feedbackCount = 0
    /// Grandma is asking whether she may send reminders.
    @State private var asksAboutReminders = false
    /// Today as a `JarDay` number. Kept as state and refreshed at midnight
    /// and when the app returns to the foreground, so the jar wakes up
    /// without the player having to relaunch.
    @State private var today = JarDay.number()
    @Environment(\.scenePhase) private var scenePhase
    /// Apple's "Enjoying the game?" prompt (iOS decides whether it shows).
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The coordinate space the jar's prize flies in, from the jar to the
    /// counters: the whole home screen.
    static let space = "home"
    /// The day the daily treats card last opened by itself. Kept on this
    /// device, like the settings: it's about this screen, not the player's
    /// progress.
    private static let streakCardShownDayKey = "streakCard.autoShownDay"

    private var dailyJarReady: Bool { game.canCollectDailyJar(today: today) }

    var body: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.horizontal, Theme.sidePadding)
                .padding(.top, 4)
                // Above the scene: on short screens the wardrobe's top
                // reaches up past the stage into this row, and the stage,
                // coming later, would otherwise be drawn over the buttons.
                .zIndex(1)

            HomeStage(
                progress: game.progress,
                canKnit: game.canKnitSomething,
                setJarWaiting: game.hasSetJarWaiting,
                jarCount: game.progress.jars.count,
                jarShakes: jarShakes,
                jarIsOpen: jarIsOpen,
                onGranny: { speech.say(GrandmaLines.greeting()) },
                onCat: { speech.say(GrandmaLines.catNapping) },
                onJar: tapJar,
                onJarFrame: { jarFrame = $0 },
                onYarnBag: { showsYarnBag = true },
                onWardrobe: { openWardrobe(on: nil) },
                wardrobeSwaps: wardrobeSwaps,
                isKnitting: isKnitting,
                onGrannyFrame: { grannyFrame = $0 },
                onWardrobeFrame: { wardrobeFrame = $0 }
            )
            // Like the settings button, but on the right of the scene rather
            // than in the top row, beside where the jars appear.
            .overlay(alignment: .topTrailing) {
                StreakButton(hasJarWaiting: dailyJarReady) { showsStreak = true }
                    .padding(.trailing, Theme.sidePadding)
                    .padding(.top, 8)
            }

            VStack(spacing: 14) {
                playButton
                if game.dailies != nil {
                    DailyPuzzleButton(status: game.dailyStatus(today:), height: Self.buttonHeight, isHeld: isOpeningJar) {
                        withAnimation(.easeInOut(duration: 0.25)) { game.playDaily() }
                    }
                }
            }
            // About 70% of the screen's width, so the two buttons sit under
            // the scene rather than spanning it.
            .padding(.horizontal, 58)
            .padding(.bottom, 20)
        }
        .background { HomeBackground() }
        // Applied before the flight's overlay, so the overlay shares this
        // space and the jar's and counters' frames are its own coordinates.
        .coordinateSpace(.named(Self.space))
        .overlay {
            if let item = knittingItem {
                KnittingOnStage(
                    item: item,
                    granny: grannyFrame,
                    wardrobe: wardrobeDoor,
                    onKnittingDone: { isKnitting = false },
                    onDone: { knitted(item) }
                )
            }
        }
        .overlay {
            if let flight {
                JarPrizeFlight(
                    faces: flight.faces,
                    start: flight.start,
                    target: counterPoint,
                    onLanded: prizeLanded,
                    onFinished: closeJar
                )
            }
        }
        .preferredColorScheme(.light)
        .gameFeedback(feedback)
        // The game's own cards rather than iOS sheets, like settings.
        .overlay {
            if showsYarnBag {
                YarnBagCard(
                    progress: game.progress,
                    catalog: game.catalog,
                    onKnit: { item in
                        showsYarnBag = false
                        startKnitting(item)
                    },
                    onClose: { showsYarnBag = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsYarnBag)
        .overlay {
            if showsWardrobe {
                WardrobeCard(
                    progress: game.progress,
                    catalog: game.catalog,
                    initialItem: wardrobeItem,
                    onCollectJar: collectSetJar,
                    onClose: { showsWardrobe = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsWardrobe)
        .overlay {
            if showsSettings {
                SettingsCard(context: .home(onHowToPlay: {
                    withAnimation(.easeInOut(duration: 0.25)) { game.startTutorial() }
                })) { showsSettings = false }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsSettings)
        .overlay {
            if let prize = setPrize {
                SetPrizeMoment(
                    items: game.catalog.itemsInSet(of: prize.item),
                    buttonTitle: pendingWardrobeDone == nil ? "Open wardrobe" : "Continue"
                ) {
                    setPrize = nil
                    // A finished wardrobe's moment comes next instead; its
                    // jar is collected later, from the wardrobe.
                    if let member = pendingWardrobeDone {
                        pendingWardrobeDone = nil
                        wardrobeDone = member
                    } else {
                        openWardrobe(on: prize.item)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: setPrize)
        .overlay {
            if let member = wardrobeDone {
                WardrobeDoneMoment(member: member, next: game.catalog.currentMember(for: game.progress)) {
                    finishWardrobe()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: wardrobeDone)
        .overlay {
            if showsStreak {
                StreakCard(
                    day: streakCardDay,
                    isCollected: !dailyJarReady,
                    length: game.tuning.jar.streakLength,
                    onCollect: collectDailyJar,
                    onClose: { showsStreak = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsStreak)
        .overlay {
            if showsStreakSave, let days = streakToSave {
                StreakSaveCard(
                    days: days,
                    isWatching: isSavingStreak,
                    noVideo: streakVideoMissing,
                    onWatch: watchVideoToSaveStreak,
                    onLetGo: letStreakGo,
                    onClose: { showsStreakSave = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsStreakSave)
        .overlay {
            if asksAboutReminders {
                ReminderAskCard(
                    onYes: { answerReminderQuestion(yes: true) },
                    onNotNow: { answerReminderQuestion(yes: false) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: asksAboutReminders)
        // Grandma's speech bubble, last so it's above everything: the scene,
        // the knitting and jar animations, the top row and any card. It
        // lets taps through, so it never blocks what's underneath.
        .overlay {
            if let line = speech.line {
                GrandmaBubble(text: line, granny: grannyFrame)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: speech.line)
        .onAppear {
            today = JarDay.number()
            speech.say(openingLine)
        }
        // Ads start here rather than at launch: a new player meets grandma's
        // lesson first, and the consent form and tracking question come
        // after it, once they know what the game is. For everyone else home
        // is the first screen anyway. Repeat calls do nothing once started.
        .task {
            await game.ads?.start()
            // Then the daily treats, after the consent and tracking questions
            // a new player gets first (once started, this returns at once).
            try? await Task.sleep(for: .seconds(0.4))
            // Gone already (Play tapped straight away): today's one automatic
            // showing mustn't be used up on a screen nobody sees.
            guard !Task.isCancelled else { return }
            // A streak about to be lost comes first: it's today or never.
            if !offerStreakSaveIfNeeded() { showStreakIfFirstVisitToday() }
        }
        // Grandma's reminder question comes right after a daily jar is
        // collected (see collectDailyJar). A player who passes enough levels
        // after today's jar would otherwise wait until tomorrow's, and that's
        // exactly the player who might not come back. So she also asks on
        // coming home with today's jar already collected. A moment's pause
        // first, so home appears before her question.
        .task {
            try? await Task.sleep(for: .seconds(0.8))
            // Asked again rather than trusted: at launch the game hasn't yet
            // heard from iOS whether notifications are already allowed.
            await game.refreshReminderPermission()
            guard !Task.isCancelled, !dailyJarReady, !isShowingSomethingElse, game.mayAskAboutReminders else { return }
            asksAboutReminders = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = JarDay.number() }
        }
        // iOS posts this at midnight (and on time zone changes). It can
        // arrive on any thread, so hop to the main thread before touching
        // view state.
        .onReceive(
            NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)
        ) { _ in
            today = JarDay.number()
        }
        // A new day while the app stays open.
        .onChange(of: today) {
            if !offerStreakSaveIfNeeded() { showStreakIfFirstVisitToday() }
        }
    }

    private var openingLine: String {
        // "I'm writing more" only when that's true: not while the next
        // pack is downloading or waiting for a connection.
        if game.nextLevelNumber == nil, game.nextPackStatus == .noneYet { return GrandmaLines.allLevelsDone }
        if dailyJarReady { return GrandmaLines.jarReady }
        return GrandmaLines.greeting()
    }

    // MARK: - Play streak

    /// The days a save would keep, when yesterday was missed.
    private var streakToSave: Int? {
        if case .canSave(let days) = game.streakStatus(today: today) { return days }
        return nil
    }

    /// Opens the save card if there's a streak to save and nothing else is
    /// up. Returns whether it did, so the daily treats card can wait.
    @discardableResult
    private func offerStreakSaveIfNeeded() -> Bool {
        guard streakToSave != nil, !isShowingSomethingElse else { return false }
        streakVideoMissing = false
        showsStreakSave = true
        return true
    }

    private func watchVideoToSaveStreak() {
        guard !isSavingStreak else { return }
        guard game.canWatchAdToSaveStreak else {
            streakVideoMissing = true
            return
        }
        isSavingStreak = true
        Task {
            let saved = await game.watchAdToSaveStreak()
            isSavingStreak = false
            // Watched to the end or not, the card stays up unless it worked,
            // so the player can try again.
            guard saved else { return }
            showsStreakSave = false
            feel(.helperEarned)
            speech.say(GrandmaLines.streakSaved)
            try? await Task.sleep(for: .seconds(0.6))
            showStreakIfFirstVisitToday()
        }
    }

    private func letStreakGo() {
        game.declineStreakSave()
        showsStreakSave = false
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            showStreakIfFirstVisitToday()
        }
    }

    /// What grandma says about the streak when its chip is tapped.
    private func sayStreakLine() {
        switch game.streakStatus(today: today) {
        case .active(let days, solvedToday: true): speech.say(GrandmaLines.streakKept(days))
        case .active(let days, solvedToday: false): speech.say(GrandmaLines.streakAtRisk(days))
        case .none, .canSave: speech.say(GrandmaLines.streakStart)
        }
    }

    // MARK: - Jars

    /// The day the streak card shows as today's.
    private var streakCardDay: Int {
        dailyJarReady
            ? game.progress.jarStreakDay(today: today, rules: game.tuning.jar)
            : max(game.progress.jarStreak, 1)
    }

    /// The first time home shows each day with today's jar waiting, the
    /// streak card opens by itself; after that it's the calendar button.
    private func showStreakIfFirstVisitToday() {
        guard dailyJarReady, !isShowingSomethingElse else { return }
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: Self.streakCardShownDayKey) != today else { return }
        defaults.set(today, forKey: Self.streakCardShownDayKey)
        showsStreak = true
    }

    /// Collected, the jar goes beside grandma's chair unopened. A moment on
    /// the card first, to see today's tick appear.
    private func collectDailyJar() {
        guard game.collectDailyJar(today: today) != nil else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            showsStreak = false
            speech.say(GrandmaLines.jarKept)
            // Right after her jar is the moment the offer means something:
            // "shall I tell you when the next one's ready?"
            try? await Task.sleep(for: .seconds(0.8))
            if !isShowingSomethingElse, game.mayAskAboutReminders { asksAboutReminders = true }
        }
    }

    /// Opens one jar: it shakes, then what's inside pops out and flies to
    /// the counters. Saved the moment it opens, like knitting; the flight is
    /// the reveal.
    private func tapJar() {
        // Not while one is still open: its lid goes back on a moment after
        // the last helper lands, and a second opening would race that.
        guard !isOpeningJar, !jarIsOpen, flight == nil, !game.progress.jars.isEmpty else { return }
        isOpeningJar = true
        if !reduceMotion { jarShakes += 1 }
        feel(.jarShaken)
        // The open jar's mouth, a little over a third of the way down its
        // image (the lid floats above it). Taken now, before the jar changes.
        let start = CGPoint(x: jarFrame.midX, y: jarFrame.minY + jarFrame.height * 0.37)
        Task {
            defer { isOpeningJar = false }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.5))
            guard let jar = game.openJar() else { return }
            // Set in the same update as the save, so the counters never
            // show the new totals before the helpers arrive.
            unlanded = [.cat: jar.reward.hints, .grandma: jar.reward.grandmas]
            jarIsOpen = true
            feel(.jarOpened)
            flight = PrizeFlight(
                start: start,
                faces: Array(repeating: HelperFace.cat, count: jar.reward.hints)
                    + Array(repeating: HelperFace.grandma, count: jar.reward.grandmas)
            )
        }
    }

    /// Everything has landed: the lid goes back on (or, if that was the
    /// last jar, the jar leaves the table) a moment later.
    private func closeJar() {
        flight = nil
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            jarIsOpen = false
        }
    }

    private func prizeLanded(_ face: HelperFace) {
        unlanded[face] = max(0, unlanded[face, default: 0] - 1)
        landings[face, default: 0] += 1
        feel(.prizeLanded)
    }

    /// Where a helper lands: on its face in the helpers' card.
    private func counterPoint(for face: HelperFace) -> CGPoint {
        guard let frame = counterFrames[face] else { return .zero }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// What a counter shows: the player's helpers, less any still flying.
    private func shownCount(of face: HelperFace) -> Int {
        let owned = face == .cat ? game.progress.hints : game.progress.grandmas
        return owned - unlanded[face, default: 0]
    }

    private func feel(_ event: FeedbackEvent) {
        feedbackCount += 1
        feedback = FeedbackSignal(event: event, id: feedbackCount)
    }

    /// The helpers' card on the left, the streak in the middle, settings on
    /// the right.
    ///
    /// The two sides take equal shares of whatever the streak leaves, so the
    /// streak stays at the screen's centre however wide the card gets (a
    /// count passing 100 widens it). Centring the streak in a ZStack over
    /// the row instead would also centre it, but a wide card could then
    /// slide under it; here the sides can only shrink into their own share.
    private var topRow: some View {
        // Top-aligned: the card is two rows tall and the streak one, and
        // their top edges in line read as one row; centred, the streak
        // would float halfway down the card.
        HStack(alignment: .top, spacing: 8) {
            HelperCard(
                counts: [.grandma: shownCount(of: .grandma), .cat: shownCount(of: .cat)],
                bumps: landings,
                onFaceFrame: { face, frame in counterFrames[face] = frame }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            StreakChip(status: game.streakStatus(today: today), action: sayStreakLine)
                .fixedSize()
                .layoutPriority(1)

            // The wardrobe of knitted things opens from the wardrobe in the
            // scene, so the top row only needs settings.
            CircleIconButton(systemName: "gearshape", label: "Settings") { showsSettings = true }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        // At least the level screen's top bar, so the scene below starts at
        // the same height; the two-row card may make it a little taller.
        .frame(minHeight: BoardMetrics.topBarHeight)
    }

    /// A sheet, card or moment is up, which grandma's question and the
    /// streak card mustn't cover.
    private var isShowingSomethingElse: Bool {
        showsYarnBag || showsWardrobe || showsSettings || showsStreak || showsStreakSave || asksAboutReminders
            || isOpeningJar || jarIsOpen || flight != nil || knittingItem != nil || setPrize != nil
            || wardrobeDone != nil
    }

    /// Closes grandma's card first, so on a yes iOS's own prompt appears
    /// over the home screen rather than over her question.
    private func answerReminderQuestion(yes: Bool) {
        asksAboutReminders = false
        Task { await game.answerReminderQuestion(yes: yes) }
    }

    /// Knitting is saved first; the moments on screen are only the reveal.
    private func startKnitting(_ item: KnitItem) {
        guard let report = game.knit(item) else { return }
        pendingSetPrize = report.completedSet ? SetPrize(item: item) : nil
        pendingWardrobeDone = report.completedWardrobe
        isKnitting = true
        knittingItem = item
    }

    /// The knitting has played: a finished set has its own moment before
    /// grandma speaks (and a finished wardrobe after that).
    private func knitted(_ item: KnitItem) {
        knittingItem = nil
        if let prize = pendingSetPrize {
            pendingSetPrize = nil
            setPrize = prize
        } else if let member = pendingWardrobeDone {
            pendingWardrobeDone = nil
            wardrobeDone = member
        } else {
            afterKnitting(for: item.member)
        }
    }

    /// The middle of the wardrobe's doors. It runs off the right edge of
    /// the screen, so this is left of its centre, on the part that's seen.
    private var wardrobeDoor: CGPoint {
        CGPoint(x: wardrobeFrame.minX + wardrobeFrame.width * 0.3, y: wardrobeFrame.minY + wardrobeFrame.height * 0.4)
    }

    private func openWardrobe(on item: KnitItem?) {
        wardrobeItem = item
        showsWardrobe = true
    }

    /// After a finished wardrobe's moment: the wardrobe in the room shakes,
    /// goes out to the right and comes back for the next member (unless
    /// that was the last), and grandma says who's next.
    private func finishWardrobe() {
        wardrobeDone = nil
        let next = game.catalog.currentMember(for: game.progress)
        if next != nil {
            wardrobeSwaps += 1
            feel(.wardrobeShaken)
        }
        speech.say(GrandmaLines.wardrobeStarted(for: next))
        askForReviewIfDue()
    }

    /// The set's jar goes beside grandma's chair, unopened, like the daily
    /// ones. The card closes so the player sees it arrive on the table.
    private func collectSetJar(for item: KnitItem) {
        guard game.collectSetJar(for: item) != nil else { return }
        showsWardrobe = false
        speech.say(GrandmaLines.jarKept)
        askForReviewIfDue()
    }

    /// Grandma's comment once the knitting is shown, and, a finished piece
    /// being a happy moment, maybe the rating prompt.
    private func afterKnitting(for member: FamilyMember) {
        speech.say(GrandmaLines.knitted(for: member))
        askForReviewIfDue()
    }

    /// The rating prompt, after a happy moment, if it's due.
    private func askForReviewIfDue() {
        guard game.mayAskForReview() else { return }
        Task {
            try? await Task.sleep(for: ReviewTiming.delayAfterHappyMoment)
            game.reviewAsked(.itemKnitted)
            requestReview()
        }
    }

    /// Both home buttons, the level and the daily.
    private static let buttonHeight: CGFloat = 54

    @ViewBuilder
    private var playButton: some View {
        if let number = game.nextLevelNumber {
            HomeButton(title: "Level \(number)", accent: Theme.primary, height: Self.buttonHeight) {
                withAnimation(.easeInOut(duration: 0.25)) { game.play() }
            }
            // Not while a jar is shaking open: leaving then would open it
            // with nobody watching. (The flight itself blocks taps.)
            .disabled(isOpeningJar)
        } else {
            OutOfLevelsNote(status: game.nextPackStatus, height: Self.buttonHeight, retry: game.retryNextPack)
        }
    }
}

// MARK: - The background

/// The room picture behind the home screen: window, floor and rug. The
/// scene's furniture and characters are separate images placed on top
/// (HomeStage), so they can be tapped and animated on their own.
private struct HomeBackground: View {
    var body: some View {
        // Measured over the whole screen, safe areas included, so the
        // picture reaches every edge. Pinned to the bottom: the floor must
        // meet the bottom edge, and on a tall screen it's the top (the
        // ceiling) that's cut instead.
        GeometryReader { proxy in
            Image("home-background")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - The stage

/// Grandma's corner, laid out on a square-ish "stage" that scales with the
/// screen. Positions are fractions of the stage size, so the scene keeps its
/// composition from an iPhone SE to a Pro Max.
private struct HomeStage: View {
    let progress: PlayerProgress
    let canKnit: Bool
    /// A finished set's jar is waiting in the wardrobe.
    let setJarWaiting: Bool
    /// Unopened jars; the jar is only on the table while there's one (or
    /// while the last one is open).
    let jarCount: Int
    let jarShakes: Int
    let jarIsOpen: Bool
    let onGranny: () -> Void
    let onCat: () -> Void
    let onJar: () -> Void
    /// Reports where the jar is, for the prize's flight.
    let onJarFrame: (CGRect) -> Void
    let onYarnBag: () -> Void
    let onWardrobe: () -> Void
    /// Increased to play the wardrobe's swap (a wardrobe finished).
    let wardrobeSwaps: Int
    /// Grandma rocks while she knits.
    let isKnitting: Bool
    /// Report where grandma and the wardrobe are, for knitting's animation.
    let onGrannyFrame: (CGRect) -> Void
    let onWardrobeFrame: (CGRect) -> Void

    /// Stage height as a multiple of its width.
    private let aspect: CGFloat = 1.1

    var body: some View {
        GeometryReader { geometry in
            // The largest stage that fits, centred in the space available.
            let side = min(geometry.size.width, geometry.size.height / aspect)
            let origin = CGPoint(
                x: (geometry.size.width - side) / 2,
                y: (geometry.size.height - side * aspect) / 2
            )
            // A point on the stage, from fractions of its width.
            let at = { (x: CGFloat, y: CGFloat) in CGPoint(x: origin.x + x * side, y: origin.y + y * side) }

            ZStack {
                // Back to front, like layers of a painting (the room picture
                // behind, with its floor and rug, is HomeBackground): the
                // wardrobe at the back on the right (running off the edge, as
                // a room does), the yarn bag tucked behind grandma's chair on
                // the right, grandma, the side table with the jars at the
                // front left, and the cat's bed in front of her.
                // Measured from the agreed mock-up of the real art (positions
                // past 1, or a width running off screen, are on purpose).
                WardrobeView(width: side * 0.623, hasJarWaiting: setJarWaiting, swaps: wardrobeSwaps, action: onWardrobe)
                    .onGeometryChange(for: CGRect.self) { [space = HomeView.space] proxy in
                        proxy.frame(in: .named(space))
                    } action: { frame in
                        onWardrobeFrame(frame)
                    }
                    .position(at(0.896, 0.411))

                YarnBagView(progress: progress, canKnit: canKnit, width: side * 0.302, action: onYarnBag)
                    .position(at(0.823, 0.902))

                GrannyView(width: side * 0.804, isKnitting: isKnitting, action: onGranny)
                    .onGeometryChange(for: CGRect.self) { [space = HomeView.space] proxy in
                        proxy.frame(in: .named(space))
                    } action: { frame in
                        onGrannyFrame(frame)
                    }
                    .position(at(0.388, 0.665))

                // The bag's "Knit!" tag and count, drawn in front of grandma
                // although the bag is behind her: half hidden by her chair,
                // they'd stop telling the player there's something to knit.
                YarnBagLabels(progress: progress, canKnit: canKnit, width: side * 0.302, action: onYarnBag)
                    .position(at(0.823, 0.902))

                SideTableView(width: side * 0.315)
                    .position(at(0.163, 0.982))

                // On the left of the table top, beside the plant.
                if jarCount > 0 || jarIsOpen {
                    JarView(width: side * 0.128, count: jarCount, shakes: jarShakes, isOpen: jarIsOpen, action: onJar)
                        .onGeometryChange(for: CGRect.self) { [space = HomeView.space] proxy in
                            proxy.frame(in: .named(space))
                        } action: { frame in
                            onJarFrame(frame)
                        }
                        .position(at(0.128, 0.879))
                        .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
                }

                CatBedView(width: side * 0.294, action: onCat)
                    .position(at(0.452, 1.012))
            }
            // A jar collected pops in; the last one opened shrinks away
            // once its helpers have landed.
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: jarCount > 0 || jarIsOpen)
        }
    }
}

// MARK: - Characters and props

/// Grandma in her armchair. Later: talking and knitting animations.
private struct GrannyView: View {
    let width: CGFloat
    /// She rocks in her chair while she knits.
    let isKnitting: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image("granny").resizable().scaledToFit().frame(width: width)
                // An oval rather than the image's rectangle, so the empty
                // corners around the armchair don't steal taps meant for
                // the yarn bag tucked behind it.
                .contentShape(Ellipse())
                // A small quick rock, over and over, while the needles go.
                // Not repeating, it rests at the start: upright.
                .keyframeAnimator(initialValue: 0.0, repeating: isKnitting && !reduceMotion) { content, degrees in
                    content.rotationEffect(.degrees(degrees), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.6, duration: 0.15)
                        CubicKeyframe(-1.6, duration: 0.3)
                        CubicKeyframe(0, duration: 0.15)
                    }
                }
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Grandma")
    }
}

/// The cat in its bed. Later: paw licking and tail waving.
private struct CatBedView: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("cat-bed").resizable().scaledToFit().frame(width: width)
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("The cat")
    }
}

/// The unopened treat jars on the side table, as one jar with an "Open!"
/// tag, and how many there are on its top right once there's more than
/// one. A tap opens one: it shakes, then its lid comes off (the open
/// image, drawn to line up exactly with the closed one) with a little hop.
private struct JarView: View {
    let width: CGFloat
    let count: Int
    /// Increased to play the shake.
    let shakes: Int
    /// The lid is off while its helpers fly out.
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(isOpen ? "jar-open" : "jar").resizable().scaledToFit().frame(width: width)
                // The hop as the lid comes off.
                .keyframeAnimator(initialValue: 1.0, trigger: isOpen) { content, scale in
                    content.scaleEffect(scale, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.1, duration: 0.08)
                        SpringKeyframe(1.0, duration: 0.3)
                    }
                }
                // A quick wobble on its base, settling back.
                .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, angle in
                    content.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-9, duration: 0.08)
                        CubicKeyframe(9, duration: 0.1)
                        CubicKeyframe(-7, duration: 0.1)
                        CubicKeyframe(6, duration: 0.1)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
                .overlay(alignment: .top) {
                    if !isOpen { NudgeTag(text: "Open!").offset(y: -width * 0.2) }
                }
                .overlay(alignment: .topTrailing) {
                    if count > 1, !isOpen { countBadge.offset(x: width * 0.15, y: width * 0.1) }
                }
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Treat jar")
        .accessibilityValue(Text("\(count) unopened"))
        .accessibilityHint(Text("Opens one jar"))
    }

    /// Like the yarn bag's count.
    private var countBadge: some View {
        Text("\(count)")
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 24)
            .background(Capsule().fill(Theme.ink))
            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
    }
}

/// Opens the daily treats card. A red dot while today's jar is waiting to
/// be collected, so the player knows there's something to tap for.
private struct StreakButton: View {
    let hasJarWaiting: Bool
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemName: "calendar", label: "Daily treats", action: action)
            .overlay(alignment: .topTrailing) {
                if hasJarWaiting {
                    Circle()
                        .fill(Theme.alertDot)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                        .offset(x: 1, y: -1)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(hasJarWaiting ? Text("Today's jar is waiting") : Text(""))
    }
}

/// Grandma's wardrobe, at the back of the room. A tap opens the wardrobe
/// of knitted things: the way in, now that the top row has no hanger button.
/// A "Collect!" tag says a finished set's jar is waiting inside.
///
/// When a family member's wardrobe is finished it shakes, rolls out to the
/// right, and the next member's comes in (the same picture: what changes
/// is what's inside) with a smaller shake.
private struct WardrobeView: View {
    let width: CGFloat
    let hasJarWaiting: Bool
    /// Each increase plays the swap once.
    let swaps: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image("wardrobe").resizable().scaledToFit().frame(width: width)
                // With Reduce Motion the trigger never changes, so it
                // doesn't play: grandma's line still says what happened.
                .keyframeAnimator(initialValue: WardrobeSwap(), trigger: reduceMotion ? 0 : swaps) { content, value in
                    content
                        // Rocking on its feet, like a heavy piece of furniture.
                        .rotationEffect(.degrees(value.degrees), anchor: .bottom)
                        .offset(x: value.offset * width)
                } keyframes: { _ in
                    // Shake, then hold still while it's away, then a smaller
                    // shake once the new one has arrived (at 1.7 s).
                    KeyframeTrack(\.degrees) {
                        CubicKeyframe(-3, duration: 0.09)
                        CubicKeyframe(3, duration: 0.09)
                        CubicKeyframe(-3, duration: 0.09)
                        CubicKeyframe(3, duration: 0.09)
                        CubicKeyframe(-2, duration: 0.09)
                        CubicKeyframe(0, duration: 0.09)
                        LinearKeyframe(0, duration: 1.16)
                        CubicKeyframe(-1.5, duration: 0.09)
                        CubicKeyframe(1.5, duration: 0.09)
                        CubicKeyframe(-1, duration: 0.09)
                        CubicKeyframe(0, duration: 0.09)
                    }
                    // Away to the right (0.9 widths takes it fully off the
                    // screen from where it stands), a pause, then back.
                    KeyframeTrack(\.offset) {
                        LinearKeyframe(0, duration: 0.55)
                        CubicKeyframe(0.9, duration: 0.45)
                        LinearKeyframe(0.9, duration: 0.15)
                        SpringKeyframe(0, duration: 0.55, spring: .bouncy)
                    }
                }
        }
        .buttonStyle(SceneButtonStyle())
        // Left of centre: the wardrobe runs off the right edge of the
        // screen, so its middle is partly hidden.
        .overlay(alignment: .top) {
            if hasJarWaiting {
                Button(action: action) { NudgeTag(text: "Collect!") }
                    .buttonStyle(.plain)
                    .offset(x: -width * 0.22, y: width * 0.1)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Wardrobe")
        .accessibilityHint(hasJarWaiting ? Text("Jar waiting") : Text(""))
    }
}

/// The side table the jars stand on. Only furniture: the jar on it is the
/// thing to tap, so the table lets taps through rather than catching them.
private struct SideTableView: View {
    let width: CGFloat

    var body: some View {
        Image("side-table").resizable().scaledToFit().frame(width: width)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Grandma's yarn bag, with the number of balls in it as a badge and a
/// "Knit!" tag when there's enough yarn for something new.
private struct YarnBagView: View {
    let progress: PlayerProgress
    let canKnit: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("yarn-bag").resizable().scaledToFit().frame(width: width)
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Yarn bag")
        .accessibilityValue("\(progress.totalYarn) balls")
        .accessibilityHint(canKnit ? Text("Enough yarn to knit something") : Text(""))
    }
}

/// The yarn bag's count and "Knit!" tag, laid out on a frame the size of
/// the bag so they sit in the same places on it, but drawn as their own
/// layer in front of grandma (see HomeStage). Only the badge and tag catch
/// taps, and they open the bag like the bag itself; the frame between them
/// lets taps through to whatever is underneath.
private struct YarnBagLabels: View {
    let progress: PlayerProgress
    let canKnit: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        // Invisible, only to take the bag's exact size.
        Image("yarn-bag").resizable().scaledToFit().frame(width: width)
            .hidden()
            // The badge sits on the bag's open top, where the balls are,
            // rather than the image corner, which is empty space.
            .overlay(alignment: .topTrailing) {
                Button(action: action) { countBadge }
                    .buttonStyle(.plain)
                    .offset(x: -width * 0.08, y: width * 0.1)
            }
            .overlay(alignment: .top) {
                if canKnit {
                    Button(action: action) { NudgeTag(text: "Knit!") }
                        .buttonStyle(.plain)
                        .offset(y: -width * 0.12)
                }
            }
            // The bag itself already tells VoiceOver the count and the hint.
            .accessibilityHidden(true)
    }

    private var countBadge: some View {
        Text("\(progress.totalYarn)")
            .font(.system(size: 13, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 24, minHeight: 24)
            .background(Capsule().fill(Theme.ink))
            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
    }
}

/// A small orange tag over a scene object that has something waiting
/// ("Knit!", "Open!").
private struct NudgeTag: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.onPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.primary))
            .shadow(color: Theme.primary.opacity(0.4), radius: 4, y: 2)
            .fixedSize()
    }
}

/// How many of each helper the player has, in one card: grandma above
/// the cat, each face with its count.
///
/// The card sizes itself to its longest count, so it grows rather than
/// clipping as counts pass 99 or 999. The faces share one column, and so
/// the counts start in line however many digits each has.
private struct HelperCard: View {
    let counts: [HelperFace: Int]
    /// Increased each time a helper from a jar lands on a face: a quick bump.
    let bumps: [HelperFace: Int]
    /// Reports where a face is in the home screen's space, which is where an
    /// opened jar's helpers fly to.
    let onFaceFrame: (HelperFace, CGRect) -> Void

    /// The same size as the faces on the old separate counters.
    private static let faceSize: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(.grandma, label: "Grandma helpers")
            row(.cat, label: "Cat hints")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        )
    }

    private func row(_ face: HelperFace, label: LocalizedStringKey) -> some View {
        let count = counts[face, default: 0]
        // Copied into a local so the geometry closure, which SwiftUI may run
        // off the main actor, captures a plain string (as in Spotlight).
        let space = HomeView.space
        return HStack(spacing: 6) {
            HelperFaceImage(face: face, size: Self.faceSize)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(space))
                } action: { frame in
                    onFaceFrame(face, frame)
                }
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                // Equal-width digits, so a count ticking up doesn't jiggle.
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                // A safety net only: the card grows with the digits, and
                // this shrinks the text a little if a very narrow screen
                // ever leaves the card less room than its count needs.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(value: Double(count)))
                .animation(.snappy, value: count)
        }
        .keyframeAnimator(initialValue: 1.0, trigger: bumps[face, default: 0]) { content, scale in
            content.scaleEffect(scale, anchor: .leading)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.18, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(count)")
    }
}

/// Scene objects shrink a little while pressed, so they feel touchable even
/// before they have real animations.
private struct SceneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    if let game = Game.preview() {
        HomeView(game: game)
    }
}

/// A finished set's moment: the item that completed it (which names the
/// set). Its jar waits in the wardrobe until collected.
/// Grandma's speech bubble on the home screen: just above her head, its
/// tail pointing down at her, and kept inside the screen's edges. Placed
/// from her measured frame (in the home screen's space), so it follows her
/// on every screen size.
private struct GrandmaBubble: View {
    let text: String
    let granny: CGRect

    /// The widest a bubble gets (SpeechBubble wraps the text to fit).
    private let maxWidth: CGFloat = 260
    private let margin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            // Her head, as a share of the granny picture: the middle of her
            // face across, the top of her hair down.
            // (Until she's been measured, the top middle of the screen.)
            let head = granny == .zero
                ? CGPoint(x: proxy.size.width / 2, y: 120)
                : CGPoint(x: granny.minX + granny.width * 0.45, y: granny.minY + granny.height * 0.03)
            let x = min(max(head.x, margin + maxWidth / 2), proxy.size.width - margin - maxWidth / 2)
            // A strip as wide as the widest bubble, its bottom where the tail
            // ends: the bubble hangs from it, growing upwards with longer
            // lines. (A zero-width spot would squeeze the text to nothing.)
            Color.clear
                .frame(width: maxWidth, height: 1)
                .overlay(alignment: .bottom) {
                    SpeechBubble(text: text, tailOffset: head.x - x)
                        // As tall as the text needs: the strip it hangs from
                        // is only a point high, and without this the text
                        // was squeezed to one line ending in "…".
                        .fixedSize(horizontal: false, vertical: true)
                }
                .position(x: x, y: head.y)
        }
    }
}

/// Where the wardrobe is in its swap: tilt in degrees, and how far right
/// it has moved, in wardrobe widths.
private struct WardrobeSwap {
    var degrees = 0.0
    var offset: CGFloat = 0
}

private struct SetPrize: Equatable {
    let item: KnitItem
}

/// An opened jar's helpers, in the order they fly.
private struct PrizeFlight: Equatable {
    let id = UUID()
    /// The top of the jar when it opened.
    let start: CGPoint
    let faces: [HelperFace]
}

/// In the Play button's place once every level on the phone is played: what
/// getting more is doing. Kept small and quiet: it's a note, not an error.
private struct OutOfLevelsNote: View {
    let status: NextPackStatus
    let height: CGFloat
    let retry: () -> Void

    var body: some View {
        Group {
            switch status {
            case .needsInternet:
                // A tap tries again, for a player who just got a connection
                // and doesn't want to reopen the app.
                Button(action: retry) {
                    Label("Connect to the internet to load new levels", systemImage: "wifi.slash")
                }
                .buttonStyle(.plain)
            case .idle, .loading:
                // Idle only for a moment: running out starts the download.
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading new levels…")
                }
            case .noneYet:
                Text("More puzzles soon!")
            }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Theme.ink)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: height)
        // A light backing, so the note reads on any part of the room picture.
        .background(Capsule().fill(Theme.background.opacity(0.9)))
    }
}
