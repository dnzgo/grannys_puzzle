import SwiftUI
import ArrowwordCore

/// Each clue's colour, and the colour maths for drawing it.
///
/// A level has around 25 clues, and nobody can tell 25 colours apart, so a
/// small palette repeats. Colours are assigned so clues that could be confused
/// with each other never match: clues that cross, share a clue cell, or sit in
/// touching clue cells.
enum ClueColors {
    /// Soft pastel colours, converted from the designer's 0–1 RGB values.
    /// Being light, dark text reads well on all of them at every strength
    /// (4.8:1 or more). Close pairs to watch: blue / grey-blue are hard to
    /// tell apart; red / brown and orange / mustard are borderline.
    static let palette: [UInt32] = [
        0x9279D0,  // purple     (0.573, 0.475, 0.816)
        0xB6D79B,  // green      (0.715, 0.845, 0.608)
        0x7FBAE2,  // blue       (0.498, 0.730, 0.888)
        0xF1AE77,  // orange     (0.947, 0.681, 0.466)
        0xC77876,  // red        (0.782, 0.469, 0.464)
        0xEFB7CF,  // pink       (0.939, 0.716, 0.810)
        0x67B2B1,  // teal       (0.404, 0.699, 0.694)
        0xACBFD5,  // grey-blue  (0.675, 0.748, 0.835)
        0xDDBC5D,  // mustard    (0.868, 0.738, 0.365)
        0xA4724F,  // brown      (0.642, 0.446, 0.309)
    ]

    /// Lines and icons (arrows, the active clue's border) use a darker shade
    /// of the clue colour. Pastels are too light against white for thin
    /// strokes (green is only 1.6:1); at 60% brightness every colour reaches
    /// at least 3.6:1, above the 3:1 that icons need.
    static let lineDarkening: Double = 0.6

    /// Strength of the active word's colour, by position after the selected
    /// cell: the selected cell, then each following cell, never below the
    /// last step. Cells behind the cursor get the last step too.
    static let fadeSteps: [Double] = [1.0, 0.6, 0.5, 0.4]

    /// Strength of a clue cell's tint while its clue isn't selected. Pastels
    /// are already light, so a weak tint would vanish into the grey cell.
    static let idleClueTint: Double = 0.4
    /// Strength of the active clue's cell, plus a border in the line colour.
    /// Text stays readable here because the colours are light.
    static let activeClueTint: Double = 0.8
    static let activeClueBorderWidth: CGFloat = 1.2

    // MARK: - Assigning colours

    /// A palette index for every answer, indexed by `Answer.id`.
    ///
    /// Greedy colouring in reading order: each answer picks from the colours
    /// none of its already-coloured neighbours uses, and among those takes
    /// the one used *least so far*. Picking the first free colour instead
    /// would favour the start of the palette: on Level 100 that used only 4
    /// colours, blue for 9 clues. Least-used spreads all 7 evenly (3–4 each).
    /// If every colour is taken by a neighbour, it falls back to cycling,
    /// which only risks two neighbours matching.
    static func assignments(for level: Level) -> [Int] {
        var colors = Array(repeating: -1, count: level.answers.count)
        var useCounts = Array(repeating: 0, count: palette.count)
        let cellSets = level.answers.map { Set($0.cells) }

        for answer in level.answers {
            var taken = Set<Int>()
            for other in level.answers where colors[other.id] >= 0 {
                if conflicts(answer, other, cellSets: cellSets) {
                    taken.insert(colors[other.id])
                }
            }
            let free = palette.indices.filter { !taken.contains($0) }
            // Ties go to the earlier palette colour, so the result is the same every time.
            let chosen = free.min { (useCounts[$0], $0) < (useCounts[$1], $1) } ?? answer.id % palette.count
            colors[answer.id] = chosen
            useCounts[chosen] += 1
        }
        return colors
    }

    private static func conflicts(_ first: Answer, _ second: Answer, cellSets: [Set<Coordinate>]) -> Bool {
        if !cellSets[first.id].isDisjoint(with: cellSets[second.id]) { return true }
        let rowDistance = abs(first.clueCell.row - second.clueCell.row)
        let columnDistance = abs(first.clueCell.column - second.clueCell.column)
        return rowDistance <= 1 && columnDistance <= 1
    }

    // MARK: - Colour maths

    /// The palette colour mixed with white at `strength` (1 = full colour).
    /// Mixing gives an opaque colour, so its contrast with text can be measured.
    static func fill(_ index: Int, strength: Double) -> Color {
        rgb(index, strength: strength).color
    }

    /// The darker shade for thin lines and icons in this clue's colour.
    static func line(_ index: Int) -> Color {
        RGB(hex: palette[index % palette.count]).darkened(by: lineDarkening).color
    }

    /// White or dark text, whichever reads better on `fill(index, strength:)`.
    static func text(on index: Int, strength: Double) -> Color {
        let background = rgb(index, strength: strength)
        let white = RGB(hex: 0xFFFFFF)
        let dark = RGB(hex: Theme.inkHex)
        return background.contrast(with: white) >= background.contrast(with: dark) ? .white : Theme.ink
    }

    private static func rgb(_ index: Int, strength: Double) -> RGB {
        let base = RGB(hex: palette[index % palette.count])
        return base.mixedWithWhite(strength: strength)
    }
}

/// A colour as red, green and blue from 0 to 1, for contrast calculations.
private struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Scales every channel toward black: 0.6 keeps 60% of the brightness.
    func darkened(by factor: Double) -> RGB {
        let keep = min(max(factor, 0), 1)
        return RGB(red: red * keep, green: green * keep, blue: blue * keep)
    }

    func mixedWithWhite(strength: Double) -> RGB {
        let keep = min(max(strength, 0), 1)
        return RGB(
            red: red * keep + (1 - keep),
            green: green * keep + (1 - keep),
            blue: blue * keep + (1 - keep)
        )
    }

    /// Relative luminance as defined by WCAG, the basis of contrast ratios.
    var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 (none) to 21 (black on white).
    func contrast(with other: RGB) -> Double {
        let lighter = max(luminance, other.luminance)
        let darker = min(luminance, other.luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var color: Color { Color(red: red, green: green, blue: blue) }
}
