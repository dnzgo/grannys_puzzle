import SwiftUI
import StoreKit
import ArrowwordCore

/// The level screen, top to bottom: clue bar, grid, letter tray, action
/// row, banner ad slot.
struct LevelScreen: View {
    let model: LevelViewModel

    /// Whether the settings card is up. Plain view state, not the view
    /// model's: opening settings doesn't change the puzzle, and the level
    /// carries on underneath exactly as it was.
    @State private var showsSettings = false
    /// Where the lesson's tap targets are. Only put in the environment for
    /// the tutorial, so real levels don't track any frames.
    @State private var spotlightFrames = SpotlightFrames()
    /// Apple's "Enjoying the game?" prompt (iOS decides whether it shows).
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let metrics = BoardMetrics(
                    width: geometry.size.width - 2 * Theme.sidePadding,
                    height: geometry.size.height,
                    columns: model.level.columns,
                    rows: model.level.rows,
                    opensCloseUp: model.isTutorial
                )
                // The spacing values come from BoardMetrics, which reserves
                // exactly this much height when sizing the cells.
                VStack(spacing: 0) {
                    TopBar(model: model) { showsSettings = true }
                        .padding(.top, BoardMetrics.topBarTopPadding)

                    // The square frame: the board as it is when it fits,
                    // zoomable inside it when it's bigger.
                    BoardViewport(model: model, metrics: metrics)
                        .padding(.top, metrics.gridTopPadding)

                    // Any leftover height is shared equally by three gaps, so
                    // the tray and the helpers sit evenly between the board
                    // and the banner: board to tray, tray to helpers, and
                    // helpers to the banner are always the same.
                    Spacer(minLength: BoardMetrics.minimumSpacer)
                    // Stays after Submit too, locked: the level-end card
                    // shows the result, so nothing changes under the dimming.
                    LetterTray(model: model, keyHeight: metrics.trayKeyHeight)
                    Spacer(minLength: BoardMetrics.minimumSpacer)

                    ActionBar(model: model, height: metrics.actionHeight)
                        .overlay(alignment: .top) { grandmaBubble }
                        // Animating on the container lets the bubble fade in and out.
                        .animation(.easeOut(duration: 0.2), value: model.speech.line)
                    Spacer(minLength: BoardMetrics.minimumSpacer)
                }
                .padding(.horizontal, Theme.sidePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // The level's ending and the settings card cover the level but
            // stop at the banner: an ad under a dim layer counts as obscured
            // for AdMob, and the banner shouldn't jump or vanish anyway.
            // The ZStack stays in place while the cards come and go, so the
            // animations can fade them in and out.
            .overlay {
                ZStack {
                    if model.isJudging {
                        // While the board lights up, a tap anywhere skips to
                        // the card (and can't reach the board or Back).
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea(edges: [.top, .horizontal])
                            .onTapGesture(perform: model.skipJudging)
                            .accessibilityHidden(true)
                    }
                    levelEnd
                    if showsSettings {
                        SettingsCard(context: .level(restart: restartOption)) { showsSettings = false }
                            .transition(.opacity)
                    }
                    if model.confirmsLeavingDaily {
                        LeaveDailyCard(
                            onKeepPlaying: model.keepPlayingDaily,
                            onLeave: { withAnimation(.easeInOut(duration: 0.25)) { model.leaveDaily() } }
                        )
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: model.showsLevelEnd)
                .animation(.easeOut(duration: 0.2), value: showsSettings)
                .animation(.easeOut(duration: 0.2), value: model.confirmsLeavingDaily)
            }
            BannerAdSlot()
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if model.isTutorial {
                TutorialOverlay(model: model, frames: spotlightFrames)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.tutorialLine)
        .overlay {
            if model.isOfferingAd {
                AdOfferCard(amount: model.offeredAmount, onChoose: model.watchAd(for:), onCancel: model.cancelAdOffer)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.isOfferingAd)
        // Both the tagged views and the overlay sit inside this space, so
        // their frames line up. Applied after the overlay so it covers it.
        .coordinateSpace(.named(SpotlightFrames.spaceName))
        .environment(model.isTutorial ? spotlightFrames : nil)
        .preferredColorScheme(.light)
        .gameFeedback(model.feedback)
        // After a perfect board, once the celebration has finished and the
        // player has had a moment: a prompt on top of it would cut it short.
        .task(id: model.readyForReviewPrompt) {
            guard model.readyForReviewPrompt else { return }
            try? await Task.sleep(for: ReviewTiming.delayAfterHappyMoment)
            // Gone already (Next level tapped during the pause): no prompt,
            // and nothing recorded, so the chance isn't wasted.
            guard !Task.isCancelled else { return }
            model.reviewPromptRequested()
            requestReview()
        }
    }

    /// After Submit and the judging wave: the celebration on a pass,
    /// grandma's encouragement on a fail, or the daily puzzle's stats. All
    /// on the same panel, over the judged board.
    @ViewBuilder
    private var levelEnd: some View {
        if case .finished(let result) = model.phase, model.showsLevelEnd {
            if let daily = model.dailyResult {
                // The daily has no pass or fail: one go, then its stats.
                DailyResultCard(result: daily, onHome: model.goHome)
                    .transition(.opacity)
            } else if result.passed {
                LevelCompleteView(
                    result: result,
                    yarn: model.earnedYarn,
                    newlyKnittable: model.newlyKnittable,
                    isTutorial: model.isTutorial,
                    onNext: model.continueAfterResult,
                    onHome: model.goHome,
                    onFinished: model.celebrationDidFinish
                )
                .transition(.opacity)
            } else {
                LevelFailView(
                    result: result,
                    isTutorial: model.isTutorial,
                    onTryAgain: model.continueAfterResult,
                    onHome: model.goHome
                )
                .transition(.opacity)
            }
        }
    }

    /// Restart for the settings card; nil where the level can't restart.
    private var restartOption: SettingsCard.LevelRestart? {
        guard model.canRestart else { return nil }
        return SettingsCard.LevelRestart(hasLettersToClear: model.hasLettersToClear, action: model.restartBoard)
    }

    /// Grandma's line floats just above the action row for a moment.
    @ViewBuilder
    private var grandmaBubble: some View {
        if let line = model.speech.line {
            SpeechBubble(text: line)
                .alignmentGuide(.top) { dimensions in dimensions[.bottom] + 10 }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

/// A rounded speech bubble for grandma's lines.
struct SpeechBubble: View {
    let text: String
    /// A tail under the bubble, pointing down at the speaker: how far from
    /// the bubble's middle its tip should be (negative is left). Nil for no
    /// tail, where it's clear enough who's talking.
    var tailOffset: CGFloat?

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                BubbleShape(cornerRadius: 14, tailOffset: tailOffset)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            )
            // Room for the tail, below the text's own frame.
            .padding(.bottom, tailOffset == nil ? 0 : BubbleShape.tailHeight)
            .frame(maxWidth: 260)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The bubble's outline: a rounded rectangle and, optionally, a tail under
/// it. One shape rather than a rectangle with a triangle on top, so the fill
/// and the shadow run round both without a seam where they meet.
struct BubbleShape: Shape {
    static let tailHeight: CGFloat = 12
    private static let tailBase: CGFloat = 20

    let cornerRadius: CGFloat
    let tailOffset: CGFloat?

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        guard let tailOffset else { return path }
        // The tail's root stays on the straight part of the bottom edge (a
        // short line may be narrower than the speaker is far away); its tip
        // leans the rest of the way, so it still points at them.
        let reach = max(0, rect.width / 2 - cornerRadius - Self.tailBase / 2)
        let root = rect.midX + min(max(tailOffset, -reach), reach)
        let tipX = min(max(rect.midX + tailOffset, root - Self.tailBase), root + Self.tailBase)
        path.move(to: CGPoint(x: root - Self.tailBase / 2, y: rect.maxY - 1))
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: rect.maxY + Self.tailHeight),
            control: CGPoint(x: root - Self.tailBase / 4, y: rect.maxY + Self.tailHeight * 0.4)
        )
        path.addQuadCurve(
            to: CGPoint(x: root + Self.tailBase / 2, y: rect.maxY - 1),
            control: CGPoint(x: root + Self.tailBase / 6, y: rect.maxY + Self.tailHeight * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    if let game = Game.preview() {
        let _ = game.play()
        GameView(game: game)
    } else {
        Text("\(LevelLoader.firstPackName(for: LevelLoader.fallbackLanguage)).json is missing from the app bundle")
    }
}
