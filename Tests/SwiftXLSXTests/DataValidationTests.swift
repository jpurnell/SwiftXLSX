import XCTest
@testable import SwiftXLSX

final class DataValidationTests: XCTestCase {

    func testValidationsDefaultsToEmpty() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        XCTAssertTrue(ws.validations.isEmpty)
    }

    func testAddListValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "A10")
        ws.addValidation(range, type: .list(["Yes", "No"]))
        XCTAssertEqual(ws.validations.count, 1)
    }

    func testAddDecimalValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "B1", to: "B5")
        ws.addValidation(range, type: .decimal(min: 0.0, max: 100.0))
        XCTAssertEqual(ws.validations.count, 1)
    }

    func testAddIntegerValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "C1", to: "C20")
        ws.addValidation(range, type: .integer(min: 1, max: 10))
        XCTAssertEqual(ws.validations.count, 1)
    }

    func testMultipleValidationsOnDifferentRanges() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "A1", to: "A10"), type: .list(["Red", "Blue"]))
        ws.addValidation(CellRange(from: "B1", to: "B10"), type: .decimal(min: 0, max: 50))
        ws.addValidation(CellRange(from: "C1", to: "C10"), type: .integer(min: 0, max: 999))
        XCTAssertEqual(ws.validations.count, 3)
    }

    func testListValidationStoresAllItems() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let items = ["Apple", "Banana", "Cherry", "Date"]
        ws.addValidation(CellRange(from: "A1", to: "A5"), type: .list(items))
        guard case .list(let stored) = ws.validations[0].type else {
            XCTFail("Expected list validation")
            return
        }
        XCTAssertEqual(stored, items)
    }

    func testDecimalValidationStoresMinMax() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "D1", to: "D10"), type: .decimal(min: -5.5, max: 99.9))
        guard case .decimal(let min, let max) = ws.validations[0].type else {
            XCTFail("Expected decimal validation")
            return
        }
        XCTAssertEqual(min, -5.5)
        XCTAssertEqual(max, 99.9)
    }

    func testIntegerValidationStoresMinMax() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        ws.addValidation(CellRange(from: "E1", to: "E10"), type: .integer(min: -100, max: 100))
        guard case .integer(let min, let max) = ws.validations[0].type else {
            XCTFail("Expected integer validation")
            return
        }
        XCTAssertEqual(min, -100)
        XCTAssertEqual(max, 100)
    }

    func testRangeReferenceIsCorrect() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange(from: "A1", to: "B10")
        ws.addValidation(range, type: .list(["X"]))
        XCTAssertEqual(ws.validations[0].range.reference, "A1:B10")
    }

    func testSingleCellRangeValidation() {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        let range = CellRange("A1")
        ws.addValidation(range, type: .integer(min: 0, max: 10))
        XCTAssertEqual(ws.validations[0].range.reference, "A1")
    }
}
