import XCTest
@testable import SwiftXLSX
import SwiftZIP
import Foundation

final class WorkbookReaderTests: XCTestCase {

    // MARK: - Helpers

    /// Saves a workbook to in-memory data, then reads it back.
    private func roundTrip(_ workbook: Workbook) throws -> Workbook {
        let data = try workbook.save()
        return try Workbook(xlsxData: data)
    }

    // MARK: - Basic Reading

    func testReadSingleSheetSingleCell() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Data")
        sheet.write("Hello", to: "A1")

        let result = try roundTrip(wb)

        XCTAssertEqual(result.sheets.count, 1)
        XCTAssertEqual(result.sheets[0].name, "Data")
        XCTAssertEqual(result.sheets[0].cell(at: "A1"), .text("Hello"))
    }

    func testReadMultipleSheets() throws {
        let wb = Workbook()
        _ = wb.addSheet(name: "Inputs")
        _ = wb.addSheet(name: "Calculations")
        _ = wb.addSheet(name: "Results")

        let result = try roundTrip(wb)

        XCTAssertEqual(result.sheets.count, 3)
        XCTAssertEqual(result.sheets[0].name, "Inputs")
        XCTAssertEqual(result.sheets[1].name, "Calculations")
        XCTAssertEqual(result.sheets[2].name, "Results")
    }

    func testReadEmptySheet() throws {
        let wb = Workbook()
        _ = wb.addSheet(name: "Empty")

        let result = try roundTrip(wb)

        XCTAssertEqual(result.sheets.count, 1)
        XCTAssertEqual(result.sheets[0].name, "Empty")
        XCTAssertNil(result.sheets[0].cell(at: "A1"))
    }

    // MARK: - Cell Types

    func testReadTextCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Text")
        sheet.write("Revenue", to: "A1")
        sheet.write("Expenses", to: "A2")
        sheet.write("Profit", to: "A3")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.cell(at: "A1"), .text("Revenue"))
        XCTAssertEqual(s.cell(at: "A2"), .text("Expenses"))
        XCTAssertEqual(s.cell(at: "A3"), .text("Profit"))
    }

    func testReadNumberCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Numbers")
        sheet.write(1_950_000.0, to: "B1")
        sheet.write(42.5, to: "B2")
        sheet.write(0.0, to: "B3")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.cell(at: "B1"), .number(1_950_000))
        XCTAssertEqual(s.cell(at: "B2"), .number(42.5))
        XCTAssertEqual(s.cell(at: "B3"), .number(0))
    }

    func testReadFormulaCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Formulas")
        sheet.write(100.0, to: "B1")
        sheet.writeFormula("B1*0.2", to: "B2")
        sheet.writeFormula("SUM(B1:B2)", to: "B3")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        // Verify formulas were read back
        guard let b2 = s.cell(at: "B2") else {
            XCTFail("B2 should have a value")
            return
        }
        XCTAssertTrue(b2.isFormula, "B2 should be a formula")

        guard let b3 = s.cell(at: "B3") else {
            XCTFail("B3 should have a value")
            return
        }
        XCTAssertTrue(b3.isFormula, "B3 should be a formula")
    }

    func testReadBooleanCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Bools")
        // Write boolean values directly via internal API
        sheet.setCell("A1", value: .bool(true), style: .general)
        sheet.setCell("A2", value: .bool(false), style: .general)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.cell(at: "A1"), .bool(true))
        XCTAssertEqual(s.cell(at: "A2"), .bool(false))
    }

    func testReadMixedCellTypes() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Mixed")
        sheet.write("Label", to: "A1")
        sheet.write(42.0, to: "B1")
        sheet.writeFormula("B1*2", to: "C1")
        sheet.setCell("D1", value: .bool(true), style: .general)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.cell(at: "A1"), .text("Label"))
        XCTAssertEqual(s.cell(at: "B1"), .number(42))
        if let c1 = s.cell(at: "C1") {
            XCTAssertTrue(c1.isFormula)
        } else {
            XCTFail("C1 should have a formula")
        }
        XCTAssertEqual(s.cell(at: "D1"), .bool(true))
    }

    // MARK: - Styles

    func testReadHeaderStyleBoldFont() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Styled")
        sheet.write("Title", to: "A1", style: .header)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        // Verify the cell value
        XCTAssertEqual(s.cell(at: "A1"), .text("Title"))

        // Access the cell's style through the internal cells dictionary
        // and verify the font is bold
        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertTrue(style.font.bold, "Header style should have bold font")
    }

    func testReadCurrencyStyle() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Currency")
        sheet.write(1234.56, to: "A1", style: .currency)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.cell(at: "A1"), .number(1234.56))

        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertEqual(style.numberFormat.formatString, "$#,##0.00")
    }

    func testReadCustomFillColor() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Fills")
        let fillStyle = CellStyle(fill: .solid("FFFF0000"))
        sheet.write("Red", to: "A1", style: fillStyle)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertEqual(style.fill?.patternType, .solid)
        XCTAssertEqual(style.fill?.foregroundColor, "FFFF0000")
    }

    // MARK: - Layout Features

    func testReadFreezePanes() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Frozen")
        sheet.write("Header", to: "A1")
        sheet.freezePanes(at: "A2")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.frozenPaneRef, "A2")
    }

    func testReadAutoFilter() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Filtered")
        sheet.write("Name", to: "A1")
        sheet.write("Value", to: "B1")
        sheet.setAutoFilter(CellRange("A1:B10"))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertNotNil(s.autoFilterRange)
        XCTAssertEqual(s.autoFilterRange?.reference, "A1:B10")
    }

    func testReadMergeCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Merged")
        sheet.write("Title", to: "A1")
        sheet.mergeCells(CellRange("A1:C1"))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.mergedCells.count, 1)
        XCTAssertEqual(s.mergedCells[0].reference, "A1:C1")
    }

    func testReadRowHeights() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Heights")
        sheet.write("Tall row", to: "A1")
        sheet.setRowHeight(row: 1, height: 30)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.rowHeights[1], 30)
    }

    func testReadDataValidationList() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Validation")
        sheet.addValidation(CellRange("A1:A10"), type: .list(["Yes", "No", "Maybe"]))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        XCTAssertEqual(s.validations.count, 1)
        if case .list(let items) = s.validations[0].type {
            XCTAssertEqual(items, ["Yes", "No", "Maybe"])
        } else {
            XCTFail("Expected list validation")
        }
    }

    // MARK: - Error Handling

    func testEmptyDataThrowsZipError() {
        XCTAssertThrowsError(try Workbook(xlsxData: Data())) { error in
            guard let xlsxError = error as? XLSXReadError else {
                XCTFail("Expected XLSXReadError, got \(error)")
                return
            }
            if case .zipError = xlsxError {
                // Expected
            } else {
                XCTFail("Expected .zipError, got \(xlsxError)")
            }
        }
    }

    func testInvalidZipThrowsZipError() {
        let garbage = Data("This is not a ZIP file".utf8)
        XCTAssertThrowsError(try Workbook(xlsxData: garbage)) { error in
            guard let xlsxError = error as? XLSXReadError else {
                XCTFail("Expected XLSXReadError, got \(error)")
                return
            }
            if case .zipError = xlsxError {
                // Expected
            } else {
                XCTFail("Expected .zipError, got \(xlsxError)")
            }
        }
    }

    func testMissingWorkbookXMLThrowsMissingPart() throws {
        // Create a valid ZIP but without workbook.xml by using a helper workbook,
        // saving it, then stripping the workbook.xml entry.
        // We use WorkbookReader directly via the convenience init with crafted data.
        // A ZIP with only a rels file pointing to a missing workbook.xml should throw.
        let minimalZIP = try buildMinimalZIPWithoutWorkbook()

        XCTAssertThrowsError(try Workbook(xlsxData: minimalZIP)) { error in
            guard let xlsxError = error as? XLSXReadError else {
                XCTFail("Expected XLSXReadError, got \(error)")
                return
            }
            if case .missingPart(let part) = xlsxError {
                XCTAssertEqual(part, "xl/workbook.xml")
            } else {
                XCTFail("Expected .missingPart, got \(xlsxError)")
            }
        }
    }

    /// Builds a minimal ZIP that has _rels/.rels pointing to xl/workbook.xml,
    /// but does not include xl/workbook.xml itself.
    private func buildMinimalZIPWithoutWorkbook() throws -> Data {
        // Save a real workbook, then rebuild the ZIP without workbook.xml
        let wb = Workbook()
        _ = wb.addSheet(name: "Test")
        let data = try wb.save()

        // Read the ZIP entries, filter out workbook.xml, re-pack
        let entries = try ZIPReader.read(from: data)
        let filtered = entries.filter { $0.path != "xl/workbook.xml" }
        return try ZIPWriter.write(entries: filtered)
    }

    // MARK: - Convenience Init

    func testInitContentsOfURL() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "URLTest")
        sheet.write("FromFile", to: "A1")
        sheet.write(99.0, to: "B1")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader_test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        try wb.save(to: url)

        let loaded = try Workbook(contentsOf: url)
        XCTAssertEqual(loaded.sheets.count, 1)
        XCTAssertEqual(loaded.sheets[0].name, "URLTest")
        XCTAssertEqual(loaded.sheets[0].cell(at: "A1"), .text("FromFile"))
        XCTAssertEqual(loaded.sheets[0].cell(at: "B1"), .number(99))
    }

    // MARK: - Multi-Cell Round-Trip

    func testRoundTripMultipleCellsAndSheets() throws {
        let wb = Workbook()

        let inputs = wb.addSheet(name: "Inputs")
        inputs.write("Revenue", to: "A1")
        inputs.write(500_000.0, to: "B1")
        inputs.write("Costs", to: "A2")
        inputs.write(350_000.0, to: "B2")

        let calcs = wb.addSheet(name: "Calcs")
        calcs.writeFormula("Inputs!B1-Inputs!B2", to: "A1")

        let result = try roundTrip(wb)

        XCTAssertEqual(result.sheets.count, 2)

        let rInputs = result.sheets[0]
        XCTAssertEqual(rInputs.cell(at: "A1"), .text("Revenue"))
        XCTAssertEqual(rInputs.cell(at: "B1"), .number(500_000))
        XCTAssertEqual(rInputs.cell(at: "A2"), .text("Costs"))
        XCTAssertEqual(rInputs.cell(at: "B2"), .number(350_000))

        let rCalcs = result.sheets[1]
        guard let formula = rCalcs.cell(at: "A1") else {
            XCTFail("A1 should have a formula")
            return
        }
        XCTAssertTrue(formula.isFormula)
    }
}
