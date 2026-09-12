import XCTest
@testable import SwiftXLSX

final class CellValueProviderTests: XCTestCase {

    // MARK: - Worksheet Value Lookup

    func testValueAtExistingCellRef() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(42.0, to: "A1")

        let ref = CellRef("A1")
        let result = sheet.value(at: ref)

        XCTAssertEqual(result, .number(42.0))
    }

    func testValueAtMissingCellRefReturnsNil() {
        let sheet = Worksheet(name: "Sheet1")

        let ref = CellRef("Z99")
        let result = sheet.value(at: ref)

        XCTAssertNil(result)
    }

    func testValueAtTextCell() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write("hello", to: "B2")

        let ref = CellRef("B2")
        let result = sheet.value(at: ref)

        XCTAssertEqual(result, .text("hello"))
    }

    func testValueAtNumericCell() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(3.14, to: "C3")

        let ref = CellRef("C3")
        let result = sheet.value(at: ref)

        XCTAssertEqual(result, .number(3.14))
    }

    func testValueAtIntegerCell() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(100, to: "D4")

        let ref = CellRef("D4")
        let result = sheet.value(at: ref)

        XCTAssertEqual(result, .number(100.0))
    }

    // MARK: - Values in Range

    func testValuesInSingleCellRange() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")

        let range = CellRange("A1")
        let results = sheet.values(in: range)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, .number(10.0))
    }

    func testValuesInColumnRange() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(1.0, to: "A1")
        sheet.write(2.0, to: "A2")
        sheet.write(3.0, to: "A3")

        let range = CellRange(from: "A1", to: "A3")
        let results = sheet.values(in: range)

        XCTAssertEqual(results, [.number(1.0), .number(2.0), .number(3.0)])
    }

    func testValuesInRowRange() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write("a", to: "A1")
        sheet.write("b", to: "B1")
        sheet.write("c", to: "C1")

        let range = CellRange(from: "A1", to: "C1")
        let results = sheet.values(in: range)

        XCTAssertEqual(results, [.text("a"), .text("b"), .text("c")])
    }

    func testValuesInRectangularRange() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(1.0, to: "A1")
        sheet.write(2.0, to: "B1")
        sheet.write(3.0, to: "A2")
        sheet.write(4.0, to: "B2")

        let range = CellRange(from: "A1", to: "B2")
        let results = sheet.values(in: range)

        XCTAssertEqual(results, [
            .number(1.0), .number(2.0),
            .number(3.0), .number(4.0)
        ])
    }

    func testValuesInRangeSkipsEmptyCells() {
        let sheet = Worksheet(name: "Sheet1")
        sheet.write(1.0, to: "A1")
        // A2 is empty
        sheet.write(3.0, to: "A3")

        let range = CellRange(from: "A1", to: "A3")
        let results = sheet.values(in: range)

        // compactMap skips nil values
        XCTAssertEqual(results, [.number(1.0), .number(3.0)])
    }

    func testValuesInEmptyRange() {
        let sheet = Worksheet(name: "Sheet1")

        let range = CellRange(from: "A1", to: "C3")
        let results = sheet.values(in: range)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - CellValueProvider Protocol Conformance

    func testWorkbookProviderValueAtRef() {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(42.0, to: "A1")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")
        let ref = CellRef("A1")
        let result = provider.value(at: ref)

        XCTAssertEqual(result, .number(42.0))
    }

    func testWorkbookProviderValueAtRefInSheet() {
        let workbook = Workbook()
        let sheet1 = workbook.addSheet(name: "Sheet1")
        let sheet2 = workbook.addSheet(name: "Sheet2")
        sheet1.write(10.0, to: "A1")
        sheet2.write(20.0, to: "A1")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")

        XCTAssertEqual(provider.value(at: CellRef("A1")), .number(10.0))
        XCTAssertEqual(provider.value(at: CellRef("A1"), inSheet: "Sheet2"), .number(20.0))
    }

    func testWorkbookProviderValueInMissingSheetReturnsNil() {
        let workbook = Workbook()
        _ = workbook.addSheet(name: "Sheet1")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")

        XCTAssertNil(provider.value(at: CellRef("A1"), inSheet: "NoSuchSheet"))
    }

    func testWorkbookProviderValuesInRange() {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(1.0, to: "A1")
        sheet.write(2.0, to: "A2")
        sheet.write(3.0, to: "A3")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")
        let range = CellRange(from: "A1", to: "A3")

        XCTAssertEqual(provider.values(in: range), [.number(1.0), .number(2.0), .number(3.0)])
    }

    func testWorkbookProviderValuesInRangeInSheet() {
        let workbook = Workbook()
        _ = workbook.addSheet(name: "Sheet1")
        let sheet2 = workbook.addSheet(name: "Sheet2")
        sheet2.write(10.0, to: "B1")
        sheet2.write(20.0, to: "B2")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")
        let range = CellRange(from: "B1", to: "B2")

        XCTAssertEqual(provider.values(in: range, inSheet: "Sheet2"), [.number(10.0), .number(20.0)])
    }

    func testWorkbookProviderValuesInMissingSheetReturnsEmpty() {
        let workbook = Workbook()
        _ = workbook.addSheet(name: "Sheet1")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")
        let range = CellRange(from: "A1", to: "A3")

        XCTAssertTrue(provider.values(in: range, inSheet: "NoSuchSheet").isEmpty)
    }

    // MARK: - Protocol Existential Usage

    func testProtocolCanBeUsedExistentially() {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(99.0, to: "A1")

        let provider: any CellValueProvider = WorkbookValueProvider(
            workbook: workbook,
            currentSheet: "Sheet1"
        )

        XCTAssertEqual(provider.value(at: CellRef("A1")), .number(99.0))
    }
}
