import Testing
import Foundation
import SwiftZIP
@testable import SwiftXLSX

@Suite
struct RoundTripReadWriteTests {

    // MARK: - Helpers

    /// Saves a workbook to in-memory data, then reads it back.
    private func roundTrip(_ configure: (Workbook) -> Void) throws -> Workbook {
        let original = Workbook()
        configure(original)
        let data = try original.save()
        return try Workbook(xlsxData: data)
    }

    // MARK: - Value Round-Trips

    @Test("String value survives round trip")
    func testStringValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Hello, World!", to: "A1")
        }

        #expect(wb.sheets.count == 1)
        #expect(wb.sheets[0].cell(at: "A1") == .text("Hello, World!"))
    }

    @Test("Integer number value survives round trip")
    func testIntegerNumberValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(42.0, to: "A1")
        }

        #expect(wb.sheets[0].cell(at: "A1") == .number(42))
    }

    @Test("Decimal number value survives round trip")
    func testDecimalNumberValueSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(3.14159, to: "B2")
        }

        #expect(wb.sheets[0].cell(at: "B2") == .number(3.14159))
    }

    @Test("Multiple cells on same row survive round trip")
    func testMultipleCellsOnSameRowSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Name", to: "A1")
            sheet.write("Age", to: "B1")
            sheet.write("City", to: "C1")
        }

        let s = wb.sheets[0]
        #expect(s.cell(at: "A1") == .text("Name"))
        #expect(s.cell(at: "B1") == .text("Age"))
        #expect(s.cell(at: "C1") == .text("City"))
    }

    @Test("Multiple rows survive round trip")
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
        #expect(s.cell(at: "A1") == .text("Revenue"))
        #expect(s.cell(at: "B1") == .number(100_000))
        #expect(s.cell(at: "A2") == .text("Expenses"))
        #expect(s.cell(at: "B2") == .number(75_000))
        #expect(s.cell(at: "A3") == .text("Profit"))
        #expect(s.cell(at: "B3") == .number(25_000))
    }

    @Test("Empty workbook round trips")
    func testEmptyWorkbookRoundTrips() throws {
        let wb = try roundTrip { wb in
            _ = wb.addSheet(name: "Empty")
        }

        #expect(wb.sheets.count == 1)
        #expect(wb.sheets[0].name == "Empty")
        #expect(wb.sheets[0].cell(at: "A1") == nil)
    }

    // MARK: - Formula Round-Trips

    @Test("Simple formula round trip")
    func testSimpleFormulaRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(10.0, to: "A1")
            sheet.write(20.0, to: "B1")
            sheet.writeFormula("A1+B1", to: "C1")
        }

        let s = wb.sheets[0]
        guard let c1 = s.cell(at: "C1") else {
            Issue.record("C1 should have a value")
            return
        }
        #expect(c1.isFormula, "C1 should be a formula")

        // Verify the formula AST was parsed back
        guard let ast = s.formulaAST(at: "C1") else {
            Issue.record("C1 should have a formula AST")
            return
        }
        // The formula should be A1+B1, which is .add(.cellRef, .cellRef)
        if case .add(let lhs, let rhs) = ast {
            if case .cellRef(let lRef) = lhs {
                #expect(lRef.reference == "A1")
            } else {
                Issue.record("Left operand should be a cell ref")
            }
            if case .cellRef(let rRef) = rhs {
                #expect(rRef.reference == "B1")
            } else {
                Issue.record("Right operand should be a cell ref")
            }
        } else {
            Issue.record("Expected add AST node, got \(ast)")
        }
    }

    @Test("Function formula survives round trip")
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
            Issue.record("A11 should have a formula AST")
            return
        }
        // Verify it's a SUM function
        if case .function(let name, let args) = ast {
            #expect(name == "SUM")
            #expect(args.count == 1)
            if case .cellRange(let range) = args[0] {
                #expect(range.reference == "A1:A10")
            } else {
                Issue.record("SUM argument should be a cell range")
            }
        } else {
            Issue.record("Expected function AST node, got \(ast)")
        }
    }

    @Test("Formula with cached value round trip")
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
            Issue.record("B1 should have a value")
            return
        }
        #expect(b1.isFormula, "B1 should be a formula")
        // Verify the cached value was preserved
        if case .formula(_, let cached) = b1 {
            #expect(cached == .number(100))
        } else {
            Issue.record("Expected formula with cached value")
        }
    }

    // MARK: - Style Round-Trips

    @Test("Header style bold font survives round trip")
    func testHeaderStyleBoldFontSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Title", to: "A1", style: .header)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(style.font.bold, "Header style should have bold font after round-trip")
    }

    @Test("Currency style survives round trip")
    func testCurrencyStyleSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(1234.56, to: "A1", style: .currency)
        }

        let cells = wb.sheets[0].cells
        guard let (value, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(value == .number(1234.56))
        #expect(style.numberFormat.formatString == "$#,##0.00")
    }

    @Test("Percent style survives round trip")
    func testPercentStyleSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write(0.075, to: "A1", style: .percent)
        }

        let cells = wb.sheets[0].cells
        guard let (value, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(value == .number(0.075))
        #expect(style.numberFormat.formatString == "0.00%")
    }

    @Test("Custom fill color survives round trip")
    func testCustomFillColorSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            let fillStyle = CellStyle(fill: .solid("FF00FF00"))
            sheet.write("Green", to: "A1", style: fillStyle)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        #expect(style.fill?.patternType == .solid)
        #expect(style.fill?.foregroundColor == "FF00FF00")
    }

    @Test("Custom border survives round trip")
    func testCustomBorderSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            let borderStyle = CellStyle(border: .thin)
            sheet.write("Boxed", to: "A1", style: borderStyle)
        }

        let cells = wb.sheets[0].cells
        guard let (_, style) = cells["A1"] else {
            Issue.record("A1 should have a cell entry")
            return
        }
        let border = try #require(style.border, "Border should survive round-trip")
        // `.thin` is a thin black line on all four edges, and all four must come back
        // with both the style and the colour they were written with.
        let thinEdge = Border.BorderEdge(style: .thin, color: "FF000000")
        #expect(border == Border.thin, "The whole `.thin` border should survive round-trip")
        #expect(border.top == thinEdge, "Top border edge should survive")
        #expect(border.bottom == thinEdge, "Bottom border edge should survive")
        #expect(border.left == thinEdge, "Left border edge should survive")
        #expect(border.right == thinEdge, "Right border edge should survive")
    }

    // MARK: - Layout Round-Trips

    @Test("Freeze panes survives round trip")
    func testFreezePanesSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Header", to: "A1")
            sheet.freezePanes(at: "A2")
        }

        #expect(wb.sheets[0].frozenPaneRef == "A2")
    }

    @Test("Merge cells survives round trip")
    func testMergeCellsSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Wide Title", to: "A1")
            sheet.mergeCells(CellRange("A1:D1"))
        }

        let s = wb.sheets[0]
        #expect(s.mergedCells.count == 1)
        #expect(s.mergedCells[0].reference == "A1:D1")
    }

    @Test("Auto filter survives round trip")
    func testAutoFilterSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Name", to: "A1")
            sheet.write("Score", to: "B1")
            sheet.setAutoFilter(CellRange("A1:B20"))
        }

        let s = wb.sheets[0]
        #expect(s.autoFilterRange == CellRange("A1:B20"))
        #expect(s.autoFilterRange?.reference == "A1:B20")
    }

    @Test("Row height survives round trip")
    func testRowHeightSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Tall", to: "A1")
            sheet.setRowHeight(row: 1, height: 45)
        }

        #expect(wb.sheets[0].rowHeights[1] == 45)
    }

    @Test("Column width survives round trip")
    func testColumnWidthSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.write("Wide column", to: "A1")
            sheet.setColumnWidth(column: "A", width: 25.5)
        }

        // Column "A" is column index 1
        #expect(try #require(wb.sheets[0].columnWidths[1]).isEqual(to: 25.5))
    }

    @Test("Data validation list survives round trip")
    func testDataValidationListSurvivesRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet = wb.addSheet(name: "Sheet1")
            sheet.addValidation(CellRange("B1:B10"),
                                type: .list(["High", "Medium", "Low"]))
        }

        let s = wb.sheets[0]
        #expect(s.validations.count == 1)
        #expect(s.validations[0].range.reference == "B1:B10")
        if case .list(let items) = s.validations[0].type {
            #expect(items == ["High", "Medium", "Low"])
        } else {
            Issue.record("Expected list validation type")
        }
    }

    // MARK: - Multi-Sheet Round-Trips

    @Test("Multiple sheets with different data survive round trip")
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

        #expect(wb.sheets.count == 3)
        #expect(wb.sheets[0].name == "Inputs")
        #expect(wb.sheets[1].name == "Calculations")
        #expect(wb.sheets[2].name == "Results")

        // Verify data on each sheet
        #expect(wb.sheets[0].cell(at: "A1") == .text("Rate"))
        #expect(wb.sheets[0].cell(at: "B1") == .number(0.05))
        #expect(wb.sheets[1].cell(at: "A1") == .number(1000))
        #expect(wb.sheets[1].cell(at: "B1")?.isFormula == true)
        #expect(wb.sheets[2].cell(at: "A1") == .text("Final"))
        #expect(wb.sheets[2].cell(at: "B1") == .number(50))
    }

    @Test("Sheet names with special characters survive round trip")
    func testSheetNamesWithSpecialCharactersSurviveRoundTrip() throws {
        let wb = try roundTrip { wb in
            let sheet1 = wb.addSheet(name: "Q1 2026")
            sheet1.write("Revenue", to: "A1")

            let sheet2 = wb.addSheet(name: "P&L Summary")
            sheet2.write("Total", to: "A1")
        }

        #expect(wb.sheets.count == 2)
        #expect(wb.sheets[0].name == "Q1 2026")
        #expect(wb.sheets[1].name == "P&L Summary")
        #expect(wb.sheets[0].cell(at: "A1") == .text("Revenue"))
        #expect(wb.sheets[1].cell(at: "A1") == .text("Total"))
    }

    // MARK: - Comprehensive Round-Trip

    @Test("All features combined round trip")
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
        #expect(wb.sheets.count == 2)
        #expect(wb.sheets[0].name == "Financial Data")
        #expect(wb.sheets[1].name == "Summary")

        // Sheet 1 values
        let data = wb.sheets[0]
        #expect(data.cell(at: "A1") == .text("Category"))
        #expect(data.cell(at: "B1") == .text("Amount"))
        #expect(data.cell(at: "C1") == .text("Rate"))
        #expect(data.cell(at: "A2") == .text("Revenue"))
        #expect(data.cell(at: "B2") == .number(500_000))
        #expect(data.cell(at: "C2") == .number(0.12))
        #expect(data.cell(at: "A3") == .text("Expenses"))
        #expect(data.cell(at: "B3") == .number(350_000))
        #expect(data.cell(at: "C3") == .number(0.08))

        // Sheet 1 styles
        let headerCells = data.cells
        if let (_, headerStyle) = headerCells["A1"] {
            #expect(headerStyle.font.bold, "Header should be bold")
        }
        if let (_, currencyStyle) = headerCells["B2"] {
            #expect(currencyStyle.numberFormat.formatString == "$#,##0.00")
        }
        if let (_, percentStyle) = headerCells["C2"] {
            #expect(percentStyle.numberFormat.formatString == "0.00%")
        }

        // Sheet 1 formula
        #expect(data.cell(at: "B4")?.isFormula == true)

        // Sheet 1 layout
        #expect(data.frozenPaneRef == "A2")
        #expect(data.autoFilterRange == CellRange("A1:C4"))
        #expect(data.autoFilterRange?.reference == "A1:C4")
        #expect(data.rowHeights[1] == 30)
        #expect(try #require(data.columnWidths[2]).isEqual(to: 18.5)) // Column B = index 2
        #expect(data.validations.count == 1)

        // Sheet 2 values and styles
        let summary = wb.sheets[1]
        #expect(summary.cell(at: "A1") == .text("Grand Total"))
        #expect(summary.cell(at: "B1")?.isFormula == true)

        let summaryCells = summary.cells
        if let (_, highlightStyle) = summaryCells["A1"] {
            #expect(highlightStyle.font.bold, "Highlight font should be bold")
            #expect(highlightStyle.border?.bottom == Border.BorderEdge(style: .thin, color: "FF000000"),
                    "Highlight should have bottom border")
            #expect(highlightStyle.border == Border.bottom,
                    "`.bottom` carries only a bottom edge, and only that edge should come back")
            #expect(highlightStyle.fill?.patternType == .solid)
            #expect(highlightStyle.fill?.foregroundColor == "FFFFFF00")
        }
    }
}
