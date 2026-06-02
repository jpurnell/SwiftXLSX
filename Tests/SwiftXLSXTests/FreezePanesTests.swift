import XCTest
@testable import SwiftXLSX

final class FreezePanesTests: XCTestCase {
    func testDefaultFrozenPaneRefIsNil() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertNil(ws.frozenPaneRef)
    }

    func testFreezePanesSetsReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "D5")
        XCTAssertEqual(ws.frozenPaneRef, "D5")
    }

    func testFreezeAtA2FreezesFirstRow() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "A2")
        XCTAssertEqual(ws.frozenPaneRef, "A2")
    }

    func testFreezeAtB1FreezesFirstColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "B1")
        XCTAssertEqual(ws.frozenPaneRef, "B1")
    }

    func testFreezeAtC3FreezesRowsAndColumns() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "C3")
        XCTAssertEqual(ws.frozenPaneRef, "C3")
    }

    func testOverwriteFreezePaneReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "A2")
        XCTAssertEqual(ws.frozenPaneRef, "A2")
        ws.freezePanes(at: "C5")
        XCTAssertEqual(ws.frozenPaneRef, "C5")
    }
}
