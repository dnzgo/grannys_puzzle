import SwiftUI
import ArrowwordCore

/// One compact row: back, the clue pill, settings. The level number is
/// small meta text and progress a thin bar; the clue keeps full size
/// because it's what the player reads most.
struct TopBar: View {
    let model: LevelViewModel
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemName: "chevron.left", label: "Home") {
                withAnimation(.easeInOut(duration: 0.25)) { model.goHome() }
            }
            CluePill(model: model)
                // The lesson keeps it lit with the word it's talking about.
                .spotlight(.clueBar)
            CircleIconButton(systemName: "gearshape", label: "Settings", action: onSettings)
        }
        .frame(height: BoardMetrics.topBarHeight)
    }
}

/// The clue being answered, in the colour of its word: the same tint as
/// its clue cell, so the bar and the grid read as one, and a change of
/// word shows at the top as a change of colour.
private struct CluePill: View {
    let model: LevelViewModel

    /// The active word's palette index; nil once the level is judged.
    private var colorIndex: Int? {
        model.activeAnswer.map { model.colorIndex(ofAnswer: $0.id) }
    }

    private var fill: Color {
        guard let colorIndex else { return Theme.surface }
        return ClueColors.fill(colorIndex, strength: ClueColors.clueBarTint)
    }

    /// Dark or white, whichever reads on the tint. Used at full strength
    /// for all of the bar's text and icons: the quieter greys, or any
    /// transparency, drop below the contrast they need on the tints.
    private var textColor: Color {
        guard let colorIndex else { return Theme.ink }
        return ClueColors.text(on: colorIndex, strength: ClueColors.clueBarTint)
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "chevron.left", label: "Previous clue", action: model.showPreviousClue)

            VStack(spacing: 2) {
                header
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(0.5)
                    .monospacedDigit()
                    .foregroundStyle(textColor)
                clueLine
            }
            // Clear of the progress line along the bottom edge; a clue that
            // doesn't fit in what's left shrinks instead.
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)

            stepButton(systemName: "chevron.right", label: "Next clue", action: model.showNextClue)
        }
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 14).fill(fill))
        // A quick fade between colours, so the change of word is noticed.
        .animation(.easeOut(duration: 0.2), value: colorIndex)
        // Progress is the pill's bottom edge rather than a row of its own.
        .overlay(alignment: .bottom) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.progressTrack)
                    Rectangle().fill(Theme.primary)
                        .frame(width: geometry.size.width * model.progressFraction)
                }
            }
            .frame(height: 3)
            .animation(.easeOut(duration: 0.24), value: model.progressFraction)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }

    /// Only which level this is. A filled count ("4/48") sat beside it but
    /// read like a second level number; the bar along the pill's bottom
    /// edge already shows how full the board is.
    @ViewBuilder
    private var header: some View {
        if model.isTutorial {
            Text("HOW TO PLAY")
        } else {
            Text("LEVEL \(model.levelNumber)")
        }
    }

    @ViewBuilder
    private var clueLine: some View {
        if let answer = model.activeAnswer {
            HStack(spacing: 5) {
                Image(systemName: answer.direction == .across ? "arrow.right" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(textColor)
                    .accessibilityLabel(answer.direction == .across ? Text("Across") : Text("Down"))
                // Never cut off with "…": a clue missing its end can't be
                // solved. Up to two lines, then the text shrinks to fit.
                // No letter count: the word's cells in the grid already show it.
                Text(answer.clueText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 2)
        } else {
            Text("Level complete")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private func stepButton(systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(width: 32, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A round white 44pt button with an SF Symbol.
struct CircleIconButton: View {
    let systemName: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.surface).shadow(color: .black.opacity(0.06), radius: 1, y: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
