import SwiftUI
import ArrowwordCore
import Foundation

/// Knitting, played on the home screen itself (it replaced a separate
/// knitting card): a ball of the item's yarn spins on grandma's lap while
/// she rocks (HomeStage rocks her while `onKnittingDone` hasn't been
/// called), the finished piece pops up above her, then flies off to the
/// wardrobe and vanishes in a burst of sparkles.
///
/// The item is already knitted and saved before this plays; it's only the
/// reveal, so closing the app halfway loses nothing. A tap anywhere skips
/// to the end, like the jar's flight: it plays after every knit, and a show
/// that can't be hurried turns into a wait. With Reduce Motion the piece
/// simply appears for a moment.
struct KnittingOnStage: View {
    let item: KnitItem
    /// Grandma's lap, where the yarn ball spins, in this view's space.
    let lap: CGPoint
    /// The wardrobe's door, where the piece goes.
    let wardrobe: CGPoint
    /// The knitting part is over: grandma can stop rocking.
    let onKnittingDone: () -> Void
    let onDone: () -> Void

    private enum Phase { case knitting, shown, flying, arrived }

    @State private var phase = Phase.knitting
    @State private var ballShown = false
    @State private var spin = 0.0
    @State private var isDone = false
    @State private var feedback: FeedbackSignal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ballSize: CGFloat = 44
    private let itemSize: CGFloat = 92
    private let knittingSeconds = 1.8
    private let flightSeconds = 0.7

    /// Above grandma's lap, where the finished piece is held up to see.
    private var shownPoint: CGPoint { CGPoint(x: lap.x, y: lap.y - itemSize * 0.9) }

    var body: some View {
        ZStack {
            // Catches a tap anywhere to skip, and keeps the rest of home from
            // being tapped meanwhile.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: finish)
                .accessibilityHidden(true)

            if phase == .knitting {
                YarnBall(color: item.color, size: ballSize)
                    .rotationEffect(.degrees(spin))
                    .scaleEffect(ballShown ? 1 : 0.2)
                    .opacity(ballShown ? 1 : 0)
                    .position(lap)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if phase == .shown || phase == .flying {
                GarmentView(item: item, size: itemSize)
                    .shadow(color: item.color.tint.opacity(0.45), radius: 12, y: 6)
                    .modifier(FlightPath(progress: phase == .flying ? 1 : 0, from: shownPoint, to: wardrobe))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if phase == .arrived {
                SparkleBurst()
                    .position(wardrobe)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Knitting the \(item.displayName.lowercased(with: .appLanguage))…"))
        .gameFeedback(feedback)
        .task { await play() }
    }

    // MARK: - The sequence

    private func play() async {
        guard !reduceMotion else {
            onKnittingDone()
            withAnimation(.easeInOut(duration: 0.25)) { phase = .shown }
            feedback = FeedbackSignal(event: .itemKnitted, id: 1)
            guard await pause(1.2) else { return }
            finish()
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { ballShown = true }
        // Three turns while grandma knits: the yarn running off the ball.
        withAnimation(.linear(duration: knittingSeconds)) { spin = 1080 }
        guard await pause(knittingSeconds) else { return }

        onKnittingDone()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { phase = .shown }
        // The success buzz and jingle land with the reveal, not with the tap on Knit.
        feedback = FeedbackSignal(event: .itemKnitted, id: 1)
        // A beat to admire it.
        guard await pause(1.0) else { return }

        withAnimation(.easeIn(duration: flightSeconds)) { phase = .flying }
        guard await pause(flightSeconds) else { return }

        phase = .arrived
        guard await pause(SparkleBurst.seconds) else { return }
        finish()
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        onKnittingDone()
        onDone()
    }

    /// Waits, and says whether to carry on: false if the player skipped
    /// ahead meanwhile (or the view went away).
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled && !isDone
    }
}

/// Sparkles bursting outwards and fading, where something vanishes into
/// the wardrobe.
private struct SparkleBurst: View {
    static let seconds = 0.6
    private static let count = 8

    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { index in
                let angle = Angle.degrees(Double(index) / Double(Self.count) * 360)
                Image(systemName: "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 12, weight: .bold))
                    .foregroundStyle(Theme.sparkle)
                    .offset(x: burst ? cos(angle.radians) * 44 : 0, y: burst ? sin(angle.radians) * 44 : 0)
                    .scaleEffect(burst ? 0.4 : 1)
                    .opacity(burst ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: Self.seconds)) { burst = true }
        }
    }
}
