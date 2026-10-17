/// One clue and the cells its answer fills.
public struct Answer: Identifiable, Sendable, Equatable {
    /// The answer's position in reading order: all across answers top to
    /// bottom, then all down answers left to right. Breaks ties when the
    /// game picks the nearest unfinished answer.
    public let id: Int
    public let clueCell: Coordinate
    public let arrow: ClueArrow
    public let clueText: String
    public let cells: [Coordinate]
    public let solution: String

    public var direction: Direction { arrow.direction }
}
