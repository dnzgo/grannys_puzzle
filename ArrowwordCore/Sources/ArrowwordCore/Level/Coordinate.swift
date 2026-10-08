/// A cell position in a level grid. Rows count down from the top and
/// columns count right from the left, both starting at 0.
public struct Coordinate: Hashable, Codable, Sendable, CustomStringConvertible {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public var description: String { "(\(row), \(column))" }

    func moved(rows: Int, columns: Int) -> Coordinate {
        Coordinate(row: row + rows, column: column + columns)
    }
}
