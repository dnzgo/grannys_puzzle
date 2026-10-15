import XCTest
@testable import ArrowwordCore

/// The order a judged board lights up in. What matters to the player: every
/// cell lights exactly once, each wave moves the way its name says, and the
/// same wave never plays twice in a row.
final class JudgingWaveTests: XCTestCase {
    /// Every cell of a 3×4 grid, in reading order.
    private let rows = 3
    private let columns = 4
    private var allCells: [Coordinate] {
        (0..<rows).flatMap { row in (0..<columns).map { cell(row, $0) } }
    }

    func testEveryWaveLightsEachCellExactlyOnce() {
        for wave in JudgingWave.allCases {
            let lit = wave.groups(of: allCells, rows: rows, columns: columns).flatMap { $0 }
            XCTAssertEqual(lit.count, allCells.count, "\(wave)")
            XCTAssertEqual(Set(lit), Set(allCells), "\(wave)")
        }
    }

    func testDiagonalStartsTopLeftAndLightsEachDiagonalTogether() {
        let groups = JudgingWave.diagonal.groups(of: allCells, rows: rows, columns: columns)

        XCTAssertEqual(groups.first, [cell(0, 0)])
        XCTAssertEqual(Set(groups[1]), [cell(0, 1), cell(1, 0)])
        XCTAssertEqual(groups.last, [cell(2, 3)])
        // 3 + 4 - 1 diagonals.
        XCTAssertEqual(groups.count, 6)
    }

    func testReverseDiagonalStartsTopRight() {
        let groups = JudgingWave.reverseDiagonal.groups(of: allCells, rows: rows, columns: columns)

        XCTAssertEqual(groups.first, [cell(0, 3)])
        XCTAssertEqual(groups.last, [cell(2, 0)])
    }

    func testRowsAndColumnsLightWholeLinesInOrder() {
        let rowGroups = JudgingWave.rows.groups(of: allCells, rows: rows, columns: columns)
        XCTAssertEqual(rowGroups.map { Set($0.map(\.row)) }, [[0], [1], [2]])

        let columnGroups = JudgingWave.columns.groups(of: allCells, rows: rows, columns: columns)
        XCTAssertEqual(columnGroups.map { Set($0.map(\.column)) }, [[0], [1], [2], [3]])
    }

    func testRippleStartsInTheMiddleAndEndsInTheCorners() {
        // A 3×3 grid has a true middle cell.
        let square = (0..<3).flatMap { row in (0..<3).map { cell(row, $0) } }
        let outwards = JudgingWave.fromCentre.groups(of: square, rows: 3, columns: 3)

        XCTAssertEqual(outwards.first, [cell(1, 1)])
        XCTAssertEqual(Set(outwards.last ?? []), [cell(0, 0), cell(0, 2), cell(2, 0), cell(2, 2)])
    }

    func testInwardsIsOutwardsBackwards() {
        let outwards = JudgingWave.fromCentre.groups(of: allCells, rows: rows, columns: columns)
        let inwards = JudgingWave.toCentre.groups(of: allCells, rows: rows, columns: columns)

        XCTAssertEqual(inwards, Array(outwards.reversed()))
    }

    /// Clue cells aren't passed in, so a diagonal made only of clue cells
    /// must not become an empty group (a pause with nothing lighting).
    func testStepsWithNoCellsLeaveNoEmptyGroups() {
        let corners = [cell(0, 0), cell(2, 3)]
        let groups = JudgingWave.diagonal.groups(of: corners, rows: rows, columns: columns)

        XCTAssertEqual(groups, [[cell(0, 0)], [cell(2, 3)]])
    }

    func testRandomNeverRepeatsThePreviousWave() {
        var generator = SeededGenerator(seed: 7)
        var previous: JudgingWave?
        var seen: Set<JudgingWave> = []
        for _ in 0..<200 {
            let wave = JudgingWave.random(after: previous, using: &generator)
            XCTAssertNotEqual(wave, previous)
            seen.insert(wave)
            previous = wave
        }
        // And over many levels, players get to see all of them.
        XCTAssertEqual(seen, Set(JudgingWave.allCases))
    }
}
