import SwiftUI
import ArrowwordCore
import Foundation

/// Knitting, played on the home screen itself (it replaced a separate
/// knitting card): a ball of the item's yarn circles grandma while she
/// rocks (HomeStage rocks her while `onKnittingDone` hasn't been
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
    /// Where grandma is, in this view's space: the yarn circles her, and the
    /// finished piece appears above her lap.
    let granny: CGRect
    /// The wardrobe's door, where the piece goes.
    let wardrobe: CGPoint
    /// The knitting part is over: grandma can stop rocking.
    let onKnittingDone: () -> Void
    let onDone: () -> Void

    private enum Phase { case knitting, shown, flying, arrived }

    @State private var phase = Phase.knitting
    @State private var ballShown = false
    /// When the ball started circling; its place follows the clock.
    @State private var orbitStart = Date.now
    @State private var isDone = false
    @State private var feedback: FeedbackSignal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ballSize: CGFloat = 44
    private let itemSize: CGFloat = 92
    private let knittingSeconds = 1.8
    private let turns = 2.0
    private let flightSeconds = 0.7

    /// Her knitting, in the granny picture (measured on the art).
    private var lap: CGPoint {
        CGPoint(x: granny.minX + granny.width * 0.62, y: granny.minY + granny.height * 0.55)
    }
    /// Above her lap, where the finished piece is held up to see.
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
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(orbitStart)
                    let orbit = orbitPlace(turn: min(max(elapsed / knittingSeconds, 0), 1) * turns)
                    YarnBall(color: item.color, size: ballSize)
                        .scaleEffect((ballShown ? 1 : 0.2) * (0.85 + 0.15 * orbit.depth))
                        // Round her back it fades away and comes out again on
                        // the other side: it reads as passing behind her. (This
                        // layer is above the scene, so it can't truly go behind.)
                        .opacity(ballShown ? min(max((orbit.depth + 0.35) / 0.5, 0), 1) : 0)
                        .position(orbit.point)
                }
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .allowsHitTesting(false)
            }

            if phase == .shown || phase == .flying {
                GarmentView(item: item, size: itemSize, showsTile: false)
                    .shadow(color: item.color.tint.opacity(0.45), radius: 12, y: 6)
                    // Shrinking all the way into the wardrobe.
                    .modifier(FlightPath(progress: phase == .flying ? 1 : 0, from: shownPoint, to: wardrobe, endScale: 0.08))
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

        orbitStart = .now
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { ballShown = true }
        // Twice round grandma while she knits.
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

extension KnittingOnStage {
    /// Where the ball is after `turn` circles round grandma, and how near
    /// the viewer (-1 behind her, 1 in front). A flat ellipse round her
    /// middle, tipped a little; it starts in front of her, at her lap's
    /// height, so it appears where the knitting is.
    fileprivate func orbitPlace(turn: Double) -> (point: CGPoint, depth: Double) {
        let center = CGPoint(x: granny.midX, y: granny.minY + granny.height * 0.55)
        let width = granny.width * 0.48
        let depth = granny.height * 0.1
        let angle = Double.pi / 2 + 2 * Double.pi * turn
        let flat = CGPoint(x: width * cos(angle), y: depth * sin(angle))
        let tilt = -12 * Double.pi / 180
        let point = CGPoint(
            x: center.x + flat.x * cos(tilt) - flat.y * sin(tilt),
            y: center.y + flat.x * sin(tilt) + flat.y * cos(tilt)
        )
        return (point, sin(angle))
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
