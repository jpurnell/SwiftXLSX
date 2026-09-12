import XCTest
@testable import SwiftXLSX

final class AutoFilterTests: XCTestCase {

    func testAutoFilterDefaultIsNil() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertNil(ws.autoFilterRange)
    }

    func testSetAutoFilterSetsRange() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "D100")
        ws.setAutoFilter(range)
        XCTAssertNotNil(ws.autoFilterRange)
    }

    func testAutoFilterRangeReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "A1", to: "D100"))
        XCTAssertEqual(ws.autoFilterRange?.reference, "A1:D100")
    }

    func testAutoFilterSingleColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "B1", to: "B50"))
        XCTAssertEqual(ws.autoFilterRange?.reference, "B1:B50")
    }

    func testAutoFilterOverwrite() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setAutoFilter(CellRange(from: "A1", to: "C10"))
        ws.setAutoFilter(CellRange(from: "A1", to: "F200"))
        XCTAssertEqual(ws.autoFilterRange?.reference, "A1:F200")
    }

    func testAutoFilterPreservesStartAndEnd() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "C3", to: "G15")
        ws.setAutoFilter(range)
        XCTAssertEqual(ws.autoFilterRange?.start, CellRef("C3"))
        XCTAssertEqual(ws.autoFilterRange?.end, CellRef("G15"))
    }
}
