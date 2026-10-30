import SwiftUI
import ArrowwordCore

/// The card both level endings are built on (LevelCompleteView after a
/// pass, LevelFailView after a fail): the level dimmed behind it, then the
/// headline and score, a stage for the cat, and whatever comes under it.
///
/// One card for both, so a pass and a fail read as the same moment with a
/// different mood, and a change to the look lands on both at once.
///
/// Place it over the level content only, not the whole screen: the banner
/// ad below the level must stay clear of the dimming (see LevelScreen).
struct LevelEndCard<Stage: View, Footer: View>: View {
    let result: LevelResult
    private let stage: Stage
    private let footer: Footer

    init(result: LevelResult, @ViewBuilder stage: () -> Stage, @ViewBuilder footer: () -> Footer) {
        self.result = result
        self.stage = stage()
        self.footer = footer()
    }

    var body: some View {
        LevelEndPanel {
            VStack(spacing: 4) {
                Text(result.headline)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(result.scoreLine)
                    .font(.system(size: 14))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }

            stage
            footer
        }
    }
}

/// The panel every card at the end of a board sits on (the level endings
/// and the daily puzzle's stats): the level dimmed behind it and a cream
/// card in the middle, so they all look like the same moment.
struct LevelEndPanel<Content: View>: View {
    private let content: Content
    /// A picture peeking over the card's top edge (the daily's cat): its
    /// flat bottom sits on the edge, overlapping it a little so it looks
    /// like it's leaning on it. Nil for none.
    private let peek: String?

    private static var peekWidth: CGFloat { 160 }
    /// The peeking picture's height for its width (cat-peek is 480 × 412).
    private static var peekHeight: CGFloat { peekWidth * 412 / 480 }
    /// How far the peeking picture's bottom comes down over the card.
    private static var peekOverlap: CGFloat { 12 }

    init(peek: String? = nil, @ViewBuilder content: () -> Content) {
        self.peek = peek
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Up into the status bar, but not down: below this view is the
            // banner, which must not be dimmed.
            Color.black.opacity(0.35)
                .ignoresSafeArea(edges: [.top, .horizontal])
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                content
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.background))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .overlay(alignment: .top) {
                if let peek {
                    Image(peek)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.peekWidth, height: Self.peekHeight)
                        // Lifted out of the card by its own height, less the
                        // overlap: its bottom ends just over the card's edge.
                        .offset(y: -(Self.peekHeight - Self.peekOverlap))
                        .accessibilityHidden(true)
                }
            }
            // Room above the card for the picture, so it's never cut off.
            .padding(.top, peek == nil ? 0 : Self.peekHeight - Self.peekOverlap)
            .padding(.horizontal, 20)
        }
        // One container marked modal, so VoiceOver stays on the card and
        // can't wander to the dimmed buttons underneath.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// Grandma's face and what she says, under the cat on both endings.
struct LevelEndGrandmaLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HelperFaceImage(face: .grandma, size: 44)
            SpeechBubble(text: text)
        }
    }
}

/// The way on (Next level, Try again, Let's play!) and Home under it, the
/// same size so both are easy to hit, with Home outlined so the way on is
/// the obvious one.
struct LevelEndButtons: View {
    let primaryTitle: LocalizedStringKey
    let onPrimary: () -> Void
    /// Nil hides Home: the lesson has a single way on.
    let onHome: (() -> Void)?

    private let height: CGFloat = 54

    var body: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: primaryTitle, height: height, action: onPrimary)
            if let onHome {
                SecondaryButton(title: "Home", height: height, action: onHome)
            }
        }
    }
}
