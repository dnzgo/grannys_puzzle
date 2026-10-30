import SwiftUI

/// A soft diagonal band of light that crosses its area from left to right,
/// then rests, over and over: a glint that catches the eye without blinking
/// at the player. Used on the trophy and the level button; the caller masks
/// it to the shape it shines on (the trophy's outline, the button's capsule),
/// so the light only crosses that.
///
/// Fills whatever space it's given, so it works on a square trophy and a
/// wide button alike. Callers leave it out with Reduce Motion.
struct ShineSweep: View {
    /// The pause between glints, and how long one takes to cross.
    var restSeconds = 2.6
    var sweepSeconds = 0.8

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            LinearGradient(
                colors: [.clear, .white.opacity(0.8), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            // A band a little over half as wide as the area is tall (the
            // same look on a trophy and a button), tall enough to stay
            // whole when tilted.
            .frame(width: size.height * 0.55, height: max(size.width, size.height) * 1.5)
            .rotationEffect(.degrees(20))
            // Waits off to the left, sweeps across, and starts again: it jumps
            // back while off the area, where it can't be seen.
            .keyframeAnimator(initialValue: -1.0, repeating: true) { content, position in
                content.offset(x: position * (size.width / 2 + size.height))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-1, duration: restSeconds)
                    CubicKeyframe(1, duration: sweepSeconds)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
