import SwiftUI

/// What comes out of an opened jar, on the home screen itself: the cats
/// and grandmas pop up above the jar, then fly one by one, trailing
/// sparkles, to their counters at the top left. Each landing adds one to
/// its counter (HomeView keeps the counter one behind per ball still in
/// the air), so the player sees every helper arrive.
///
/// The prize is already saved when this plays (Game.openJar); this is only
/// the reveal. A tap anywhere lands the rest at once: players see it every
/// day, and a show that can't be hurried turns into a wait. With Reduce
/// Motion the helpers land straight away and the counters simply count up.
struct JarPrizeFlight: View {
    /// What came out, in landing order.
    let faces: [HelperFace]
    /// Where they pop up from: the top of the jar, in this view's space.
    let start: CGPoint
    /// Where each kind lands: its counter, in this view's space.
    let target: (HelperFace) -> CGPoint
    let onLanded: (HelperFace) -> Void
    let onFinished: () -> Void

    @State private var popped = false
    /// Helpers on their way, and helpers arrived (and gone from here).
    @State private var flying: Set<Int> = []
    @State private var landed: Set<Int> = []
    @State private var isDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tokenSize: CGFloat = 46
    private let flightSeconds = 0.5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Catches a tap anywhere to skip ahead, and keeps the rest of
                // home from being tapped mid-flight.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: landAll)
                    .accessibilityHidden(true)

                ForEach(faces.indices, id: \.self) { index in
                    if !landed.contains(index) {
                        RewardToken(face: faces[index], size: tokenSize)
                            .scaleEffect(popped ? 1 : 0.2)
                            .opacity(popped ? 1 : 0)
                            .modifier(FlightPath(
                                progress: flying.contains(index) ? 1 : 0,
                                from: popPoint(index, width: proxy.size.width),
                                to: target(faces[index])
                            ))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .task { await play() }
    }

    /// Side by side just above the jar, kept on screen even when there are
    /// several and the jar is near the edge.
    private func popPoint(_ index: Int, width: CGFloat) -> CGPoint {
        let spacing = tokenSize + 8
        let rowWidth = CGFloat(faces.count - 1) * spacing
        let margin = tokenSize / 2 + 12
        let firstX = min(max(start.x - rowWidth / 2, margin), max(margin, width - margin - rowWidth))
        return CGPoint(x: firstX + CGFloat(index) * spacing, y: start.y - tokenSize * 0.9)
    }

    private var accessibilityText: Text {
        let cats = faces.filter { $0 == .cat }.count
        let grandmas = faces.count - cats
        return Text("Cat hints: \(cats). Grandma helpers: \(grandmas).")
    }

    // MARK: - The sequence

    private func play() async {
        guard !reduceMotion else {
            landAll()
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { popped = true }
        // A beat to see what came out before it flies.
        guard await pause(0.6) else { return }

        for index in faces.indices {
            withAnimation(.easeIn(duration: flightSeconds)) { _ = flying.insert(index) }
            guard await pause(flightSeconds) else { return }
            land(index)
        }
        finish()
    }

    private func land(_ index: Int) {
        guard !landed.contains(index) else { return }
        landed.insert(index)
        onLanded(faces[index])
    }

    /// Everything still to come lands now (a tap, or Reduce Motion).
    private func landAll() {
        guard !isDone else { return }
        for index in faces.indices { land(index) }
        finish()
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        onFinished()
    }

    /// Waits, and says whether to carry on: false if the player skipped
    /// ahead meanwhile (or the view went away).
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled && !isDone
    }
}

/// Moves a helper along a curve from above the jar to its counter, with a
/// tail of sparkles where it was a moment ago.
///
/// Animatable, so SwiftUI hands it every in-between `progress` while the
/// flight animates: that's what lets the tail follow the same curve, which
/// a plain position animation (a straight line between two points) can't.
private struct FlightPath: ViewModifier, Animatable {
    var progress: Double
    let from: CGPoint
    let to: CGPoint

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let sparkles = 6
    /// How far behind each sparkle is, as a share of the flight.
    private static let sparkleGap = 0.045

    func body(content: Content) -> some View {
        ZStack {
            if progress > 0, progress < 1 {
                ForEach(1...Self.sparkles, id: \.self) { step in
                    let behind = progress - Double(step) * Self.sparkleGap
                    if behind > 0 {
                        let fade = 1 - Double(step) / Double(Self.sparkles + 1)
                        Image(systemName: "sparkle")
                            .font(.system(size: 16 - CGFloat(step) * 1.5, weight: .bold))
                            .foregroundStyle(Theme.sparkle)
                            .opacity(fade)
                            .position(point(at: behind))
                    }
                }
            }
            content
                // Shrinks on the way, to about the counter's own face size.
                .scaleEffect(1 - 0.45 * progress)
                .position(point(at: progress))
        }
    }

    /// A curve that rises first and then sweeps across to the counter, so
    /// the helper seems thrown up out of the jar rather than slid.
    private func point(at t: Double) -> CGPoint {
        let control = CGPoint(x: from.x, y: to.y)
        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
            y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
        )
    }
}

/// One cat or grandma out of a jar, styled like the level's helper buttons
/// so the player recognises what they got.
struct RewardToken: View {
    let face: HelperFace
    var size: CGFloat = 54

    var body: some View {
        HelperFaceImage(face: face, size: size * 0.92)
            .frame(width: size, height: size)
            // The same soft orange glow as the level's helper buttons.
            .background(Circle().fill(Theme.surface).shadow(color: Theme.primary.opacity(0.45), radius: 6, y: 2))
    }
}
