import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct RowHeightTests {
    @Test("Default row heights is empty")
    func testDefaultRowHeightsIsEmpty() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.rowHeights.isEmpty)
    }

    @Test("Set row height stores height")
    func testSetRowHeightStoresHeight() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 25.0)
        #expect(try #require(ws.rowHeights[1]).isEqual(to: 25.0))
    }

    @Test("Set multiple row heights")
    func testSetMultipleRowHeights() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 20.0)
        ws.setRowHeight(row: 2, height: 30.0)
        ws.setRowHeight(row: 5, height: 15.0)
        #expect(ws.rowHeights.count == 3)
        #expect(try #require(ws.rowHeights[1]).isEqual(to: 20.0))
        #expect(try #require(ws.rowHeights[2]).isEqual(to: 30.0))
        #expect(try #require(ws.rowHeights[5]).isEqual(to: 15.0))
    }

    @Test("Overwrite row height")
    func testOverwriteRowHeight() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 3, height: 20.0)
        ws.setRowHeight(row: 3, height: 50.0)
        #expect(try #require(ws.rowHeights[3]).isEqual(to: 50.0))
        #expect(ws.rowHeights.count == 1)
    }

    @Test("Different rows are independent")
    func testDifferentRowsAreIndependent() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 10.0)
        ws.setRowHeight(row: 2, height: 99.0)
        #expect(try #require(ws.rowHeights[1]).isEqual(to: 10.0))
        #expect(try #require(ws.rowHeights[2]).isEqual(to: 99.0))
        #expect(ws.rowHeights[1] != ws.rowHeights[2])
    }

    @Test("Fractional height preserved exactly")
    func testFractionalHeightPreservedExactly() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 7, height: 40.5)
        #expect(try #require(ws.rowHeights[7]).isEqual(to: 40.5))
    }

    @Test("Unset row returns nil")
    func testUnsetRowReturnsNil() throws {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.setRowHeight(row: 1, height: 20.0)
        #expect(ws.rowHeights[999] == nil)
    }
}
