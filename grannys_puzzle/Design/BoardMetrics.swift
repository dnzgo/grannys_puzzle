import CoreGraphics
import ArrowwordCore

/// Sizes that depend on the screen.
///
/// The board sits in a square *frame*, like a window: as large a square as
/// the screen leaves after the top bar, the three-row letter tray and the
/// buttons (361pt on a 393pt-wide iPhone, about 330pt on an SE). A white
/// border runs round it; the board is seen through the *viewport* inside.
///
/// Each screen has a *reading size* for cells, chosen on the simulators:
///
/// | Screen class                      | Height above banner | Cell |
/// |-----------------------------------|---------------------|------|
/// | iPhone 15–18 and larger           | 690pt or more       | 48pt |
/// | iPhone 12/13 mini                 | 640–690pt           | 45pt |
/// | iPhone SE (compact)               | under 640pt         | 40pt |
///
/// Every board zooms and pans inside the viewport (ZoomableBoard), the
/// same way on every phone, between:
/// - **whole board**, the furthest out;
/// - **opening view**, where a level opens and returns after Try again:
///   the whole board if its cells there are at least three quarters of
///   reading size (today's 7×9 levels, on every phone), else reading size;
///   the tutorial opens on the close-up instead, so there's something to
///   pinch out to;
/// - **close-up**, the furthest in: 5×5 cells fill the viewport.
///
/// The board is *drawn* at close-up size and everything else is a zoom out
/// from there, because zooming scales the drawing: shrunk it stays sharp,
/// enlarged past its drawn size it would blur.
///
/// The width and height checks below are a safety net for screens not in this
/// table (iPad split view, future devices): the frame never overflows.
struct BoardMetrics: Equatable {
    /// Height of the area above the banner below which the screen counts as
    /// compact. An iPhone SE has about 580pt here; a mini about 660pt.
    static let compactHeight: CGFloat = 640
    /// At or above this height, phones get the largest cells. A 393×852
    /// iPhone has about 692pt, so only just: more chrome on the level
    /// screen would drop it to the mini's size.
    static let regularHeight: CGFloat = 690
    /// Smallest cells, as a share of reading size, at which a board is
    /// still drawn whole rather than zoomed.
    static let wholeBoardShare: CGFloat = 0.75
    static let cellGap: CGFloat = 2
    /// Cells across the viewport at the closest zoom.
    static let closeUpCells = 5
    /// The window's white border, and its outer corner radius (the
    /// viewport's corners are this minus the border, so the curves match).
    static let windowBorder: CGFloat = 4
    static let windowCornerRadius: CGFloat = 12
    /// Rows in the letter tray: 8 keys each, so up to 24 distinct letters.
    static let trayRows = 3

    // Fixed parts of the level screen. LevelScreen lays itself out with these
    // same values, so the height reserved here is the height actually used.
    static let topBarHeight: CGFloat = 52
    static let topBarTopPadding: CGFloat = 4
    static let trayRowSpacing: CGFloat = 6
    static let minimumSpacer: CGFloat = 8
    static let actionBottomPadding: CGFloat = 8

    /// The side of the square frame, border included.
    let frameSide: CGFloat
    /// The side of the square the board is seen through, inside the border.
    let viewportSide: CGFloat
    /// The size the cells are drawn at.
    let cellSize: CGFloat
    let isCompact: Bool
    /// The zoom that shows the whole board in the viewport.
    let minimumZoom: CGFloat
    /// The zoom of the opening view (see the type's comment). Equal to
    /// `minimumZoom` when the level opens on the whole board.
    let openingZoom: CGFloat
    /// The whole board as drawn, before any zoom.
    let boardSize: CGSize

    /// - Parameters:
    ///   - width: content width (screen width minus side padding).
    ///   - height: height available above the banner ad.
    ///   - opensCloseUp: open on the close-up rather than the usual
    ///     opening view (the tutorial, which teaches zooming out).
    init(width: CGFloat, height: CGFloat, columns: Int, rows: Int, opensCloseUp: Bool = false) {
        let compact = height < Self.compactHeight
        isCompact = compact
        frameSide = max(0, min(width, height - Self.reservedHeight(isCompact: compact)).rounded(.down))
        let side = max(0, frameSide - 2 * Self.windowBorder)
        viewportSide = side

        let viewport = CGSize(width: side, height: side)
        let reading = Self.preferredCellSize(forHeight: height)
        let fitting = Self.largestCell(fitting: viewport, columns: columns, rows: rows, cap: .infinity)
        let opensWhole = fitting >= (reading * Self.wholeBoardShare).rounded(.down)
        let closeUp = Self.largestCell(fitting: viewport, columns: Self.closeUpCells, rows: Self.closeUpCells, cap: .infinity)
        // Never smaller than reading size (a tiny screen's close-up),
        // nor than the whole board fits at (a board of under 5×5).
        cellSize = max(reading, closeUp, fitting)
        boardSize = CGSize(
            width: Self.span(of: columns, cellSize: cellSize),
            height: Self.span(of: rows, cellSize: cellSize)
        )
        minimumZoom = min(side / boardSize.width, side / boardSize.height, 1)
        if opensCloseUp {
            openingZoom = 1
        } else {
            openingZoom = opensWhole ? minimumZoom : max(minimumZoom, reading / cellSize)
        }
    }

    /// Where a cell's top-left corner is on the drawn board.
    func origin(of cell: Coordinate) -> CGPoint {
        CGPoint(x: CGFloat(cell.column) * (cellSize + gap), y: CGFloat(cell.row) * (cellSize + gap))
    }

    /// The cell under a point on the drawn board, or nil past its edge. A
    /// point in the gap between two cells counts for the one before it, so
    /// a tap there still lands somewhere.
    func cell(at point: CGPoint, columns: Int, rows: Int) -> Coordinate? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let column = Int(point.x / (cellSize + gap))
        let row = Int(point.y / (cellSize + gap))
        guard column < columns, row < rows else { return nil }
        return Coordinate(row: row, column: column)
    }

    /// The smallest rectangle around these cells on the drawn board.
    func rect(around cells: [Coordinate]) -> CGRect {
        cells.reduce(CGRect.null) { rect, cell in
            rect.union(CGRect(origin: origin(of: cell), size: CGSize(width: cellSize, height: cellSize)))
        }
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

    /// Everything on the level screen except the board's frame.
    private static func reservedHeight(isCompact: Bool) -> CGFloat {
        let topBar = topBarTopPadding + topBarHeight
        let rows = CGFloat(trayRows)
        let tray = rows * trayKeyHeight(isCompact: isCompact) + (rows - 1) * trayRowSpacing
        let actions = actionHeight(isCompact: isCompact) + actionBottomPadding
        return topBar + gridTopPadding(isCompact: isCompact) + tray + actions + 2 * minimumSpacer
    }
}
