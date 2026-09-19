import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FreezePanesTests {
    @Test("Default frozen pane ref is nil")
    func testDefaultFrozenPaneRefIsNil() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.frozenPaneRef == nil)
    }

    @Test("Freeze panes sets reference")
    func testFreezePanesSetsReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "D5")
        #expect(ws.frozenPaneRef == "D5")
    }

    @Test("Freeze at A 2 freezes first row")
    func testFreezeAtA2FreezesFirstRow() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "A2")
        #expect(ws.frozenPaneRef == "A2")
    }

    @Test("Freeze at B 1 freezes first column")
    func testFreezeAtB1FreezesFirstColumn() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "B1")
        #expect(ws.frozenPaneRef == "B1")
    }

    @Test("Freeze at C 3 freezes rows and columns")
    func testFreezeAtC3FreezesRowsAndColumns() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "C3")
        #expect(ws.frozenPaneRef == "C3")
    }

    @Test("Overwrite freeze pane reference")
    func testOverwriteFreezePaneReference() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.freezePanes(at: "A2")
        #expect(ws.frozenPaneRef == "A2")
        ws.freezePanes(at: "C5")
        #expect(ws.frozenPaneRef == "C5")
    }
}
