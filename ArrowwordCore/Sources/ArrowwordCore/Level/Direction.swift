/// The way an answer reads.
public enum Direction: String, Codable, Sendable, CaseIterable {
    case across
    case down

    public var other: Direction { self == .across ? .down : .across }

    /// One step along the answer.
    var step: (rows: Int, columns: Int) { self == .across ? (0, 1) : (1, 0) }
}

/// Where a clue's arrow points from its clue cell.
///
/// The two bent arrows exist because clue cells on the top and left edges
/// often need to clue an answer that starts next to them but reads the other
/// way: `rightDown` starts in the cell to the right and reads down.
public enum ClueArrow: String, Codable, Sendable {
    case right
    case down
    case rightDown
    case downRight

    /// The direction the answer reads in.
    public var direction: Direction {
        switch self {
        case .right, .downRight: return .across
        case .down, .rightDown: return .down
        }
    }

    /// Offset from the clue cell to the answer's first letter.
    var startOffset: (rows: Int, columns: Int) {
        switch self {
        case .right, .rightDown: return (0, 1)
        case .down, .downRight: return (1, 0)
        }
    }

    /// Whether the arrow leaves the clue cell through its bottom edge.
    /// A cell holding two clues puts the right-exiting one on top and the
    /// bottom-exiting one below, so the arrows never cross.
    public var exitsBottom: Bool { self == .down || self == .downRight }
}
