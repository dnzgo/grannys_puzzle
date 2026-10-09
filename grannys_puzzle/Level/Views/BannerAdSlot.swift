import SwiftUI

/// Placeholder for the banner ad. Its height is reserved whether or not an ad
/// loads, so the grid never jumps; the divider keeps it apart from the buttons
/// to avoid accidental taps. AdMob's banner view replaces the inner box later.
struct BannerAdSlot: View {
    static let adSize = CGSize(width: 320, height: 50)

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Text("Ad · 320 × 50")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryInk)
                .frame(width: Self.adSize.width, height: Self.adSize.height)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xEFEFEB)))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(hex: 0xC9C9C4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
