import XCTest
@testable import SwiftXLSX

final class MergeCellsTests: XCTestCase {

    func testDefaultMergedCellsIsEmpty() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertTrue(ws.mergedCells.isEmpty)
    }

    func testMergeCellsAddsRange() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "B2")
        ws.mergeCells(range)
        XCTAssertEqual(ws.mergedCells.count, 1)
        XCTAssertEqual(ws.mergedCells[0], range)
    }

    func testMergeCellsAllowsMultipleRanges() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.mergeCells(CellRange(from: "A1", to: "B2"))
        ws.mergeCells(CellRange(from: "D1", to: "F3"))
        ws.mergeCells(CellRange(from: "A5", to: "C5"))
        XCTAssertEqual(ws.mergedCells.count, 3)
    }

    func testCellRangeReferenceFormat() {
        let range = CellRange(from: "A1", to: "B2")
        XCTAssertEqual(range.reference, "A1:B2")
    }

    func testMergeSingleRow() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "C1")
        ws.mergeCells(range)
        XCTAssertEqual(ws.mergedCells[0].reference, "A1:C1")
        XCTAssertEqual(ws.mergedCells[0].rowCount, 1)
        XCTAssertEqual(ws.mergedCells[0].columnCount, 3)
    }

    func testMergeSingleColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "A5")
        ws.mergeCells(range)
        XCTAssertEqual(ws.mergedCells[0].reference, "A1:A5")
        XCTAssertEqual(ws.mergedCells[0].rowCount, 5)
        XCTAssertEqual(ws.mergedCells[0].columnCount, 1)
    }

    func testCountIncreasesWithEachMerge() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertEqual(ws.mergedCells.count, 0)
        ws.mergeCells(CellRange(from: "A1", to: "B2"))
        XCTAssertEqual(ws.mergedCells.count, 1)
        ws.mergeCells(CellRange(from: "C1", to: "D2"))
        XCTAssertEqual(ws.mergedCells.count, 2)
        ws.mergeCells(CellRange(from: "E1", to: "F2"))
        XCTAssertEqual(ws.mergedCells.count, 3)
    }

    func testMergedRangePreservesStartAndEnd() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "B3", to: "D7")
        ws.mergeCells(range)
        XCTAssertEqual(ws.mergedCells[0].start, CellRef("B3"))
        XCTAssertEqual(ws.mergedCells[0].end, CellRef("D7"))
    }
}
