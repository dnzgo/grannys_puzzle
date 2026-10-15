/// The pattern in which a submitted board lights up green and red, cell
/// group by cell group, before the level-end card.
///
/// Several patterns, one picked at random each time, so a moment players
/// see after every level doesn't turn into wallpaper. Only the *order* lives
/// here; timing and looks are the app's.
public enum JudgingWave: CaseIterable, Sendable {
    /// Diagonals from the top-left corner to the bottom-right.
    case diagonal
    /// Diagonals from the top-right corner to the bottom-left.
    case reverseDiagonal
    /// Whole rows, top to bottom.
    case rows
    /// Whole columns, left to right.
    case columns
    /// A diamond-shaped ripple from the middle out to the edges.
    case fromCentre
    /// The same ripple running the other way, edges in to the middle.
    case toCentre

    /// The given cells in light-up order: every cell in a group lights at
    /// the same moment, and groups follow one another.
    ///
    /// Only the cells passed in are grouped, so a step with none of them
    /// (a diagonal of nothing but clue cells) never becomes an empty pause.
    public func groups(of cells: [Coordinate], rows: Int, columns: Int) -> [[Coordinate]] {
        var byStep: [Int: [Coordinate]] = [:]
        for cell in cells {
            byStep[step(of: cell, rows: rows, columns: columns), default: []].append(cell)
        }
        let ordered = byStep.keys.sorted().compactMap { byStep[$0] }
        // Inwards is the outward ripple played backwards.
        return self == .toCentre ? ordered.reversed() : ordered
    }

    /// Which moment a cell lights at; lower lights first.
    private func step(of cell: Coordinate, rows: Int, columns: Int) -> Int {
        switch self {
        case .diagonal:
            return cell.row + cell.column
        case .reverseDiagonal:
            return cell.row + (columns - 1 - cell.column)
        case .rows:
            return cell.row
        case .columns:
            return cell.column
        case .fromCentre, .toCentre:
            // Distance from the middle, counted along rows plus columns (which
            // gives the diamond). Coordinates are doubled so that the middle
            // of an even-sized grid, which falls between two cells, is still a
            // whole number; halving at the end puts each pair of half-steps
            // into one ring.
            let rowDistance = abs(2 * cell.row - (rows - 1))
            let columnDistance = abs(2 * cell.column - (columns - 1))
            return (rowDistance + columnDistance) / 2
        }
    }

    /// A random wave, never the same as the one before, so two levels in a
    /// row always look different.
    public static func random<Generator: RandomNumberGenerator>(
        after previous: JudgingWave?,
        using generator: inout Generator
    ) -> JudgingWave {
        let choices = allCases.filter { $0 != previous }
        // allCases has six cases, so leaving one out still leaves five.
        return choices.randomElement(using: &generator) ?? .diagonal
    }
}
