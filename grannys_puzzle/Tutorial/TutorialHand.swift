import SwiftUI
import ArrowwordCore

/// What grandma's hand shows during a lesson step, at points in the
/// overlay's own space. Each motion plays and then repeats until the
/// player does it.
enum HandMotion: Equatable {
    case tap(at: CGPoint)
    /// Two quick taps on one square (switching a word's direction).
    case doubleTap(at: CGPoint)
    /// Points at one thing without pressing, then moves on and taps
    /// another: the clue bar, then the first letter of the word. The
    /// pointing happens once; after that it only repeats the tap.
    case point(at: CGPoint, thenTap: CGPoint)
    /// Fingers apart, then together: zooming out.
    case pinchClosing(at: CGPoint)
    /// Fingers together, then apart (zooming in), then a one-finger slide.
    case pinchOpeningThenSlide(at: CGPoint, from: CGPoint, to: CGPoint)

    /// The same motion moved, to change coordinate spaces.
    func offsetBy(dx: CGFloat, dy: CGFloat) -> HandMotion {
        func move(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + dx, y: point.y + dy) }
        switch self {
        case .tap(let point): return .tap(at: move(point))
        case .doubleTap(let point): return .doubleTap(at: move(point))
        case .point(let first, let then): return .point(at: move(first), thenTap: move(then))
        case .pinchClosing(let point): return .pinchClosing(at: move(point))
        case .pinchOpeningThenSlide(let point, let from, let to):
            return .pinchOpeningThenSlide(at: move(point), from: move(from), to: move(to))
        }
    }
}

/// What makes the hand start its motion from the beginning: a new step,
/// a new thing to point at, or the first letter typed. Its points alone
/// don't, since they move with the board as it slides.
struct HandKey: Hashable {
    let step: Int?
    let target: TutorialTarget?
    let visitsClueBar: Bool
}

/// Grandma's hand, playing a `HandMotion` over the lesson's dimming. It
/// never takes touches: the player's own fingers go through it.
///
/// The motion is worked out from the time since it started, frame by
/// frame (`HandMotion.pose(at:)`), rather than with SwiftUI animations.
/// What it points at can move under it (the board slides and zooms), and a
/// pose computed fresh each frame follows that, where an animation would
/// keep heading for where the thing was when it started.
struct TutorialHand: View {
    let motion: HandMotion
    let restartKey: HandKey

    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let pose = motion.pose(at: context.date.timeIntervalSince(start), reduceMotion: reduceMotion)
            HandArtwork(pose: pose)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: restartKey) { start = .now }
    }
}

// MARK: - The motion, frame by frame

/// Where the hand is and how it looks at one moment.
struct HandPose: Equatable {
    enum Art: Equatable {
        case pointing
        /// The pinch, `closed` from 0 (fingers apart) to 1 (together).
        case pinch(closed: Double)
    }

    var art: Art
    /// The fingertip (pointing) or the point between the fingers (pinch).
    var location: CGPoint
    /// How far the fingertip is pressed in, 0 to 1.
    var press: Double = 0
    var opacity: Double
}

extension HandMotion {
    /// The whole motion's length; it then starts over.
    var period: TimeInterval {
        switch self {
        case .tap: 2.0
        case .doubleTap: 2.4
        case .point: 3.4
        case .pinchClosing: 2.4
        case .pinchOpeningThenSlide: 4.4
        }
    }

    /// The hand `elapsed` seconds into the motion. With Reduce Motion it
    /// still shows the gesture (presses and the pinch's two poses) but
    /// doesn't glide from place to place.
    func pose(at elapsed: TimeInterval, reduceMotion: Bool = false) -> HandPose {
        let time = elapsed.truncatingRemainder(dividingBy: period)
        // The hand comes in from below and to the right, the way its wrist
        // points, so it never crosses what it's pointing at.
        let approach = reduceMotion ? CGSize.zero : CGSize(width: 36, height: 44)

        switch self {
        case .tap(let point):
            return pointing(at: point, time: time, presses: [0.35], approach: approach, leaveAt: 1.4)

        case .doubleTap(let point):
            return pointing(at: point, time: time, presses: [0.35, 0.65], approach: approach, leaveAt: 1.7)

        case .point(let first, let then):
            // Shown once is enough to say "the clue is up here too";
            // repeated, it would keep pulling the eye away from the keys.
            if elapsed >= period {
                return HandMotion.tap(at: then).pose(at: elapsed - period, reduceMotion: reduceMotion)
            }
            // In and resting on the first point, a glide to the second, a tap.
            let glide = reduceMotion ? 1.0 : Self.ease(time, from: 1.25, to: 1.85)
            let location = Self.mix(first, then, glide)
            var pose = pointing(at: location, time: time, presses: [1.85], approach: approach, leaveAt: 2.9)
            if time < 0.35 { pose.location = Self.mix(Self.offset(first, by: approach), first, Self.ease(time, from: 0, to: 0.35)) }
            return pose

        case .pinchClosing(let point):
            let closed = Self.ease(time, from: 0.5, to: 1.3)
            return HandPose(art: .pinch(closed: closed), location: point, opacity: Self.fade(time, in: 0, out: 1.8))

        case .pinchOpeningThenSlide(let point, let from, let to):
            if time < 2.0 {
                let closed = 1 - Self.ease(time, from: 0.5, to: 1.3)
                return HandPose(art: .pinch(closed: closed), location: point, opacity: Self.fade(time, in: 0, out: 1.7))
            }
            // The slide: pressed down the whole way across, then lifted.
            let local = time - 2.0
            let travel = reduceMotion ? 0 : Self.ease(local, from: 0.25, to: 1.25)
            let press = local < 1.25 ? 1.0 : 1 - Self.ease(local, from: 1.25, to: 1.4)
            return HandPose(
                art: .pointing,
                location: Self.mix(from, to, travel),
                press: press,
                opacity: Self.fade(local, in: 0, out: 1.4)
            )
        }
    }

    /// The pointing finger: in to `point`, pressing at each of `presses`
    /// (each press takes 0.24s), resting, then fading at `leaveAt`.
    private func pointing(at point: CGPoint, time: TimeInterval, presses: [TimeInterval], approach: CGSize, leaveAt: TimeInterval) -> HandPose {
        let arrival = Self.ease(time, from: 0, to: 0.35)
        let location = Self.mix(Self.offset(point, by: approach), point, arrival)
        let press = presses.map { start in
            time < start + 0.12 ? Self.ease(time, from: start, to: start + 0.12) : 1 - Self.ease(time, from: start + 0.12, to: start + 0.24)
        }.max() ?? 0
        return HandPose(art: .pointing, location: location, press: press, opacity: Self.fade(time, in: 0, out: leaveAt))
    }

    // Small timing helpers: `ease` goes 0 → 1 between two times, gently at
    // both ends; `fade` is the opacity of something shown from `in` and
    // fading out over 0.3s from `out`.

    private static func ease(_ time: TimeInterval, from start: TimeInterval, to end: TimeInterval) -> Double {
        let linear = min(1, max(0, (time - start) / (end - start)))
        return linear * linear * (3 - 2 * linear)
    }

    private static func fade(_ time: TimeInterval, in start: TimeInterval, out end: TimeInterval) -> Double {
        ease(time, from: start, to: start + 0.3) * (1 - ease(time, from: end, to: end + 0.3))
    }

    private static func mix(_ first: CGPoint, _ second: CGPoint, _ amount: Double) -> CGPoint {
        CGPoint(x: first.x + (second.x - first.x) * amount, y: first.y + (second.y - first.y) * amount)
    }

    private static func offset(_ point: CGPoint, by size: CGSize) -> CGPoint {
        CGPoint(x: point.x + size.width, y: point.y + size.height)
    }
}

// MARK: - Drawing

/// The hand images, placed so the right spot of the art lands on the
/// pose's location.
///
/// The art (hand-point, hand-pinch-open, hand-pinch-closed) is square,
/// fingertips toward the top-left and the knitted cuff at the bottom-right.
/// The two pinch images line up at the wrist, so swapping them moves only
/// the fingers; they share one placement, anchored where the open fingers'
/// midpoint is.
private struct HandArtwork: View {
    let pose: HandPose

    private static let pointingSize: CGFloat = 76
    private static let pinchSize: CGFloat = 124
    /// The pad of the index finger, as a share of the pointing art.
    private static let fingertip = UnitPoint(x: 0.07, y: 0.07)
    /// Between thumb and index finger of the open pinch.
    private static let pinchCentre = UnitPoint(x: 0.08, y: 0.24)

    var body: some View {
        switch pose.art {
        case .pointing:
            ZStack {
                // A soft ring where the finger presses, so the tap reads
                // even where the hand covers the button.
                Circle()
                    .fill(Theme.primary.opacity(0.35 * pose.press))
                    .frame(width: 34, height: 34)
                    .scaleEffect(0.6 + 0.4 * pose.press)
                    .position(pose.location)
                // Pressing: the hand dips a little toward the screen.
                placed("hand-point", size: Self.pointingSize, anchor: Self.fingertip, scale: 1 - 0.1 * pose.press)
            }
            .opacity(pose.opacity)

        case .pinch(let closed):
            // A swap halfway rather than a cross-fade: two hands half seen
            // at once would read as a blur, not as fingers moving.
            placed(closed < 0.5 ? "hand-pinch-open" : "hand-pinch-closed", size: Self.pinchSize, anchor: Self.pinchCentre, scale: 1)
                .opacity(pose.opacity)
        }
    }

    /// The image with its `anchor` at the pose's location, scaled around
    /// that same point (before placing, while the frame is still the image's).
    private func placed(_ name: String, size: CGFloat, anchor: UnitPoint, scale: CGFloat) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .scaleEffect(scale, anchor: anchor)
            // A light shadow lifts it off the board and the dimming.
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .position(
                x: pose.location.x + (0.5 - anchor.x) * size,
                y: pose.location.y + (0.5 - anchor.y) * size
            )
    }
}
