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
    @State private var showsSettings = false
    /// The item whose knitting moment is playing, if any.
    @State private var knittingItem: KnitItem?
    /// A finished set's prize, waiting for the knitting moment to end.
    @State private var pendingSetPrize: SetPrize?
    /// The set prize being shown, if any.
    @State private var setPrize: SetPrize?
    /// The daily treats card is up.
    @State private var showsStreak = false
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
    /// Where the jar and the counters are, for the prize's flight.
    @State private var jarFrame = CGRect.zero
    @State private var counterFrames: [HelperFace: CGRect] = [:]
    @State private var haptic: HapticSignal?
    @State private var hapticCount = 0
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

            HomeStage(
                progress: game.progress,
                canKnit: game.canKnitSomething,
                jarCount: game.progress.jars.count,
                jarShakes: jarShakes,
                speechLine: speech.line,
                onGranny: { speech.say(GrandmaLines.greeting()) },
                onCat: { speech.say(GrandmaLines.catNapping) },
                onJar: tapJar,
                onJarFrame: { jarFrame = $0 },
                onYarnBag: { showsYarnBag = true }
            )
            .animation(.easeOut(duration: 0.2), value: speech.line)
            // Like the settings button, but on the right of the scene rather
            // than in the top row, beside where the jars appear.
            .overlay(alignment: .topTrailing) {
                StreakButton(hasJarWaiting: dailyJarReady) { showsStreak = true }
                    .padding(.trailing, Theme.sidePadding)
                    .padding(.top, 8)
            }

            playButton
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        // Applied before the flight's overlay, so the overlay shares this
        // space and the jar's and counters' frames are its own coordinates.
        .coordinateSpace(.named(Self.space))
        .overlay {
            if let flight {
                JarPrizeFlight(
                    faces: flight.faces,
                    start: flight.start,
                    target: counterPoint,
                    onLanded: prizeLanded,
                    onFinished: { self.flight = nil }
                )
            }
        }
        .preferredColorScheme(.light)
        .gameHaptics(haptic)
        .sheet(isPresented: $showsYarnBag) {
            YarnBagSheet(progress: game.progress, catalog: game.catalog, onKnit: startKnitting)
        }
        .sheet(isPresented: $showsWardrobe) {
            WardrobeSheet(progress: game.progress, catalog: game.catalog)
        }
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
            if let item = knittingItem {
                KnittingMoment(item: item) {
                    knittingItem = nil
                    // A finished set has its own moment before grandma speaks.
                    if let prize = pendingSetPrize {
                        pendingSetPrize = nil
                        setPrize = prize
                    } else {
                        afterKnitting()
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: knittingItem)
        .overlay {
            if let prize = setPrize {
                SetPrizeMoment(items: game.catalog.itemsInSet(of: prize.item)) {
                    setPrize = nil
                    afterKnitting()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: setPrize)
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
            if asksAboutReminders {
                ReminderAskCard(
                    onYes: { answerReminderQuestion(yes: true) },
                    onNotNow: { answerReminderQuestion(yes: false) }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: asksAboutReminders)
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
            showStreakIfFirstVisitToday()
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
        .onChange(of: today) { showStreakIfFirstVisitToday() }
    }

    private var openingLine: String {
        if game.nextLevelNumber == nil { return GrandmaLines.allLevelsDone }
        if dailyJarReady { return GrandmaLines.jarReady }
        return GrandmaLines.greeting()
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
        guard !isOpeningJar, flight == nil, !game.progress.jars.isEmpty else { return }
        isOpeningJar = true
        if !reduceMotion { jarShakes += 1 }
        feel(.jarShaken)
        // Taken now: when the last jar opens, the jar shrinks away and its
        // frame changes while the helpers are still popping out of it.
        let start = CGPoint(x: jarFrame.midX, y: jarFrame.minY)
        Task {
            defer { isOpeningJar = false }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.5))
            guard let jar = game.openJar() else { return }
            // Set in the same update as the save, so the counters never
            // show the new totals before the helpers arrive.
            unlanded = [.cat: jar.reward.hints, .grandma: jar.reward.grandmas]
            feel(.jarOpened)
            flight = PrizeFlight(
                start: start,
                faces: Array(repeating: HelperFace.cat, count: jar.reward.hints)
                    + Array(repeating: HelperFace.grandma, count: jar.reward.grandmas)
            )
        }
    }

    private func prizeLanded(_ face: HelperFace) {
        unlanded[face] = max(0, unlanded[face, default: 0] - 1)
        landings[face, default: 0] += 1
        feel(.prizeLanded)
    }

    /// Where a helper lands: on its counter's face.
    private func counterPoint(for face: HelperFace) -> CGPoint {
        guard let frame = counterFrames[face] else { return .zero }
        return CGPoint(x: frame.minX + 25, y: frame.midY)
    }

    /// What a counter shows: the player's helpers, less any still flying.
    private func shownCount(of face: HelperFace) -> Int {
        let owned = face == .cat ? game.progress.hints : game.progress.grandmas
        return owned - unlanded[face, default: 0]
    }

    private func feel(_ event: HapticEvent) {
        hapticCount += 1
        haptic = HapticSignal(event: event, id: hapticCount)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            counter(.cat, label: "Cat hints")
            counter(.grandma, label: "Grandma helpers")
            Spacer()
            CircleIconButton(systemName: "hanger", label: "Wardrobe") { showsWardrobe = true }
            CircleIconButton(systemName: "gearshape", label: "Settings") { showsSettings = true }
        }
        .frame(height: BoardMetrics.topBarHeight)
    }

    private func counter(_ face: HelperFace, label: LocalizedStringKey) -> some View {
        // Copied into a local so the geometry closure, which SwiftUI may run
        // off the main actor, captures a plain string (as in Spotlight).
        let space = Self.space
        return HelperCountChip(face: face, count: shownCount(of: face), bumps: landings[face, default: 0], label: label)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(space))
            } action: { frame in
                counterFrames[face] = frame
            }
    }

    /// A sheet, card or moment is up, which grandma's question and the
    /// streak card mustn't cover.
    private var isShowingSomethingElse: Bool {
        showsYarnBag || showsWardrobe || showsSettings || showsStreak || asksAboutReminders
            || isOpeningJar || flight != nil || knittingItem != nil || setPrize != nil
    }

    /// Closes grandma's card first, so on a yes iOS's own prompt appears
    /// over the home screen rather than over her question.
    private func answerReminderQuestion(yes: Bool) {
        asksAboutReminders = false
        Task { await game.answerReminderQuestion(yes: yes) }
    }

    /// Knitting (and any set prize) is saved first; the moments on screen
    /// are only the reveal.
    private func startKnitting(_ item: KnitItem) {
        guard let report = game.knit(item) else { return }
        pendingSetPrize = report.earnedSetJar ? SetPrize(item: item) : nil
        knittingItem = item
    }

    /// Grandma's comment once the knitting (and any set prize) is shown,
    /// and, a finished piece being a happy moment, maybe the rating prompt.
    private func afterKnitting() {
        speech.say(GrandmaLines.knitted)
        guard game.mayAskForReview() else { return }
        Task {
            try? await Task.sleep(for: ReviewTiming.delayAfterHappyMoment)
            game.reviewAsked(.itemKnitted)
            requestReview()
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if let number = game.nextLevelNumber {
            PrimaryButton(title: "Level \(number)", height: 60) {
                withAnimation(.easeInOut(duration: 0.25)) { game.play() }
            }
            // Not while a jar is shaking open: leaving then would open it
            // with nobody watching. (The flight itself blocks taps.)
            .disabled(isOpeningJar)
        } else {
            Text("More puzzles soon!")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .overlay(Capsule().strokeBorder(Theme.secondary, lineWidth: 2))
        }
    }
}

// MARK: - The stage

/// Grandma's corner, laid out on a square-ish "stage" that scales with the
/// screen. Positions are fractions of the stage size, so the scene keeps its
/// composition from an iPhone SE to a Pro Max.
private struct HomeStage: View {
    let progress: PlayerProgress
    let canKnit: Bool
    /// Unopened jars; the jar is only on the stage while there's one.
    let jarCount: Int
    let jarShakes: Int
    let speechLine: String?
    let onGranny: () -> Void
    let onCat: () -> Void
    let onJar: () -> Void
    /// Reports where the jar is, for the prize's flight.
    let onJarFrame: (CGRect) -> Void
    let onYarnBag: () -> Void

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
                // Back to front, like layers of a painting: the bag tucked
                // half behind the armchair's right side, grandma, the cat's
                // bed just in front of the chair's left side, and the jar on
                // the floor at the front (it moves to a coffee table later).
                Ellipse()
                    .fill(Theme.clueCell)
                    .frame(width: side * 0.95, height: side * 0.24)
                    .position(at(0.5, 0.88))

                // Its bottom stays on the same floor line as the chair's feet.
                YarnBagView(progress: progress, canKnit: canKnit, width: side * 0.25, action: onYarnBag)
                    .position(at(0.8, 0.705))

                GrannyView(width: side * 0.6, action: onGranny)
                    .position(at(0.5, 0.52))

                CatBedView(width: side * 0.34, action: onCat)
                    .position(at(0.31, 0.8))

                if jarCount > 0 {
                    JarView(width: side * 0.17, count: jarCount, shakes: jarShakes, action: onJar)
                        .onGeometryChange(for: CGRect.self) { [space = HomeView.space] proxy in
                            proxy.frame(in: .named(space))
                        } action: { frame in
                            onJarFrame(frame)
                        }
                        .position(at(0.82, 0.92))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                if let speechLine {
                    SpeechBubble(text: speechLine)
                        .position(at(0.5, 0.12))
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
            // A jar collected pops in; the last one opened shrinks away.
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: jarCount)
        }
    }
}

// MARK: - Characters and props

/// Grandma in her armchair. Later: talking and knitting animations.
private struct GrannyView: View {
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("granny").resizable().scaledToFit().frame(width: width)
                // An oval rather than the image's rectangle, so the empty
                // corners around the armchair don't steal taps meant for
                // the yarn bag tucked behind it.
                .contentShape(Ellipse())
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

/// The unopened treat jars beside grandma's chair, as one jar with an
/// "Open!" tag, and how many there are on its top right once there's more
/// than one. A tap opens one. Later: a real lid-off animation.
private struct JarView: View {
    let width: CGFloat
    let count: Int
    /// Increased to play the shake.
    let shakes: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("jar").resizable().scaledToFit().frame(width: width)
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
                    NudgeTag(text: "Open!").offset(y: -width * 0.32)
                }
                .overlay(alignment: .topTrailing) {
                    if count > 1 { countBadge.offset(x: width * 0.12, y: -width * 0.05) }
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
                // The badge sits on the bag's open top, where the balls are,
                // rather than the image corner, which is empty space.
                .overlay(alignment: .topTrailing) {
                    countBadge.offset(x: -width * 0.08, y: width * 0.1)
                }
                .overlay(alignment: .top) {
                    if canKnit { NudgeTag(text: "Knit!").offset(y: -width * 0.12) }
                }
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Yarn bag")
        .accessibilityValue("\(progress.totalYarn) balls")
        .accessibilityHint(canKnit ? Text("Enough yarn to knit something") : Text(""))
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

/// A small pill showing how many of a helper the player has.
private struct HelperCountChip: View {
    let face: HelperFace
    let count: Int
    /// Increased each time a helper from a jar lands here: a quick bump.
    let bumps: Int
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            HelperFaceImage(face: face, size: 26)
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(count)))
                .animation(.snappy, value: count)
        }
        .keyframeAnimator(initialValue: 1.0, trigger: bumps) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.18, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.3)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
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
/// set). Its jar is already saved with the unopened ones.
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
