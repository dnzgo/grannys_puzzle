import SwiftUI
import ArrowwordCore

/// The arrowword grid: clue cells, letter cells and gaps, row by row.
struct BoardGrid: View {
    let model: LevelViewModel
    let metrics: BoardMetrics

    var body: some View {
        VStack(spacing: metrics.gap) {
            ForEach(0..<model.level.rows, id: \.self) { row in
                HStack(spacing: metrics.gap) {
                    ForEach(0..<model.level.columns, id: \.self) { column in
                        cellView(at: Coordinate(row: row, column: column))
                            .frame(width: metrics.cellSize, height: metrics.cellSize)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(at cell: Coordinate) -> some View {
        if model.level.isGap(cell) {
            // Left out of the board: nothing drawn, so the board's window
            // shows through, like a black square in a crossword.
            Color.clear
                .accessibilityHidden(true)
        } else if model.level.isClueCell(cell) {
            ClueCellView(
                clues: model.clues(atClueCell: cell),
                fontSize: metrics.clueFontSize,
                arrowSize: metrics.arrowSize,
                onTap: { answerID in model.tapClue(answerID: answerID) }
            )
        } else {
            LetterCellView(
                appearance: model.appearance(of: cell),
                fontSize: metrics.letterFontSize,
                accessibilityText: String(localized: "Row \(cell.row + 1), column \(cell.column + 1)", bundle: .appLanguage, locale: .appLanguage),
                onTap: { model.tapCell(cell) }
            )
        }
    }
}

/// A clue cell holding zero, one or two clues. Every clue shows its own
/// colour: a light tint while idle; a stronger tint with a darker border in
/// that colour while it's being answered.
/// With two clues, the one whose arrow leaves through the right edge sits on
/// top (Level orders them).
struct ClueCellView: View {
    let clues: [ClueAppearance]
    let fontSize: CGFloat
    let arrowSize: CGFloat
    let onTap: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(clues.enumerated()), id: \.element.id) { index, clue in
                if index > 0 {
                    Rectangle().fill(Theme.clueDivider).frame(height: 1)
                }
                clueButton(clue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.clueCell)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func clueButton(_ clue: ClueAppearance) -> some View {
        let strength = clue.isActive ? ClueColors.activeClueTint : ClueColors.idleClueTint
        let textColor = clue.isActive ? ClueColors.text(on: clue.colorIndex, strength: strength) : Theme.clueInk
        let lineColor = ClueColors.line(clue.colorIndex)

        return Button { onTap(clue.answerID) } label: {
            Text(clue.text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                // Room on the right and bottom edges for the arrow.
                .padding(EdgeInsets(top: 1, leading: 2, bottom: 4, trailing: 5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ClueColors.fill(clue.colorIndex, strength: strength))
                // A border marks the active clue, so the tint alone doesn't
                // have to carry the difference.
                .overlay {
                    if clue.isActive {
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(lineColor, lineWidth: ClueColors.activeClueBorderWidth)
                    }
                }
                .overlay(alignment: arrowAlignment(clue.arrow)) {
                    Image(systemName: arrowSymbol(clue.arrow))
                        .font(.system(size: arrowSize, weight: .heavy))
                        .foregroundStyle(lineColor)
                        .padding(clue.isActive ? 2 : 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Whole sentences, not "Across" pasted into a template, so each
        // language can phrase them its own way.
        .accessibilityLabel(clue.arrow.direction == .across ? Text("Across clue: \(clue.text)") : Text("Down clue: \(clue.text)"))
        .accessibilityAddTraits(clue.isActive ? .isSelected : [])
    }

    private func arrowSymbol(_ arrow: ClueArrow) -> String {
        switch arrow {
        case .right: return "chevron.right"
        case .down: return "chevron.down"
        case .rightDown: return "arrow.turn.right.down"
        case .downRight: return "arrow.turn.down.right"
        }
    }

    /// The arrow sits on the edge the answer starts from.
    private func arrowAlignment(_ arrow: ClueArrow) -> Alignment {
        switch arrow {
        case .right, .rightDown: return .trailing
        case .down, .downRight: return .bottom
        }
    }
}

/// A letter cell. Cells of the active answer take its clue's colour, strongest
/// on the selected cell. Shows the cat's head briefly after a hint. After
/// Submit it turns green or red when the judging wave reaches it, with a
/// quick pop.
struct LetterCellView: View {
    let appearance: LetterCellAppearance
    let fontSize: CGFloat
    let accessibilityText: String
    let onTap: () -> Void

    /// Counts pops; each increase plays one.
    @State private var pops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(fill)
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(border, lineWidth: borderWidth)
                if appearance.showsCat {
                    HelperFaceImage(face: .cat, size: fontSize * 1.5)
                        .transition(.scale.combined(with: .opacity))
                } else if let letter = appearance.letter {
                    Text(String(letter))
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                    if appearance.isLocked {
                        lockedMark
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: appearance)
        // The pop: a little bigger, then a spring back. Kept to 14% because
        // cells sit only a few points apart, and neighbours lit in the same
        // group pop together.
        .keyframeAnimator(initialValue: 1.0, trigger: pops) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.14, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.3)
            }
        }
        // Pops only on the way into green or red, not when Try again clears
        // the board; with Reduce Motion the colour change alone carries it.
        .onChange(of: appearance.isJudged) { _, isJudged in
            if isJudged, !reduceMotion { pops += 1 }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(appearance.letter.map { String($0) } ?? "empty")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    /// A small triangle in the top-right corner of a letter the player
    /// can't erase, in the same amber as the letter. Being a shape, it
    /// doesn't rely on colour alone.
    private var lockedMark: some View {
        CornerTriangle()
            .fill(ink)
            // Half the letter size: 10–12pt on phone cells. Smaller, and the
            // rounded corner clips it down to a sliver.
            .frame(width: fontSize * 0.5, height: fontSize * 0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // Follows the cell's rounded corner instead of poking past it.
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch appearance.style {
        case .normal: return Theme.surface
        case .correct: return Theme.correctFill
        case .wrong: return Theme.wrongFill
        case .highlighted(let colorIndex, let strength):
            // A locked letter inside the active word sits on a light tint of
            // the word's colour, light enough that its amber stays readable
            // (the full tint can take amber below 2:1).
            let tint = appearance.isLocked ? min(strength, ClueColors.lockedCellTint) : strength
            return ClueColors.fill(colorIndex, strength: tint)
        }
    }

    private var border: Color {
        switch appearance.style {
        case .normal: return Theme.cellBorder
        case .correct: return Theme.correctBorder
        case .wrong: return Theme.wrongBorder
        case .highlighted: return .clear
        }
    }

    private var borderWidth: CGFloat {
        appearance.isJudged ? Theme.judgedBorderWidth : 1
    }

    private var ink: Color {
        switch appearance.style {
        case .normal: return appearance.isLocked ? Theme.lockedInk : Theme.ink
        // Cat and grandma letters lose their amber here: on the judged
        // board they're simply right, like the rest.
        case .correct: return Theme.ink
        case .wrong: return Theme.wrongInk
        // Inside the coloured word: amber for locked letters (on their
        // lighter tint, see `fill`), otherwise whichever text colour reads.
        case .highlighted(let colorIndex, let strength):
            return appearance.isLocked ? Theme.lockedInk : ClueColors.text(on: colorIndex, strength: strength)
        }
    }
}

/// A right triangle filling the top-right half of its frame.
private struct CornerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
