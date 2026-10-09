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
                    systemImage: "eyeglasses",
                    count: model.grandmas,
                    isProminent: false,
                    diameter: height,
                    action: model.useGrandma
                )
                .disabled(!model.canUseGrandma)
                .accessibilityLabel("Grandma: solve this word")
                .accessibilityValue("\(model.grandmas) left")
                HelperButton(
                    systemImage: "cat.fill",
                    count: model.hints,
                    isProminent: true,
                    diameter: height,
                    action: model.useCat
                )
                .disabled(!model.canUseCat)
                .accessibilityLabel("Cat: reveal a letter")
                .accessibilityValue("\(model.hints) left")

            case .readyToSubmit:
                eraseButton
                PrimaryButton(title: "Submit", height: height, action: model.submit)

            case .finished(let result):
                PrimaryButton(
                    title: result.passed ? "Next level" : "Try again",
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

/// A round help button: the character's icon, with the saved count in a
/// small circle on its top-right edge. At 0 it's disabled for now; the
/// rewarded-ad offer replaces that state when ads are added.
private struct HelperButton: View {
    let systemImage: String
    let count: Int
    let isProminent: Bool
    let diameter: CGFloat
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    /// The badge grows into a pill for two-digit counts instead of clipping them.
    private let badgeSize: CGFloat = 22

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.44, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(fill).shadow(color: .black.opacity(0.08), radius: 2, y: 1))
                .overlay(Circle().strokeBorder(border, lineWidth: 1.5))
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

    private var foreground: Color {
        guard isEnabled else { return Theme.usedUpKey }
        return isProminent ? .white : Theme.ink
    }

    private var fill: Color {
        guard isEnabled else { return Color(hex: 0xE9E9E5) }
        return isProminent ? Theme.accent : Theme.surface
    }

    private var border: Color {
        guard isEnabled else { return .clear }
        return isProminent ? .clear : Theme.accent
    }

    /// Dark on both buttons, so the count reads the same on blue and on white.
    private var badgeFill: Color {
        isEnabled ? Theme.ink : Theme.usedUpKey
    }
}

/// The full-width blue button (Submit, Next level, Try again).
private struct PrimaryButton: View {
    let title: LocalizedStringKey
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }
}
