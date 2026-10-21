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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Large and in the heaviest weight: a light label on these fills
            // reads by size and stroke (see Theme.primary's contrast note).
            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    Capsule()
                        .fill(accent)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 14) {
        HomeButton(title: "Level 12", accent: Theme.primary, height: 54) {}
        HomeButton(title: "Daily challenge", accent: Theme.daily, height: 54) {}
    }
    .padding(58)
    .background(Color.gray)
}
