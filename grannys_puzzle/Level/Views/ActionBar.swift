import SwiftUI
import ArrowwordCore

/// The row in the thumb's reach. While playing: erase · grandma · cat as one
/// centred group. With a full board: erase · Submit. After the result: Next
/// level or Try again.
struct ActionBar: View {
    let model: LevelViewModel
    let height: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            switch model.phase {
            case .playing:
                eraseButton
                HelperButton(
                    face: .grandma,
                    count: model.grandmas,
                    diameter: height,
                    action: model.useGrandma
                )
                .disabled(!model.canUseGrandma)
                .spotlight(.target(.grandma))
                .accessibilityLabel("Grandma: solve this word")
                .accessibilityValue("\(model.grandmas) left")
                HelperButton(
                    face: .cat,
                    count: model.hints,
                    diameter: height,
                    action: model.useCat
                )
                .disabled(!model.canUseCat)
                .spotlight(.target(.cat))
                .accessibilityLabel("Cat: reveal a letter")
                .accessibilityValue("\(model.hints) left")

            case .readyToSubmit:
                eraseButton
                PrimaryButton(title: "Submit", height: height, action: model.submit)
                    .spotlight(.target(.submit))

            case .finished(let result):
                PrimaryButton(
                    // After the lesson, the next stop is home with the first yarn.
                    title: result.passed ? (model.isTutorial ? "Let's play!" : "Next level") : "Try again",
                    height: height,
                    action: model.continueAfterResult
                )
            }
        }
        .frame(height: height)
    }

    private var eraseButton: some View {
        Button(action: model.erase) {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 56, height: height)
                .background(Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Erase letter")
    }
}

/// A round help button: the helper's face, with the saved count in a
/// small circle on its top-right edge. At 0 it's disabled for now; the
/// rewarded-ad offer replaces that state when ads are added.
private struct HelperButton: View {
    let face: HelperFace
    let count: Int
    let diameter: CGFloat
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    /// The badge grows into a pill for two-digit counts instead of clipping them.
    private let badgeSize: CGFloat = 22

    var body: some View {
        Button(action: action) {
            // The face nearly fills the circle; the white rim around it is
            // the button's edge, so it needs no extra ring.
            HelperFaceImage(face: face, size: diameter * 0.92, isEnabled: isEnabled)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill).shadow(color: glow, radius: 6, y: 2))
                .overlay(alignment: .topTrailing) { badge }
        }
        .buttonStyle(.plain)
    }

    private var badge: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: badgeSize, minHeight: badgeSize)
            .background(Capsule().fill(badgeFill))
            // A ring in the screen's background colour separates the badge
            // from the button it overlaps.
            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
            // Half outside the circle, like an app icon badge.
            .offset(x: 6, y: -6)
    }

    // White on both, because the faces are colourful (an orange cat on an
    // orange button would vanish). The faces themselves tell them apart.
    private var fill: Color {
        isEnabled ? Theme.surface : Theme.disabledFill
    }

    /// A soft orange glow under the circle; gone when the helper is used
    /// up, so an available helper looks lit and an empty one looks flat.
    private var glow: Color {
        isEnabled ? Theme.primary.opacity(0.45) : .clear
    }

    /// Dark on both buttons, so the count reads the same on orange and on white.
    private var badgeFill: Color {
        isEnabled ? Theme.ink : Theme.usedUpKey
    }
}

/// The full-width main button (Submit, Next level, Try again, and Play on
/// the home screen).
struct PrimaryButton: View {
    let title: LocalizedStringKey
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Large, heavy, rounded text: white on this light orange relies
            // on size and weight to stay readable (see Theme.primary).
            Text(title)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    Capsule()
                        .fill(Theme.primary)
                        .shadow(color: Theme.primary.opacity(0.35), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}
