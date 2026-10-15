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
                    offersAd: model.grandmaOffersAd,
                    isLit: model.canUseGrandma,
                    diameter: height,
                    action: model.useGrandma
                )
                .disabled(!model.canTapHelpers)
                .spotlight(.target(.grandma))
                .accessibilityLabel("Grandma: solve this word")
                .accessibilityValue(helperValue(count: model.grandmas, offersAd: model.grandmaOffersAd))
                HelperButton(
                    face: .cat,
                    count: model.hints,
                    offersAd: model.catOffersAd,
                    isLit: model.canUseCat,
                    diameter: height,
                    action: model.useCat
                )
                .disabled(!model.canTapHelpers)
                .spotlight(.target(.cat))
                .accessibilityLabel("Cat: reveal a letter")
                .accessibilityValue(helperValue(count: model.hints, offersAd: model.catOffersAd))

            case .readyToSubmit:
                eraseButton
                PrimaryButton(title: "Submit", height: height, action: model.submit)
                    .spotlight(.target(.submit))

            case .finished(let result):
                // Empty while the board lights up: "Try again" appearing
                // under the wave would give the verdict away.
                if model.showsLevelEnd {
                    PrimaryButton(
                        // After the lesson, the next stop is home with the first yarn.
                        title: result.passed ? (model.isTutorial ? "Let's play!" : "Next level") : "Try again",
                        height: height,
                        action: model.continueAfterResult
                    )
                }
            }
        }
        .frame(height: height)
    }

    private func helperValue(count: Int, offersAd: Bool) -> Text {
        offersAd ? Text("None left. Watch a short video for more help") : Text("\(count) left")
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
/// small circle on its top-right edge. At 0 it offers a short ad for one
/// more when an ad is ready; when none is, it looks used up but can still
/// be tapped, and grandma says why.
private struct HelperButton: View {
    let face: HelperFace
    let count: Int
    /// Out of this helper, but a short ad can earn one: the badge shows a
    /// play sign instead of 0, and the button stays lit.
    let offersAd: Bool
    /// Looks available (lit, glowing) rather than used up. Separate from
    /// whether it can be tapped: a used-up helper still explains itself.
    let isLit: Bool
    let diameter: CGFloat
    let action: () -> Void

    @Environment(\.isEnabled) private var canTap
    /// What every part of the look follows: lit, and not paused (a video
    /// playing disables the buttons).
    private var isEnabled: Bool { isLit && canTap }

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
        Group {
            if offersAd {
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
            } else {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .frame(minWidth: badgeSize, minHeight: badgeSize)
        .background(Capsule().fill(offersAd && isEnabled ? Theme.primary : badgeFill))
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

/// The quieter partner of PrimaryButton (Home under Next level): the same
/// shape, size and type, but only a brown outline and label, so it's as
/// easy to hit while the main action stays the obvious one.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Brown on cream is 3.3:1, which passes for text this large and
            // heavy (see Theme.secondary).
            Text(title)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(Capsule().strokeBorder(Theme.secondary, lineWidth: 2))
                // The inside of an outline isn't hit-testable by default;
                // this makes the whole capsule the tap target.
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
