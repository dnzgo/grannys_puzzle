import SwiftUI
import ArrowwordCore

/// One compact row: back, the clue pill, settings. Level number and
/// progress are small meta text; the clue keeps full size because it's what
/// the player reads most.
struct TopBar: View {
    let model: LevelViewModel

    var body: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemName: "chevron.left", label: "Home") {
                withAnimation(.easeInOut(duration: 0.25)) { model.goHome() }
            }
            // Settings gets its action when the settings screen exists.
            CluePill(model: model)
            CircleIconButton(systemName: "gearshape", label: "Settings") {}
        }
        .frame(height: BoardMetrics.topBarHeight)
    }
}

private struct CluePill: View {
    let model: LevelViewModel

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "chevron.left", label: "Previous clue", action: model.showPreviousClue)

            VStack(spacing: 2) {
                Text("LEVEL \(model.levelNumber) · \(model.progressText)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(0.5)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
                clueLine
            }
            .frame(maxWidth: .infinity)

            stepButton(systemName: "chevron.right", label: "Next clue", action: model.showNextClue)
        }
        .frame(height: 52)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
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

    @ViewBuilder
    private var clueLine: some View {
        if let answer = model.activeAnswer {
            HStack(spacing: 5) {
                Image(systemName: answer.direction == .across ? "arrow.right" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ClueColors.line(model.colorIndex(ofAnswer: answer.id)))
                    .accessibilityLabel(answer.direction == .across ? "Across" : "Down")
                Text(answer.clueText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // Crossword convention: the answer's length in brackets.
                Text("(\(answer.cells.count))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondaryInk)
                    .layoutPriority(1)
            }
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
                .foregroundStyle(Theme.quietInk)
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
