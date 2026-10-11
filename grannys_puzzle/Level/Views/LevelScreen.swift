import SwiftUI
import ArrowwordCore

/// The level screen, top to bottom: clue bar, grid, letter tray (or the
/// result), action row, banner ad slot.
struct LevelScreen: View {
    let model: LevelViewModel

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let metrics = BoardMetrics(
                    width: geometry.size.width - 2 * Theme.sidePadding,
                    height: geometry.size.height,
                    columns: model.level.columns,
                    rows: model.level.rows
                )
                // The spacing values come from BoardMetrics, which reserves
                // exactly this much height when sizing the cells.
                VStack(spacing: 0) {
                    TopBar(model: model)
                        .padding(.top, BoardMetrics.topBarTopPadding)

                    BoardGrid(model: model, metrics: metrics)
                        .padding(.top, metrics.gridTopPadding)

                    // Any leftover height goes around the tray as breathing room.
                    Spacer(minLength: BoardMetrics.minimumSpacer)
                    trayOrResult(metrics: metrics)
                    Spacer(minLength: BoardMetrics.minimumSpacer)

                    ActionBar(model: model, height: metrics.actionHeight)
                        .padding(.bottom, BoardMetrics.actionBottomPadding)
                        .overlay(alignment: .top) { grandmaBubble }
                        // Animating on the container lets the bubble fade in and out.
                        .animation(.easeOut(duration: 0.2), value: model.speech.line)
                }
                .padding(.horizontal, Theme.sidePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            BannerAdSlot()
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func trayOrResult(metrics: BoardMetrics) -> some View {
        if case .finished(let result) = model.phase {
            ResultPanel(result: result, earnedYarn: model.earnedYarn)
        } else {
            LetterTray(model: model, keyHeight: metrics.trayKeyHeight)
        }
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

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            )
            .frame(maxWidth: 260)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    if let game = Game.preview() {
        let _ = game.play()
        GameView(game: game)
    } else {
        Text("\(LevelLoader.firstPackName).json is missing from the app bundle")
    }
}
