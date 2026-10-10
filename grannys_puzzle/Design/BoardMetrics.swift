import CoreGraphics
import ArrowwordCore

/// Sizes that depend on the screen.
///
/// Every player gets the same level (the daily leaderboard depends on it),
/// so small phones draw the grid smaller instead of getting a smaller level.
///
/// Cell size is a fixed size per screen class, chosen on the simulators:
///
/// | Screen class                      | Height above banner | Cell |
/// |-----------------------------------|---------------------|------|
/// | iPhone 15–18 and larger           | 690pt or more       | 48pt |
/// | iPhone 12/13 mini                 | 640–690pt           | 45pt |
/// | iPhone SE (compact)               | under 640pt         | 40pt |
///
/// Those sizes are for the largest grid the rules allow (7×9), and they
/// define a fixed *board box* per screen. A smaller grid gets the largest
/// cells that fit in that box, so a 5×6 level fills the same space as a 7×9
/// one instead of floating in empty space, and no level is ever bigger.
///
/// The width and height checks below are a safety net for screens not in this
/// table (iPad split view, future devices): the grid never overflows.
struct BoardMetrics {
    /// Height of the area above the banner below which the screen counts as
    /// compact. An iPhone SE has about 590pt here; a mini about 670pt.
    static let compactHeight: CGFloat = 640
    /// At or above this height, phones get the largest cells.
    static let regularHeight: CGFloat = 690
    static let cellGap: CGFloat = 2

    // Fixed parts of the level screen. LevelScreen lays itself out with these
    // same values, so the height reserved here is the height actually used.
    static let topBarHeight: CGFloat = 52
    static let topBarTopPadding: CGFloat = 4
    static let trayRowSpacing: CGFloat = 6
    static let minimumSpacer: CGFloat = 8
    static let actionBottomPadding: CGFloat = 8

    let cellSize: CGFloat
    let isCompact: Bool

    /// - Parameters:
    ///   - width: content width (screen width minus side padding).
    ///   - height: height available above the banner ad.
    init(width: CGFloat, height: CGFloat, columns: Int, rows: Int) {
        let compact = height < Self.compactHeight
        isCompact = compact
        let available = CGSize(width: width, height: height - Self.reservedHeight(isCompact: compact))

        // 1. Size the largest allowed grid for this screen: the preferred cell
        //    size from the table, shrunk only if the screen is too small.
        let largest = LevelRules.standard
        let referenceCell = Self.largestCell(
            fitting: available,
            columns: largest.columns.upperBound,
            rows: largest.rows.upperBound,
            cap: Self.preferredCellSize(forHeight: height)
        )
        // 2. That grid's outline is the board box every level shares.
        let boardBox = CGSize(
            width: Self.span(of: largest.columns.upperBound, cellSize: referenceCell),
            height: Self.span(of: largest.rows.upperBound, cellSize: referenceCell)
        )
        // 3. This level's cells grow until its grid touches the box's width
        //    or height. The box already fits the screen, so this one does too.
        cellSize = Self.largestCell(fitting: boardBox, columns: columns, rows: rows, cap: .infinity)
    }

    var gap: CGFloat { Self.cellGap }
    var letterFontSize: CGFloat { cellSize * 0.5 }
    /// Clue text stays small; the clue bar repeats the active clue at full size.
    var clueFontSize: CGFloat { cellSize * 0.17 }
    var arrowSize: CGFloat { cellSize * 0.14 }
    var gridTopPadding: CGFloat { Self.gridTopPadding(isCompact: isCompact) }
    var trayKeyHeight: CGFloat { Self.trayKeyHeight(isCompact: isCompact) }
    var actionHeight: CGFloat { Self.actionHeight(isCompact: isCompact) }

    /// The largest whole-point square cell that lets a grid fit in `size`.
    /// Rounded down so cell edges land on whole points and stay crisp.
    private static func largestCell(fitting size: CGSize, columns: Int, rows: Int, cap: CGFloat) -> CGFloat {
        let columnCount = CGFloat(max(1, columns))
        let rowCount = CGFloat(max(1, rows))
        let fitsWidth = (size.width - cellGap * (columnCount - 1)) / columnCount
        let fitsHeight = (size.height - cellGap * (rowCount - 1)) / rowCount
        return max(0, min(cap, fitsWidth, fitsHeight).rounded(.down))
    }

    /// The length of `count` cells side by side, including the gaps between them.
    private static func span(of count: Int, cellSize: CGFloat) -> CGFloat {
        CGFloat(count) * cellSize + CGFloat(max(0, count - 1)) * cellGap
    }

    private static func preferredCellSize(forHeight height: CGFloat) -> CGFloat {
        if height >= regularHeight { return 48 }
        if height >= compactHeight { return 45 }
        return 40
    }

    private static func gridTopPadding(isCompact: Bool) -> CGFloat { isCompact ? 6 : 10 }
    private static func trayKeyHeight(isCompact: Bool) -> CGFloat { isCompact ? 36 : 40 }
    private static func actionHeight(isCompact: Bool) -> CGFloat { isCompact ? 44 : 48 }

    /// Everything on the level screen except the grid itself.
    private static func reservedHeight(isCompact: Bool) -> CGFloat {
        let topBar = topBarTopPadding + topBarHeight
        let tray = 2 * trayKeyHeight(isCompact: isCompact) + trayRowSpacing
        let actions = actionHeight(isCompact: isCompact) + actionBottomPadding
        return topBar + gridTopPadding(isCompact: isCompact) + tray + actions + 2 * minimumSpacer
    }
}
