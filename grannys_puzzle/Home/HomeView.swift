import SwiftUI
import Combine
import StoreKit
import AdKit
import ArrowwordCore

/// The home screen: grandma in her armchair with the cat, the treat jar and
/// the yarn bag around her, and the Play button.
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
    /// The jar opening being shown, if any.
    @State private var jarOpening: JarOpening?
    /// Grandma is asking whether she may send reminders.
    @State private var asksAboutReminders = false
    /// Today as a `JarDay` number. Kept as state and refreshed at midnight
    /// and when the app returns to the foreground, so the jar wakes up
    /// without the player having to relaunch.
    @State private var today = JarDay.number()
    @Environment(\.scenePhase) private var scenePhase
    /// Apple's "Enjoying the game?" prompt (iOS decides whether it shows).
    @Environment(\.requestReview) private var requestReview

    private var jarReady: Bool { game.progress.canOpenJar(today: today) }

    var body: some View {
        VStack(spacing: 0) {
            topRow
                .padding(.horizontal, Theme.sidePadding)
                .padding(.top, 4)

            HomeStage(
                progress: game.progress,
                canKnit: game.canKnitSomething,
                jarReady: jarReady,
                speechLine: speech.line,
                onGranny: { speech.say(GrandmaLines.greeting()) },
                onCat: { speech.say(GrandmaLines.catNapping) },
                onJar: tapJar,
                onYarnBag: { showsYarnBag = true }
            )
            .animation(.easeOut(duration: 0.2), value: speech.line)

            playButton
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showsYarnBag) {
            YarnBagSheet(progress: game.progress, catalog: game.catalog, onKnit: startKnitting)
        }
        .sheet(isPresented: $showsWardrobe) {
            WardrobeSheet(progress: game.progress, catalog: game.catalog)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsSheet(onHowToPlay: {
                withAnimation(.easeInOut(duration: 0.25)) { game.startTutorial() }
            })
        }
        .overlay {
            if let item = knittingItem {
                KnittingMoment(item: item) {
                    knittingItem = nil
                    speech.say(GrandmaLines.knitted)
                    // A finished piece is the other happy moment for asking.
                    if game.mayAskForReview() {
                        Task {
                            try? await Task.sleep(for: ReviewTiming.delayAfterHappyMoment)
                            game.reviewAsked(.itemKnitted)
                            requestReview()
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: knittingItem)
        .overlay {
            if let opening = jarOpening {
                JarMoment(opening: opening, streakLength: DailyJarRules.standard.streakLength) {
                    jarOpening = nil
                    // Right after her jar is the moment the offer means
                    // something: "shall I tell you when the next one's ready?"
                    if game.mayAskAboutReminders { asksAboutReminders = true }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: jarOpening)
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
    }

    private var openingLine: String {
        if game.nextLevelNumber == nil { return GrandmaLines.allLevelsDone }
        if jarReady { return GrandmaLines.jarReady }
        return GrandmaLines.greeting()
    }

    /// Opens today's jar, or reminds the player when it opens next. Like
    /// knitting, the reward is saved first; the moment on screen is the reveal.
    private func tapJar() {
        if let opening = game.openJar(today: today) {
            jarOpening = opening
        } else {
            speech.say(GrandmaLines.jarTomorrow)
        }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            HelperCountChip(face: .cat, count: game.progress.hints, label: "Cat hints")
            HelperCountChip(face: .grandma, count: game.progress.grandmas, label: "Grandma helpers")
            Spacer()
            CircleIconButton(systemName: "hanger", label: "Wardrobe") { showsWardrobe = true }
            CircleIconButton(systemName: "gearshape", label: "Settings") { showsSettings = true }
        }
        .frame(height: BoardMetrics.topBarHeight)
    }

    /// Closes grandma's card first, so on a yes iOS's own prompt appears
    /// over the home screen rather than over her question.
    private func answerReminderQuestion(yes: Bool) {
        asksAboutReminders = false
        Task { await game.answerReminderQuestion(yes: yes) }
    }

    /// Knitting is saved first; the moment on screen is only the reveal.
    private func startKnitting(_ item: KnitItem) {
        if game.knit(item) {
            knittingItem = item
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if let number = game.nextLevelNumber {
            PrimaryButton(title: "Level \(number)", height: 60) {
                withAnimation(.easeInOut(duration: 0.25)) { game.play() }
            }
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
    let jarReady: Bool
    let speechLine: String?
    let onGranny: () -> Void
    let onCat: () -> Void
    let onJar: () -> Void
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

                JarView(width: side * 0.17, isReady: jarReady, action: onJar)
                    .position(at(0.82, 0.92))

                if let speechLine {
                    SpeechBubble(text: speechLine)
                        .position(at(0.5, 0.12))
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
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

/// The daily treat jar, with an "Open!" tag while today's treat is waiting.
/// Later: a gentle idle wobble when ready, and a real open animation.
private struct JarView: View {
    let width: CGFloat
    let isReady: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("jar").resizable().scaledToFit().frame(width: width)
                .overlay(alignment: .top) {
                    if isReady { NudgeTag(text: "Open!").offset(y: -width * 0.32) }
                }
        }
        .buttonStyle(SceneButtonStyle())
        .accessibilityLabel("Treat jar")
        .accessibilityHint(isReady ? Text("Today's treat is waiting") : Text("Opens again tomorrow"))
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
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            HelperFaceImage(face: face, size: 26)
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
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
