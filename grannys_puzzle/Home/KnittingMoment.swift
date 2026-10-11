import SwiftUI
import ArrowwordCore

/// The short scene after the player taps Knit: grandma knits for a moment,
/// then the finished piece appears and goes to the wardrobe.
///
/// The item is already knitted and saved before this shows; the scene is
/// only the reveal. So closing the app mid-animation loses nothing.
///
/// Placeholder motion until the Rive knitting animation exists: grandma
/// rocks gently and a yarn ball bobs beside her. With Reduce Motion on,
/// both stay still.
struct KnittingMoment: View {
    let item: KnitItem
    let onDone: () -> Void

    private enum Phase {
        case knitting
        case finished
    }

    @State private var phase = Phase.knitting
    @State private var rocking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Long enough to read the line and feel the wait, short enough not to drag.
    private let knittingTime: Duration = .seconds(1.8)

    var body: some View {
        ZStack {
            // Dims the home screen and swallows taps behind the scene.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 18) {
                switch phase {
                case .knitting:
                    knitting
                case .finished:
                    finished
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 32)
        }
        .task {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { rocking = true }
            }
            try? await Task.sleep(for: knittingTime)
            // Cancelled means the view went away; nothing left to reveal.
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.45, dampingFraction: 0.6)) {
                phase = .finished
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var knitting: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(decorative: "granny")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (rocking ? 2 : -2)), anchor: .bottom)
                YarnBall(color: item.color, size: 52)
                    .offset(x: 8, y: reduceMotion ? 0 : (rocking ? -6 : 4))
            }
            // "the" reads right for singular and plural (the scarf, the mittens).
            Text("Knitting the \(item.displayName.lowercased())…")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var finished: some View {
        VStack(spacing: 14) {
            GarmentView(kind: item.kind, color: item.color, size: 120)
                .shadow(color: item.color.tint.opacity(0.4), radius: 12, y: 6)
                .accessibilityHidden(true)
            Text("\(item.displayName) for the cat!")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("It's in the wardrobe now.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryInk)
            PrimaryButton(title: "Lovely!", height: 52, action: onDone)
        }
    }
}

#Preview {
    KnittingMoment(item: KnitItem(member: .cat, kind: .scarf, color: .red, cost: 6), onDone: {})
}
