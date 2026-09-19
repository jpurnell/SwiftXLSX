import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct AutoFilterTests {

    @Test("Auto filter default is nil")
    func testAutoFilterDefaultIsNil() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.autoFilterRange == nil)
    }

    @Test("Set auto filter sets range")
    func testSetAutoFilterSetsRange() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "D100")
        ws.setAutoFilter(range)
        #expect(ws.autoFilterRange == range)
    }

    @Test("Auto filter range reference")
    func testAutoFilterRangeReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "A1", to: "D100"))
        #expect(ws.autoFilterRange?.reference == "A1:D100")
    }

    @Test("Auto filter single column")
    func testAutoFilterSingleColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "B1", to: "B50"))
        #expect(ws.autoFilterRange?.reference == "B1:B50")
    }

    @Test("Auto filter overwrite")
    func testAutoFilterOverwrite() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "A1", to: "C10"))
        ws.setAutoFilter(CellRange(from: "A1", to: "F200"))
        #expect(ws.autoFilterRange?.reference == "A1:F200")
    }

    @Test("Auto filter preserves start and end")
    func testAutoFilterPreservesStartAndEnd() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "C3", to: "G15")
        ws.setAutoFilter(range)
        #expect(ws.autoFilterRange?.start == CellRef("C3"))
        #expect(ws.autoFilterRange?.end == CellRef("G15"))
    }
}
