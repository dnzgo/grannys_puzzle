import SwiftUI

/// The first screen after iOS's own launch screen, in two steps: the
/// Dengo Labs logo on its own, then the game's logo (granny and the cat)
/// with a bar under it that fills while the cat walks along it.
///
/// It runs for a fixed time rather than following real loading. The game
/// is loaded before the first frame (ContentView's `Startup.load()`), so
/// by now there's nothing left to measure, and a bar pretending to track
/// work would be a lie that only makes the wait feel longer. It's a short
/// hello instead, about three seconds in all.
struct LaunchSplash: View {
    /// Called once, when the bar is full and the cat has had a moment there.
    let onFinished: () -> Void

    /// How long the studio logo shows on its own. Long enough to read the
    /// name, short enough that nobody waits for it.
    static let studioDuration: TimeInterval = 1.0
    /// The cross-fade from the studio logo to the game's.
    static let fadeDuration: TimeInterval = 0.35
    /// How long the bar takes to fill. It starts as the game logo fades in.
    static let fillDuration: TimeInterval = 1.6
    /// How long the full bar stays before the home screen fades in, so the
    /// end reads as "done" instead of being cut off.
    static let pauseAtEnd: TimeInterval = 0.3
    private static let studioLogoWidth: CGFloat = 260
    private static let gameLogoWidth: CGFloat = 300
    private static let barWidth: CGFloat = 220

    @State private var showsGameLogo = false

    var body: some View {
        ZStack {
            if showsGameLogo {
                VStack(spacing: 28) {
                    Image("game-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.gameLogoWidth)
                    // Created here, not at launch, so its clock (and the
                    // cat's walk) starts when it's seen.
                    WalkingCatBar(duration: Self.fillDuration)
                        .frame(width: Self.barWidth)
                }
                .transition(.opacity)
            } else {
                Image("company-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.studioLogoWidth)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The same cream as the logo picture and the launch screen
        // (LaunchBackground), so the three read as one screen.
        .background(Theme.logoBackground.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: showsGameLogo ? "Granny's Puzzle" : "Dengo Labs"))
        .accessibilityValue("Loading")
        .task {
            // A cancelled sleep (the view went away) returns early: then the
            // splash isn't finishing, it's gone, so don't report it.
            try? await Task.sleep(for: .seconds(Self.studioDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: Self.fadeDuration)) { showsGameLogo = true }
            try? await Task.sleep(for: .seconds(Self.fillDuration + Self.pauseAtEnd))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}

/// A loading bar with the cat walking on top of it, at the end of the fill.
///
/// Drawn frame by frame from the time since it appeared (as TutorialHand
/// does), so the bar and the cat's steps come from one clock and can't
/// drift apart.
private struct WalkingCatBar: View {
    let duration: TimeInterval

    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Emoji size: the walk frames are drawn at 96 x 72px, which is exactly
    /// this at 3x.
    private static let catSize = CGSize(width: 32, height: 24)
    private static let frameCount = 8
    /// How far the cat goes in one full stride (all 8 frames). Tied to
    /// distance rather than time, so the legs keep pace with how fast it
    /// moves. Longer than a real cat's stride, a compromise: a true one
    /// would need about 30 frames a second at this speed, a scurry that
    /// reads as jitter; this gives about 15.
    private static let strideLength: CGFloat = 64
    private static let barHeight: CGFloat = 10

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let progress = min(1, max(0, elapsed / duration))
            GeometryReader { proxy in
                let width = proxy.size.width
                let tip = width * progress
                ZStack(alignment: .bottomLeading) {
                    Capsule()
                        .fill(Theme.progressTrack)
                        .frame(height: Self.barHeight)
                    Capsule()
                        .fill(Theme.primary)
                        // At least a circle, so the start is a dot, not a sliver.
                        .frame(width: max(Self.barHeight, tip), height: Self.barHeight)
                    Image(catFrame(distance: tip, isWalking: progress < 1))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: Self.catSize.width, height: Self.catSize.height)
                        // Its front paws at the tip of the fill, standing on the bar.
                        .offset(x: tip - Self.catSize.width * 0.75, y: -Self.barHeight)
                }
            }
            .frame(height: Self.barHeight + Self.catSize.height)
        }
        .accessibilityHidden(true)
    }

    /// The walk frame for how far the cat has come. Standing (frame 1) once
    /// the bar is full, and always with Reduce Motion: the bar still fills,
    /// as that's the progress, but the legs stay still.
    private func catFrame(distance: CGFloat, isWalking: Bool) -> String {
        guard isWalking, !reduceMotion else { return "cat-walk-1" }
        let step = Self.strideLength / CGFloat(Self.frameCount)
        let index = Int(distance / step) % Self.frameCount
        return "cat-walk-\(index + 1)"
    }
}

#Preview {
    LaunchSplash {}
}
