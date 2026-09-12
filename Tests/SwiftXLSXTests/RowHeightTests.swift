import XCTest
@testable import SwiftXLSX

final class RowHeightTests: XCTestCase {
    func testDefaultRowHeightsIsEmpty() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertTrue(ws.rowHeights.isEmpty)
    }

    func testSetRowHeightStoresHeight() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 25.0)
        XCTAssertEqual(ws.rowHeights[1], 25.0)
    }

    func testSetMultipleRowHeights() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 20.0)
        ws.setRowHeight(row: 2, height: 30.0)
        ws.setRowHeight(row: 5, height: 15.0)
        XCTAssertEqual(ws.rowHeights.count, 3)
        XCTAssertEqual(ws.rowHeights[1], 20.0)
        XCTAssertEqual(ws.rowHeights[2], 30.0)
        XCTAssertEqual(ws.rowHeights[5], 15.0)
    }

    func testOverwriteRowHeight() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 3, height: 20.0)
        ws.setRowHeight(row: 3, height: 50.0)
        XCTAssertEqual(ws.rowHeights[3], 50.0)
        XCTAssertEqual(ws.rowHeights.count, 1)
    }

    func testDifferentRowsAreIndependent() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 10.0)
        ws.setRowHeight(row: 2, height: 99.0)
        XCTAssertEqual(ws.rowHeights[1], 10.0)
        XCTAssertEqual(ws.rowHeights[2], 99.0)
        XCTAssertNotEqual(ws.rowHeights[1], ws.rowHeights[2])
    }

    func testFractionalHeightPreservedExactly() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 7, height: 40.5)
        XCTAssertEqual(ws.rowHeights[7], 40.5)
    }

    func testUnsetRowReturnsNil() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 20.0)
        XCTAssertNil(ws.rowHeights[999])
    }
}
