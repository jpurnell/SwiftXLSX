import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct DataValidationTests {

    @Test("Validations defaults to empty")
    func testValidationsDefaultsToEmpty() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        #expect(ws.validations.isEmpty)
    }

    @Test("Add list validation")
    func testAddListValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "A10")
        ws.addValidation(range, type: .list(["Yes", "No"]))
        #expect(ws.validations.count == 1)
    }

    @Test("Add decimal validation")
    func testAddDecimalValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "B1", to: "B5")
        ws.addValidation(range, type: .decimal(min: 0.0, max: 100.0))
        #expect(ws.validations.count == 1)
    }

    @Test("Add integer validation")
    func testAddIntegerValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "C1", to: "C20")
        ws.addValidation(range, type: .integer(min: 1, max: 10))
        #expect(ws.validations.count == 1)
    }

    @Test("Multiple validations on different ranges")
    func testMultipleValidationsOnDifferentRanges() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "A1", to: "A10"), type: .list(["Red", "Blue"]))
        ws.addValidation(CellRange(from: "B1", to: "B10"), type: .decimal(min: 0, max: 50))
        ws.addValidation(CellRange(from: "C1", to: "C10"), type: .integer(min: 0, max: 999))
        #expect(ws.validations.count == 3)
    }

    @Test("List validation stores all items")
    func testListValidationStoresAllItems() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let items = ["Apple", "Banana", "Cherry", "Date"]
        ws.addValidation(CellRange(from: "A1", to: "A5"), type: .list(items))
        guard case .list(let stored) = ws.validations[0].type else {
            Issue.record("Expected list validation")
            return
        }
        #expect(stored == items)
    }

    @Test("Decimal validation stores min max")
    func testDecimalValidationStoresMinMax() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "D1", to: "D10"), type: .decimal(min: -5.5, max: 99.9))
        guard case .decimal(let min, let max) = ws.validations[0].type else {
            Issue.record("Expected decimal validation")
            return
        }
        #expect(min == -5.5)
        #expect(max.isEqual(to: 99.9))
    }

    @Test("Integer validation stores min max")
    func testIntegerValidationStoresMinMax() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "E1", to: "E10"), type: .integer(min: -100, max: 100))
        guard case .integer(let min, let max) = ws.validations[0].type else {
            Issue.record("Expected integer validation")
            return
        }
        #expect(min == -100)
        #expect(max == 100)
    }

    @Test("Range reference is correct")
    func testRangeReferenceIsCorrect() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "B10")
        ws.addValidation(range, type: .list(["X"]))
        #expect(ws.validations[0].range.reference == "A1:B10")
    }

    @Test("Single cell range validation")
    func testSingleCellRangeValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange("A1")
        ws.addValidation(range, type: .integer(min: 0, max: 10))
        #expect(ws.validations[0].range.reference == "A1")
    }
}
