import SwiftUI
import AdKit

/// The banner under the level. Its height is reserved whether or not an ad
/// shows, so the grid never jumps when one arrives; the divider keeps it
/// apart from the buttons to avoid accidental taps.
struct BannerAdSlot: View {
    /// Nil in previews; the slot then shows its placeholder.
    @Environment(AdsController.self) private var ads: AdsController?

    private let bannerSize = AdBannerSize.standard

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if let banner = ads?.bannerView(size: bannerSize) {
                    banner
                } else {
                    placeholder
                }
            }
            .frame(width: bannerSize.size.width, height: bannerSize.size.height)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
    }

    /// While no ad can show (before consent, or consent declined). Debug
    /// builds draw the slot so the layout can be checked; players just see
    /// the reserved space.
    @ViewBuilder
    private var placeholder: some View {
        #if DEBUG
        Text("Ad · 320 × 50")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondaryInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.adPlaceholderFill))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.adPlaceholderBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .accessibilityHidden(true)
        #else
        Color.clear
            .accessibilityHidden(true)
        #endif
    }
}
