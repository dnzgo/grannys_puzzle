import SwiftUI
import ArrowwordCore

/// Each clue's colour, and the colour maths for drawing it.
///
/// A level has around 25 clues, and nobody can tell 25 colours apart, so a
/// small palette repeats. Colours are assigned so clues that could be confused
/// with each other never match: clues that cross, share a clue cell, or sit in
/// touching clue cells.
enum ClueColors {
    /// Dark enough that white text on the full colour passes 4.5:1 contrast.
    /// Red and amber are left out: red means "wrong" after submitting and
    /// amber marks revealed letters.
    static let palette: [UInt32] = [
        0x3355FF,  // blue
        0x0F766E,  // teal
        0x7C3AED,  // violet
        0xBE185D,  // pink
        0xC2410C,  // orange
        0x15803D,  // green
        0x854D0E,  // brown
    ]

    /// Strength of the active word's colour, by position after the selected
    /// cell: the selected cell, then each following cell, never below the
    /// last step. Cells behind the cursor get the last step too.
    static let fadeSteps: [Double] = [1.0, 0.6, 0.5, 0.4]

    /// Strength of a clue cell's tint while its clue isn't selected.
    static let idleClueTint: Double = 0.16

    // MARK: - Assigning colours

    /// A palette index for every answer, indexed by `Answer.id`.
    ///
    /// Greedy colouring in reading order: each answer takes the first colour
    /// none of its already-coloured neighbours uses. With 7 colours that
    /// almost always succeeds; if every colour is taken it falls back to
    /// cycling, which only risks two neighbours matching.
    static func assignments(for level: Level) -> [Int] {
        var colors = Array(repeating: -1, count: level.answers.count)
        let cellSets = level.answers.map { Set($0.cells) }

        for answer in level.answers {
            var taken = Set<Int>()
            for other in level.answers where colors[other.id] >= 0 {
                if conflicts(answer, other, cellSets: cellSets) {
                    taken.insert(colors[other.id])
                }
            }
            colors[answer.id] = palette.indices.first { !taken.contains($0) } ?? answer.id % palette.count
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

    /// White or dark text, whichever reads better on `fill(index, strength:)`.
    static func text(on index: Int, strength: Double) -> Color {
        let background = rgb(index, strength: strength)
        let white = RGB(hex: 0xFFFFFF)
        let dark = RGB(hex: 0x1C1C1E)
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
