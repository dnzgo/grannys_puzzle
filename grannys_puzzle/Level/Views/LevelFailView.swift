import SwiftUI
import ArrowwordCore

/// The ending after a level that didn't pass: the same card as a pass, so
/// the two feel like one moment, but quiet. No yarn and no dance, a sad cat,
/// and grandma cheering the player on to try again.
///
/// Nothing to wait for, so it opens complete: a fail is the moment a player
/// is most likely to quit, and a ceremony in their way would make it worse.
struct LevelFailView: View {
    let result: LevelResult
    /// The lesson has a single way on, so no Home.
    let isTutorial: Bool
    let onTryAgain: () -> Void
    let onHome: () -> Void

    /// Picked once: @State keeps its first value for as long as the card is
    /// up, so the line doesn't change while the player is reading it.
    @State private var line = GrandmaLines.encouragement()

    var body: some View {
        LevelEndCard(result: result) {
            SadCat(size: 110)
                .frame(height: 140)
        } footer: {
            LevelEndGrandmaLine(text: line)
            LevelEndButtons(
                primaryTitle: "Try again",
                onPrimary: onTryAgain,
                onHome: isTutorial ? nil : onHome
            )
        }
    }
}

/// The cat when a level didn't pass: head bowed to one side, a little
/// greyer, with a slow sigh.
///
/// A placeholder like CatCelebration, kept self-contained for the same
/// reason: the real sad pose (most likely a state in the same Rive file as
/// the dance) replaces only what's inside.
struct SadCat: View {
    let size: CGFloat

    @State private var sighing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("cat-head")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // Muted rather than grey: a fully grey cat reads as "disabled".
            .saturation(0.7)
            .rotationEffect(.degrees(-12), anchor: .bottom)
            // The sigh: sinking a little and settling back, slower than the
            // celebration's bounce so it feels heavy rather than lively.
            .scaleEffect(x: 1, y: sighing ? 0.96 : 1, anchor: .bottom)
            .offset(y: sighing ? size * 0.04 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    sighing = true
                }
            }
            .accessibilityHidden(true)
    }
}
