import Testing
import Foundation
@testable import SwiftXLSX
import SwiftZIP

@Suite
struct WorkbookReaderTests {

    // MARK: - Helpers

    /// Saves a workbook to in-memory data, then reads it back.
    private func roundTrip(_ workbook: Workbook) throws -> Workbook {
        let data = try workbook.save()
        return try Workbook(xlsxData: data)
    }

    // MARK: - Basic Reading

    @Test("Read single sheet single cell")
    func testReadSingleSheetSingleCell() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Data")
        sheet.write("Hello", to: "A1")

        let result = try roundTrip(wb)

        #expect(result.sheets.count == 1)
        #expect(result.sheets[0].name == "Data")
        #expect(result.sheets[0].cell(at: "A1") == .text("Hello"))
    }

    @Test("Read multiple sheets")
    func testReadMultipleSheets() throws {
        let wb = Workbook()
        _ = wb.addSheet(name: "Inputs")
        _ = wb.addSheet(name: "Calculations")
        _ = wb.addSheet(name: "Results")

        let result = try roundTrip(wb)

        #expect(result.sheets.count == 3)
        #expect(result.sheets[0].name == "Inputs")
        #expect(result.sheets[1].name == "Calculations")
        #expect(result.sheets[2].name == "Results")
    }

    @Test("Read empty sheet")
    func testReadEmptySheet() throws {
        let wb = Workbook()
        _ = wb.addSheet(name: "Empty")

        let result = try roundTrip(wb)

        #expect(result.sheets.count == 1)
        #expect(result.sheets[0].name == "Empty")
        #expect(result.sheets[0].cell(at: "A1") == nil)
    }

    // MARK: - Cell Types

    @Test("Read text cells")
    func testReadTextCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Text")
        sheet.write("Revenue", to: "A1")
        sheet.write("Expenses", to: "A2")
        sheet.write("Profit", to: "A3")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.cell(at: "A1") == .text("Revenue"))
        #expect(s.cell(at: "A2") == .text("Expenses"))
        #expect(s.cell(at: "A3") == .text("Profit"))
    }

    @Test("Read number cells")
    func testReadNumberCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Numbers")
        sheet.write(1_950_000.0, to: "B1")
        sheet.write(42.5, to: "B2")
        sheet.write(0.0, to: "B3")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.cell(at: "B1") == .number(1_950_000))
        #expect(s.cell(at: "B2") == .number(42.5))
        #expect(s.cell(at: "B3") == .number(0))
    }

    @Test("Read formula cells")
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
            Issue.record("B2 should have a value")
            return
        }
        #expect(b2.isFormula, "B2 should be a formula")

        guard let b3 = s.cell(at: "B3") else {
            Issue.record("B3 should have a value")
            return
        }
        #expect(b3.isFormula, "B3 should be a formula")
    }

    @Test("Read boolean cells")
    func testReadBooleanCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Bools")
        // Write boolean values directly via internal API
        sheet.setCell("A1", value: .bool(true), style: .general)
        sheet.setCell("A2", value: .bool(false), style: .general)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.cell(at: "A1") == .bool(true))
        #expect(s.cell(at: "A2") == .bool(false))
    }

    @Test("Read mixed cell types")
    func testReadMixedCellTypes() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Mixed")
        sheet.write("Label", to: "A1")
        sheet.write(42.0, to: "B1")
        sheet.writeFormula("B1*2", to: "C1")
        sheet.setCell("D1", value: .bool(true), style: .general)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.cell(at: "A1") == .text("Label"))
        #expect(s.cell(at: "B1") == .number(42))
        if let c1 = s.cell(at: "C1") {
            #expect(c1.isFormula)
        } else {
            Issue.record("C1 should have a formula")
        }
        #expect(s.cell(at: "D1") == .bool(true))
    }

    // MARK: - Styles

    @Test("Read header style bold font")
    func testReadHeaderStyleBoldFont() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Styled")
        sheet.write("Title", to: "A1", style: .header)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        // Verify the cell value
        #expect(s.cell(at: "A1") == .text("Title"))

        // Access the cell's style through the internal cells dictionary
        // and verify the font is bold
        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(style.font.bold, "Header style should have bold font")
    }

    @Test("Read currency style")
    func testReadCurrencyStyle() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Currency")
        sheet.write(1234.56, to: "A1", style: .currency)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.cell(at: "A1") == .number(1234.56))

        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(style.numberFormat.formatString == "$#,##0.00")
    }

    @Test("Read custom fill color")
    func testReadCustomFillColor() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Fills")
        let fillStyle = CellStyle(fill: .solid("FFFF0000"))
        sheet.write("Red", to: "A1", style: fillStyle)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        let cells = s.cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(style.fill?.patternType == .solid)
        #expect(style.fill?.foregroundColor == "FFFF0000")
    }

    // MARK: - Layout Features

    @Test("Read freeze panes")
    func testReadFreezePanes() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Frozen")
        sheet.write("Header", to: "A1")
        sheet.freezePanes(at: "A2")

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.frozenPaneRef == "A2")
    }

    @Test("Read auto filter")
    func testReadAutoFilter() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Filtered")
        sheet.write("Name", to: "A1")
        sheet.write("Value", to: "B1")
        sheet.setAutoFilter(CellRange("A1:B10"))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        let filter = try #require(s.autoFilterRange)
        #expect(filter == CellRange("A1:B10"))
        #expect(filter.reference == "A1:B10")
    }

    @Test("Read merge cells")
    func testReadMergeCells() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Merged")
        sheet.write("Title", to: "A1")
        sheet.mergeCells(CellRange("A1:C1"))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.mergedCells.count == 1)
        #expect(s.mergedCells[0].reference == "A1:C1")
    }

    @Test("Read row heights")
    func testReadRowHeights() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Heights")
        sheet.write("Tall row", to: "A1")
        sheet.setRowHeight(row: 1, height: 30)

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.rowHeights[1] == 30)
    }

    @Test("Read data validation list")
    func testReadDataValidationList() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Validation")
        sheet.addValidation(CellRange("A1:A10"), type: .list(["Yes", "No", "Maybe"]))

        let result = try roundTrip(wb)
        let s = result.sheets[0]

        #expect(s.validations.count == 1)
        if case .list(let items) = s.validations[0].type {
            #expect(items == ["Yes", "No", "Maybe"])
        } else {
            Issue.record("Expected list validation")
        }
    }

    // MARK: - Error Handling

    @Test("Empty data throws zip error")
    func testEmptyDataThrowsZipError() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try Workbook(xlsxData: Data())
        })
        guard let xlsxError = error as? XLSXReadError else {
            Issue.record("Expected XLSXReadError, got \(error)")
            return
        }
        if case .zipError = xlsxError {
            // Expected
        } else {
            Issue.record("Expected .zipError, got \(xlsxError)")
        }
    }

    @Test("Invalid zip throws zip error")
    func testInvalidZipThrowsZipError() throws {
        let garbage = Data("This is not a ZIP file".utf8)
        let error = try #require(#expect(throws: (any Error).self) {
            try Workbook(xlsxData: garbage)
        })
        guard let xlsxError = error as? XLSXReadError else {
            Issue.record("Expected XLSXReadError, got \(error)")
            return
        }
        if case .zipError = xlsxError {
            // Expected
        } else {
            Issue.record("Expected .zipError, got \(xlsxError)")
        }
    }

    @Test("Missing workbook XML throws missing part")
    func testMissingWorkbookXMLThrowsMissingPart() throws {
        // Create a valid ZIP but without workbook.xml by using a helper workbook,
        // saving it, then stripping the workbook.xml entry.
        // We use WorkbookReader directly via the convenience init with crafted data.
        // A ZIP with only a rels file pointing to a missing workbook.xml should throw.
        let minimalZIP = try buildMinimalZIPWithoutWorkbook()

        let error = try #require(#expect(throws: (any Error).self) {
            try Workbook(xlsxData: minimalZIP)
        })
        guard let xlsxError = error as? XLSXReadError else {
            Issue.record("Expected XLSXReadError, got \(error)")
            return
        }
        if case .missingPart(let part) = xlsxError {
            #expect(part == "xl/workbook.xml")
        } else {
            Issue.record("Expected .missingPart, got \(xlsxError)")
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

    @Test("Init contents of URL")
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
        #expect(loaded.sheets.count == 1)
        #expect(loaded.sheets[0].name == "URLTest")
        #expect(loaded.sheets[0].cell(at: "A1") == .text("FromFile"))
        #expect(loaded.sheets[0].cell(at: "B1") == .number(99))
    }

    // MARK: - Multi-Cell Round-Trip

    @Test("Round trip multiple cells and sheets")
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

        #expect(result.sheets.count == 2)

        let rInputs = result.sheets[0]
        #expect(rInputs.cell(at: "A1") == .text("Revenue"))
        #expect(rInputs.cell(at: "B1") == .number(500_000))
        #expect(rInputs.cell(at: "A2") == .text("Costs"))
        #expect(rInputs.cell(at: "B2") == .number(350_000))

        let rCalcs = result.sheets[1]
        guard let formula = rCalcs.cell(at: "A1") else {
            Issue.record("A1 should have a formula")
            return
        }
        #expect(formula.isFormula)
    }
}
