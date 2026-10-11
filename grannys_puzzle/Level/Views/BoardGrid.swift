import SwiftUI
import ArrowwordCore

/// The arrowword grid: clue cells and letter cells, row by row.
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
        if model.level.isClueCell(cell) {
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
                accessibilityText: "Row \(cell.row + 1), column \(cell.column + 1)",
                onTap: { model.tapCell(cell) }
            )
            .spotlight(.cell(cell))
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
        .spotlight(.target(.clue(answerID: clue.answerID)))
        .accessibilityLabel("\(clue.arrow.direction == .across ? "Across" : "Down") clue: \(clue.text)")
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
/// on the selected cell. Shows the cat's head briefly after a hint.
struct LetterCellView: View {
    let appearance: LetterCellAppearance
    let fontSize: CGFloat
    let accessibilityText: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(fill)
                RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(border, lineWidth: 1)
                if appearance.showsCat {
                    HelperFaceImage(face: .cat, size: fontSize * 1.5)
                        .transition(.scale.combined(with: .opacity))
                } else if let letter = appearance.letter {
                    Text(String(letter))
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: appearance)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(appearance.letter.map { String($0) } ?? "empty")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    private var fill: Color {
        switch appearance.style {
        case .normal: return Theme.surface
        case .wrong: return Theme.wrongFill
        case .highlighted(let colorIndex, let strength): return ClueColors.fill(colorIndex, strength: strength)
        }
    }

    private var border: Color {
        switch appearance.style {
        case .normal: return Theme.cellBorder
        case .wrong: return Theme.wrongBorder
        case .highlighted: return .clear
        }
    }

    private var ink: Color {
        switch appearance.style {
        case .normal: return appearance.isRevealed ? Theme.revealedInk : Theme.ink
        case .wrong: return Theme.wrongInk
        // Inside the coloured word, readability wins over the amber marker.
        case .highlighted(let colorIndex, let strength): return ClueColors.text(on: colorIndex, strength: strength)
        }
    }
}
