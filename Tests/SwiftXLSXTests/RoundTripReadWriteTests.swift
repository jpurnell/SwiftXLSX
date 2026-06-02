import XCTest
import SwiftZIP
@testable import SwiftXLSX

final class RoundTripReadWriteTests: XCTestCase {

    // MARK: - Helpers

    /// Saves a workbook to in-memory data, then reads it back.
    private func roundTrip(_ configure: (Workbook) -> Void) throws -> Workbook {
        let original = Workbook()
        configure(original)
        let data = try original.save()
        return try Workbook(xlsxData: data)
    }

    // MARK: - Value Round-Trips

    func testStringValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Hello, World!", to: "A1")
        }

        XCTAssertEqual(wb.sheets.count, 1)
        XCTAssertEqual(wb.sheets[0].cell(at: "A1"), .text("Hello, World!"))
    }

    func testIntegerNumberValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(42.0, to: "A1")
        }

        XCTAssertEqual(wb.sheets[0].cell(at: "A1"), .number(42))
    }

    func testDecimalNumberValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(3.14159, to: "B2")
        }

        XCTAssertEqual(wb.sheets[0].cell(at: "B2"), .number(3.14159))
    }

    func testMultipleCellsOnSameRowSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Name", to: "A1")
            sheet.write("Age", to: "B1")
            sheet.write("City", to: "C1")
        }

        let s = wb.sheets[0]
        XCTAssertEqual(s.cell(at: "A1"), .text("Name"))
        XCTAssertEqual(s.cell(at: "B1"), .text("Age"))
        XCTAssertEqual(s.cell(at: "C1"), .text("City"))
    }

    func testMultipleRowsSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Revenue", to: "A1")
            sheet.write(100_000.0, to: "B1")
            sheet.write("Expenses", to: "A2")
            sheet.write(75_000.0, to: "B2")
            sheet.write("Profit", to: "A3")
            sheet.write(25_000.0, to: "B3")
        }

        let s = wb.sheets[0]
        XCTAssertEqual(s.cell(at: "A1"), .text("Revenue"))
        XCTAssertEqual(s.cell(at: "B1"), .number(100_000))
        XCTAssertEqual(s.cell(at: "A2"), .text("Expenses"))
        XCTAssertEqual(s.cell(at: "B2"), .number(75_000))
        XCTAssertEqual(s.cell(at: "A3"), .text("Profit"))
        XCTAssertEqual(s.cell(at: "B3"), .number(25_000))
    }

    func testEmptyWorkbookRoundTrips() throws {
        let wb = try roundTrip { wb in
            _ = wb.addSheet(name: "Empty")
        }

        XCTAssertEqual(wb.sheets.count, 1)
        XCTAssertEqual(wb.sheets[0].name, "Empty")
        XCTAssertNil(wb.sheets[0].cell(at: "A1"))
    }

    // MARK: - Formula Round-Trips

    func testSimpleFormulaRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(10.0, to: "A1")
            sheet.write(20.0, to: "B1")
            sheet.writeFormula("A1+B1", to: "C1")
        }

        let s = wb.sheets[0]
        guard let c1 = s.cell(at: "C1") else {
            XCTFail("C1 should have a value")
            return
        }
        XCTAssertTrue(c1.isFormula, "C1 should be a formula")

        // Verify the formula AST was parsed back
        guard let ast = s.formulaAST(at: "C1") else {
            XCTFail("C1 should have a formula AST")
            return
        }
        // The formula should be A1+B1, which is .add(.cellRef, .cellRef)
        if case .add(let lhs, let rhs) = ast {
            if case .cellRef(let lRef) = lhs {
                XCTAssertEqual(lRef.reference, "A1")
            } else {
                XCTFail("Left operand should be a cell ref")
            }
            if case .cellRef(let rRef) = rhs {
                XCTAssertEqual(rRef.reference, "B1")
            } else {
                XCTFail("Right operand should be a cell ref")
            }
        } else {
            XCTFail("Expected add AST node, got \(ast)")
        }
    }

    func testFunctionFormulaSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            for i in 1...10 {
                sheet.write(Double(i), to: "A\(i)")
            }
            sheet.writeFormula("SUM(A1:A10)", to: "A11")
        }

        let s = wb.sheets[0]
        guard let ast = s.formulaAST(at: "A11") else {
            XCTFail("A11 should have a formula AST")
            return
        }
        // Verify it's a SUM function
        if case .function(let name, let args) = ast {
            XCTAssertEqual(name, "SUM")
            XCTAssertEqual(args.count, 1)
            if case .cellRange(let range) = args[0] {
                XCTAssertEqual(range.reference, "A1:A10")
            } else {
                XCTFail("SUM argument should be a cell range")
            }
        } else {
            XCTFail("Expected function AST node, got \(ast)")
        }
    }

    func testFormulaWithCachedValueRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(50.0, to: "A1")
            // Write a formula with a cached value using the internal API
            let ast = FormulaAST.multiply(.cellRef(CellRef("A1")), .number(2))
            sheet.setCell("B1", value: .formula(ast, cached: .number(100)), style: .general)
        }

        let s = wb.sheets[0]
        guard let b1 = s.cell(at: "B1") else {
            XCTFail("B1 should have a value")
            return
        }
        XCTAssertTrue(b1.isFormula, "B1 should be a formula")
        // Verify the cached value was preserved
        if case .formula(_, let cached) = b1 {
            XCTAssertEqual(cached, .number(100))
        } else {
            XCTFail("Expected formula with cached value")
        }
    }

    // MARK: - Style Round-Trips

    func testHeaderStyleBoldFontSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Title", to: "A1", style: .header)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertTrue(style.font.bold, "Header style should have bold font after round-trip")
    }

    func testCurrencyStyleSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(1234.56, to: "A1", style: .currency)
        }

        let cells = wb.sheets[0].cells
        guard let (value, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertEqual(value, .number(1234.56))
        XCTAssertEqual(style.numberFormat.formatString, "$#,##0.00")
    }

    func testPercentStyleSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(0.075, to: "A1", style: .percent)
        }

        let cells = wb.sheets[0].cells
        guard let (value, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertEqual(value, .number(0.075))
        XCTAssertEqual(style.numberFormat.formatString, "0.00%")
    }

    func testCustomFillColorSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            let fillStyle = CellStyle(fill: .solid("FF00FF00"))
            sheet.write("Green", to: "A1", style: fillStyle)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertEqual(style.fill?.patternType, .solid)
        XCTAssertEqual(style.fill?.foregroundColor, "FF00FF00")
    }

    func testCustomBorderSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            let borderStyle = CellStyle(border: .thin)
            sheet.write("Boxed", to: "A1", style: borderStyle)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            XCTFail("A1 should have a cell entry")
            return
        }
        XCTAssertNotNil(style.border, "Border should survive round-trip")
        XCTAssertNotNil(style.border?.top, "Top border edge should survive")
        XCTAssertNotNil(style.border?.bottom, "Bottom border edge should survive")
        XCTAssertNotNil(style.border?.left, "Left border edge should survive")
        XCTAssertNotNil(style.border?.right, "Right border edge should survive")
        XCTAssertEqual(style.border?.top?.style, .thin)
        XCTAssertEqual(style.border?.bottom?.style, .thin)
    }

    // MARK: - Layout Round-Trips

    func testFreezePanesSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Header", to: "A1")
            sheet.freezePanes(at: "A2")
        }

        XCTAssertEqual(wb.sheets[0].frozenPaneRef, "A2")
    }

    func testMergeCellsSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Wide Title", to: "A1")
            sheet.mergeCells(CellRange("A1:D1"))
        }

        let s = wb.sheets[0]
        XCTAssertEqual(s.mergedCells.count, 1)
        XCTAssertEqual(s.mergedCells[0].reference, "A1:D1")
    }

    func testAutoFilterSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Name", to: "A1")
            sheet.write("Score", to: "B1")
            sheet.setAutoFilter(CellRange("A1:B20"))
        }

        let s = wb.sheets[0]
        XCTAssertNotNil(s.autoFilterRange)
        XCTAssertEqual(s.autoFilterRange?.reference, "A1:B20")
    }

    func testRowHeightSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Tall", to: "A1")
            sheet.setRowHeight(row: 1, height: 45)
        }

        XCTAssertEqual(wb.sheets[0].rowHeights[1], 45)
    }

    func testColumnWidthSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Wide column", to: "A1")
            sheet.setColumnWidth(column: "A", width: 25.5)
        }

        // Column "A" is column index 1
        XCTAssertEqual(wb.sheets[0].columnWidths[1], 25.5)
    }

    func testDataValidationListSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.addValidation(CellRange("B1:B10"),
                                type: .list(["High", "Medium", "Low"]))
        }

        let s = wb.sheets[0]
        XCTAssertEqual(s.validations.count, 1)
        XCTAssertEqual(s.validations[0].range.reference, "B1:B10")
        if case .list(let items) = s.validations[0].type {
            XCTAssertEqual(items, ["High", "Medium", "Low"])
        } else {
            XCTFail("Expected list validation type")
        }
    }

    // MARK: - Multi-Sheet Round-Trips

    func testMultipleSheetsWithDifferentDataSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let inputs = wb.addSheet(name: "Inputs")
            inputs.write("Rate", to: "A1")
            inputs.write(0.05, to: "B1")

            let calculations = wb.addSheet(name: "Calculations")
            calculations.write(1000.0, to: "A1")
            calculations.writeFormula("A1*Inputs!B1", to: "B1")

            let results = wb.addSheet(name: "Results")
            results.write("Final", to: "A1")
            results.write(50.0, to: "B1")
        }

        XCTAssertEqual(wb.sheets.count, 3)
        XCTAssertEqual(wb.sheets[0].name, "Inputs")
        XCTAssertEqual(wb.sheets[1].name, "Calculations")
        XCTAssertEqual(wb.sheets[2].name, "Results")

        // Verify data on each sheet
        XCTAssertEqual(wb.sheets[0].cell(at: "A1"), .text("Rate"))
        XCTAssertEqual(wb.sheets[0].cell(at: "B1"), .number(0.05))
        XCTAssertEqual(wb.sheets[1].cell(at: "A1"), .number(1000))
        XCTAssertTrue(wb.sheets[1].cell(at: "B1")?.isFormula == true)
        XCTAssertEqual(wb.sheets[2].cell(at: "A1"), .text("Final"))
        XCTAssertEqual(wb.sheets[2].cell(at: "B1"), .number(50))
    }

    func testSheetNamesWithSpecialCharactersSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet1 = wb.addSheet(name: "Q1 2026")
            sheet1.write("Revenue", to: "A1")

            let sheet2 = wb.addSheet(name: "P&L Summary")
            sheet2.write("Total", to: "A1")
        }

        XCTAssertEqual(wb.sheets.count, 2)
        XCTAssertEqual(wb.sheets[0].name, "Q1 2026")
        XCTAssertEqual(wb.sheets[1].name, "P&L Summary")
        XCTAssertEqual(wb.sheets[0].cell(at: "A1"), .text("Revenue"))
        XCTAssertEqual(wb.sheets[1].cell(at: "A1"), .text("Total"))
    }

    // MARK: - Comprehensive Round-Trip

    func testAllFeaturesCombinedRoundTrip() throws {
        let wb = try roundTrip { wb in
            // Sheet 1: Data with various value types and styles
            let data = wb.addSheet(name: "Financial Data")

            // Headers with bold style
            data.write("Category", to: "A1", style: .header)
            data.write("Amount", to: "B1", style: .header)
            data.write("Rate", to: "C1", style: .header)

            // Data rows with different styles
            data.write("Revenue", to: "A2")
            data.write(500_000.0, to: "B2", style: .currency)
            data.write(0.12, to: "C2", style: .percent)

            data.write("Expenses", to: "A3")
            data.write(350_000.0, to: "B3", style: .currency)
            data.write(0.08, to: "C3", style: .percent)

            // Formula row
            data.write("Profit", to: "A4", style: .header)
            data.writeFormula("B2-B3", to: "B4")

            // Layout features
            data.freezePanes(at: "A2")
            data.mergeCells(CellRange("A1:A1"))  // Single cell "merge" just to test
            data.setAutoFilter(CellRange("A1:C4"))
            data.setRowHeight(row: 1, height: 30)
            data.setColumnWidth(column: "B", width: 18.5)

            // Data validation
            data.addValidation(CellRange("A5:A20"),
                               type: .list(["Revenue", "Expenses", "Tax", "Interest"]))

            // Sheet 2: Summary with custom styling
            let summary = wb.addSheet(name: "Summary")
            let highlight = CellStyle(
                font: Font(bold: true),
                border: .bottom,
                fill: .solid("FFFFFF00")
            )
            summary.write("Grand Total", to: "A1", style: highlight)
            summary.writeFormula("'Financial Data'!B4", to: "B1")
        }

        // Verify sheet count and names
        XCTAssertEqual(wb.sheets.count, 2)
        XCTAssertEqual(wb.sheets[0].name, "Financial Data")
        XCTAssertEqual(wb.sheets[1].name, "Summary")

        // Sheet 1 values
        let data = wb.sheets[0]
        XCTAssertEqual(data.cell(at: "A1"), .text("Category"))
        XCTAssertEqual(data.cell(at: "B1"), .text("Amount"))
        XCTAssertEqual(data.cell(at: "C1"), .text("Rate"))
        XCTAssertEqual(data.cell(at: "A2"), .text("Revenue"))
        XCTAssertEqual(data.cell(at: "B2"), .number(500_000))
        XCTAssertEqual(data.cell(at: "C2"), .number(0.12))
        XCTAssertEqual(data.cell(at: "A3"), .text("Expenses"))
        XCTAssertEqual(data.cell(at: "B3"), .number(350_000))
        XCTAssertEqual(data.cell(at: "C3"), .number(0.08))

        // Sheet 1 styles
        let headerCells = data.cells
        if let (_, headerStyle) = headerCells["A1"] {
            XCTAssertTrue(headerStyle.font.bold, "Header should be bold")
        }
        if let (_, currencyStyle) = headerCells["B2"] {
            XCTAssertEqual(currencyStyle.numberFormat.formatString, "$#,##0.00")
        }
        if let (_, percentStyle) = headerCells["C2"] {
            XCTAssertEqual(percentStyle.numberFormat.formatString, "0.00%")
        }

        // Sheet 1 formula
        XCTAssertTrue(data.cell(at: "B4")?.isFormula == true)

        // Sheet 1 layout
        XCTAssertEqual(data.frozenPaneRef, "A2")
        XCTAssertNotNil(data.autoFilterRange)
        XCTAssertEqual(data.autoFilterRange?.reference, "A1:C4")
        XCTAssertEqual(data.rowHeights[1], 30)
        XCTAssertEqual(data.columnWidths[2], 18.5) // Column B = index 2
        XCTAssertEqual(data.validations.count, 1)

        // Sheet 2 values and styles
        let summary = wb.sheets[1]
        XCTAssertEqual(summary.cell(at: "A1"), .text("Grand Total"))
        XCTAssertTrue(summary.cell(at: "B1")?.isFormula == true)

        let summaryCells = summary.cells
        if let (_, highlightStyle) = summaryCells["A1"] {
            XCTAssertTrue(highlightStyle.font.bold, "Highlight font should be bold")
            XCTAssertNotNil(highlightStyle.border?.bottom, "Highlight should have bottom border")
            XCTAssertEqual(highlightStyle.fill?.patternType, .solid)
            XCTAssertEqual(highlightStyle.fill?.foregroundColor, "FFFFFF00")
        }
    }
}
