import XCTest
@testable import SwiftXLSX

final class CellRangeTests: XCTestCase {

    // MARK: - Construction from string range

    func testConstructFromStringRange_A1B10() {
        let range = CellRange("A1:B10")
        XCTAssertEqual(range.start.column, 1)
        XCTAssertEqual(range.start.row, 1)
        XCTAssertEqual(range.end.column, 2)
        XCTAssertEqual(range.end.row, 10)
    }

    func testConstructFromStringRange_C3E7() {
        let range = CellRange("C3:E7")
        XCTAssertEqual(range.start.column, 3)
        XCTAssertEqual(range.start.row, 3)
        XCTAssertEqual(range.end.column, 5)
        XCTAssertEqual(range.end.row, 7)
    }

    // MARK: - Construction from CellRefs

    func testConstructFromCellRefs() {
        let start = CellRef("A1")
        let end = CellRef("B10")
        let range = CellRange(from: start, to: end)
        XCTAssertEqual(range.start.column, 1)
        XCTAssertEqual(range.start.row, 1)
        XCTAssertEqual(range.end.column, 2)
        XCTAssertEqual(range.end.row, 10)
    }

    // MARK: - Construction from strings (from:to:)

    func testConstructFromStrings() {
        let range = CellRange(from: "D2", to: "F8")
        XCTAssertEqual(range.start.column, 4)
        XCTAssertEqual(range.start.row, 2)
        XCTAssertEqual(range.end.column, 6)
        XCTAssertEqual(range.end.row, 8)
    }

    // MARK: - Single cell range

    func testSingleCellRange() {
        let range = CellRange("A1")
        XCTAssertEqual(range.start.column, range.end.column)
        XCTAssertEqual(range.start.row, range.end.row)
        XCTAssertEqual(range.rowCount, 1)
        XCTAssertEqual(range.columnCount, 1)
    }

    func testSingleCellRangeCells() {
        let range = CellRange("B5")
        let cells = range.cells
        XCTAssertEqual(cells.count, 1)
        XCTAssertEqual(cells[0].column, 2)
        XCTAssertEqual(cells[0].row, 5)
    }

    // MARK: - reference property

    func testReferenceRoundTrip() {
        let range = CellRange("A1:B10")
        XCTAssertEqual(range.reference, "A1:B10")
    }

    func testReferenceRoundTripSingleCell() {
        let range = CellRange("C5")
        XCTAssertEqual(range.reference, "C5")
    }

    func testReferenceWithAbsolute() {
        let range = CellRange("$A$1:$B$10")
        XCTAssertEqual(range.reference, "$A$1:$B$10")
    }

    func testReferenceMixedAbsolute() {
        let range = CellRange("$A1:B$10")
        XCTAssertEqual(range.reference, "$A1:B$10")
    }

    // MARK: - absolute()

    func testAbsolute() {
        let range = CellRange("A1:B5")
        let abs = range.absolute()
        XCTAssertEqual(abs.reference, "$A$1:$B$5")
    }

    func testAbsoluteAlreadyAbsolute() {
        let range = CellRange("$A$1:$B$5")
        let abs = range.absolute()
        XCTAssertEqual(abs.reference, "$A$1:$B$5")
    }

    func testAbsoluteSingleCell() {
        let range = CellRange("C3")
        let abs = range.absolute()
        XCTAssertEqual(abs.reference, "$C$3")
    }

    // MARK: - cells iteration

    func testCellsA1C3() {
        let range = CellRange("A1:C3")
        let cells = range.cells
        XCTAssertEqual(cells.count, 9)

        // Row 1: A1, B1, C1
        XCTAssertEqual(cells[0].column, 1)
        XCTAssertEqual(cells[0].row, 1)
        XCTAssertEqual(cells[1].column, 2)
        XCTAssertEqual(cells[1].row, 1)
        XCTAssertEqual(cells[2].column, 3)
        XCTAssertEqual(cells[2].row, 1)

        // Row 2: A2, B2, C2
        XCTAssertEqual(cells[3].column, 1)
        XCTAssertEqual(cells[3].row, 2)
        XCTAssertEqual(cells[4].column, 2)
        XCTAssertEqual(cells[4].row, 2)
        XCTAssertEqual(cells[5].column, 3)
        XCTAssertEqual(cells[5].row, 2)

        // Row 3: A3, B3, C3
        XCTAssertEqual(cells[6].column, 1)
        XCTAssertEqual(cells[6].row, 3)
        XCTAssertEqual(cells[7].column, 2)
        XCTAssertEqual(cells[7].row, 3)
        XCTAssertEqual(cells[8].column, 3)
        XCTAssertEqual(cells[8].row, 3)
    }

    func testCellsReferenceStrings() {
        let range = CellRange("A1:C3")
        let refs = range.cells.map(\.reference)
        XCTAssertEqual(refs, [
            "A1", "B1", "C1",
            "A2", "B2", "C2",
            "A3", "B3", "C3",
        ])
    }

    // MARK: - Single column cells

    func testCellsSingleColumn() {
        let range = CellRange("A1:A5")
        let cells = range.cells
        XCTAssertEqual(cells.count, 5)
        for (i, cell) in cells.enumerated() {
            XCTAssertEqual(cell.column, 1)
            XCTAssertEqual(cell.row, i + 1)
        }
    }

    // MARK: - Single row cells

    func testCellsSingleRow() {
        let range = CellRange("A1:E1")
        let cells = range.cells
        XCTAssertEqual(cells.count, 5)
        for (i, cell) in cells.enumerated() {
            XCTAssertEqual(cell.column, i + 1)
            XCTAssertEqual(cell.row, 1)
        }
    }

    // MARK: - rowCount and columnCount

    func testRowCount() {
        let range = CellRange("A1:A10")
        XCTAssertEqual(range.rowCount, 10)
    }

    func testColumnCount() {
        let range = CellRange("A1:E1")
        XCTAssertEqual(range.columnCount, 5)
    }

    func testRowAndColumnCount() {
        let range = CellRange("B2:D6")
        XCTAssertEqual(range.rowCount, 5)
        XCTAssertEqual(range.columnCount, 3)
    }

    // MARK: - Equatable

    func testEquatable_SameRangeDifferentConstruction() {
        let range1 = CellRange("A1:B5")
        let range2 = CellRange(from: CellRef("A1"), to: CellRef("B5"))
        XCTAssertEqual(range1, range2)
    }

    func testEquatable_DifferentRanges() {
        let range1 = CellRange("A1:B5")
        let range2 = CellRange("A1:C5")
        XCTAssertNotEqual(range1, range2)
    }

    // MARK: - Hashable

    func testHashable_SetElement() {
        let range1 = CellRange("A1:B5")
        let range2 = CellRange("A1:B5")
        let range3 = CellRange("C1:D5")

        var set = Set<CellRange>()
        set.insert(range1)
        set.insert(range2)
        set.insert(range3)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Multi-letter column

    func testMultiLetterColumn() {
        let range = CellRange("AA1:AB3")
        XCTAssertEqual(range.start.column, 27)
        XCTAssertEqual(range.end.column, 28)
        XCTAssertEqual(range.columnCount, 2)
        XCTAssertEqual(range.rowCount, 3)
        XCTAssertEqual(range.cells.count, 6)
    }
}
