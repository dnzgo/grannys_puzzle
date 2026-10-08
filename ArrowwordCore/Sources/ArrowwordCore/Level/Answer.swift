/// One clue and the cells its answer fills.
public struct Answer: Identifiable, Sendable, Equatable {
    /// The answer's position in reading order: all across answers top to
    /// bottom, then all down answers left to right. The clue bar's
    /// previous/next buttons walk this order.
    public let id: Int
    public let clueCell: Coordinate
    public let arrow: ClueArrow
    public let clueText: String
    public let cells: [Coordinate]
    public let solution: String

    public var direction: Direction { arrow.direction }
}
