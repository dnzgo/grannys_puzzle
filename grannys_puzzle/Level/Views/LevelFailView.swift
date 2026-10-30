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
            // On the same floor as the celebration, so the two endings
            // look like one place.
            ZStack(alignment: .bottom) {
                StageFloor(width: 220)
                ContactShadow(width: 90)
                    .padding(.bottom, StageFloor.height / 2 - 4)
                SadCat(size: 140)
                    .padding(.bottom, StageFloor.height / 2)
            }
            .frame(height: 170)
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

/// The cat when a level didn't pass: sitting, ears down, looking up a bit
/// sheepish ("oh no, let's try again"), with a slow sigh. Gently
/// disappointed rather than upset: a fail is when players are most likely
/// to quit, and a crying cat would make them feel guilty.
///
/// Self-contained like CatCelebration, for the same reason.
struct SadCat: View {
    let size: CGFloat

    @State private var sighing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("cat-sad")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
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
