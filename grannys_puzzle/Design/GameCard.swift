import SwiftUI

/// The game's own card over a dimmed screen: a cream header band with the
/// title and a close button (and a back button on a card's inner pages),
/// and the content under it. Settings and the daily treats card use it.
///
/// Drawn by the game rather than borrowed from iOS (a sheet, an alert), so
/// every card looks like Granny's Puzzle and not like the system.
///
/// Placed over the level, it must sit in the area above the banner ad (see
/// LevelScreen), so the dimming never covers the ad.
struct GameCard<Content: View>: View {
    let title: LocalizedStringKey
    /// Shows a back button; nil on a card's first page.
    let onBack: (() -> Void)?
    let onClose: () -> Void
    private let content: Content

    init(
        title: LocalizedStringKey,
        onBack: (() -> Void)? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onBack = onBack
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Every edge: on home that's the whole screen. In a level the
            // card sits in the area above the banner, which doesn't reach
            // the bottom safe area, so the banner stays clear regardless.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                content
                    .padding(20)
            }
            .frame(maxWidth: 360)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // VoiceOver's two-finger scrub: back a page, or close.
        .accessibilityAction(.escape) {
            if let onBack { onBack() } else { onClose() }
        }
    }

    private var header: some View {
        ZStack {
            Text(title)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 52)
                .accessibilityAddTraits(.isHeader)
            HStack {
                if let onBack {
                    headerButton(systemName: "chevron.left", label: "Back", action: onBack)
                }
                Spacer()
                headerButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .background(Theme.clueCell)
    }

    private func headerButton(systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
