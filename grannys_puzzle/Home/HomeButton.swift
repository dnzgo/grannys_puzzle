import SwiftUI

/// The home screen's two big buttons (the level and the daily challenge):
/// filled in the button's own colour (orange to play on, purple for the
/// daily) with a bone-coloured label, larger and heavier than the
/// PrimaryButton used elsewhere, so they hold their own on the room picture.
struct HomeButton: View {
    let title: LocalizedStringKey
    /// The fill.
    let accent: Color
    let height: CGFloat
    /// A glint of light sweeps across it now and then, like the trophy's:
    /// the level button's, so the main way on is the one that catches the eye.
    var shines = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Room kept free on each side of the label inside the capsule, so a
    /// long label never runs into the rounded ends.
    private static let labelInset: CGFloat = 22
    /// How far a long label may shrink to fit on one line: 24pt down to
    /// about 15pt. Below that it would stop looking like a big button.
    private static let smallestScale: CGFloat = 0.62

    var body: some View {
        Button(action: action) {
            // Large and in the heaviest weight: a light label on these fills
            // reads by size and stroke (see Theme.primary's contrast note).
            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Theme.background)
                // One line, shrinking to fit: "Daily challenge done" and
                // its Turkish are longer than "Level 12" and would otherwise
                // wrap or run to the edges.
                .lineLimit(1)
                .minimumScaleFactor(Self.smallestScale)
                .padding(.horizontal, Self.labelInset)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    Capsule()
                        .fill(accent)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                )
                .overlay {
                    if shines && !reduceMotion {
                        // The trophy's glint, across the button, inside its shape.
                        ShineSweep()
                            .clipShape(Capsule())
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 14) {
        HomeButton(title: "Level 12", accent: Theme.primary, height: 54, shines: true) {}
        HomeButton(title: "Daily challenge", accent: Theme.daily, height: 54) {}
        HomeButton(title: "Daily challenge done", accent: Theme.daily, height: 54) {}
    }
    .padding(58)
    .background(Color.gray)
}
