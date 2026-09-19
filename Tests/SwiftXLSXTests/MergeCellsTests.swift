import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct MergeCellsTests {

    @Test("Default merged cells is empty")
    func testDefaultMergedCellsIsEmpty() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.mergedCells.isEmpty)
    }

    @Test("Merge cells adds range")
    func testMergeCellsAddsRange() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "B2")
        ws.mergeCells(range)
        #expect(ws.mergedCells.count == 1)
        #expect(ws.mergedCells[0] == range)
    }

    @Test("Merge cells allows multiple ranges")
    func testMergeCellsAllowsMultipleRanges() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.mergeCells(CellRange(from: "A1", to: "B2"))
        ws.mergeCells(CellRange(from: "D1", to: "F3"))
        ws.mergeCells(CellRange(from: "A5", to: "C5"))
        #expect(ws.mergedCells.count == 3)
    }

    @Test("Cell range reference format")
    func testCellRangeReferenceFormat() {
        let range = CellRange(from: "A1", to: "B2")
        #expect(range.reference == "A1:B2")
    }

    @Test("Merge single row")
    func testMergeSingleRow() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "C1")
        ws.mergeCells(range)
        #expect(ws.mergedCells[0].reference == "A1:C1")
        #expect(ws.mergedCells[0].rowCount == 1)
        #expect(ws.mergedCells[0].columnCount == 3)
    }

    @Test("Merge single column")
    func testMergeSingleColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "A5")
        ws.mergeCells(range)
        #expect(ws.mergedCells[0].reference == "A1:A5")
        #expect(ws.mergedCells[0].rowCount == 5)
        #expect(ws.mergedCells[0].columnCount == 1)
    }

    @Test("Count increases with each merge")
    func testCountIncreasesWithEachMerge() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.mergedCells.count == 0)
        ws.mergeCells(CellRange(from: "A1", to: "B2"))
        #expect(ws.mergedCells.count == 1)
        ws.mergeCells(CellRange(from: "C1", to: "D2"))
        #expect(ws.mergedCells.count == 2)
        ws.mergeCells(CellRange(from: "E1", to: "F2"))
        #expect(ws.mergedCells.count == 3)
    }

    @Test("Merged range preserves start and end")
    func testMergedRangePreservesStartAndEnd() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "B3", to: "D7")
        ws.mergeCells(range)
        #expect(ws.mergedCells[0].start == CellRef("B3"))
        #expect(ws.mergedCells[0].end == CellRef("D7"))
    }
}
