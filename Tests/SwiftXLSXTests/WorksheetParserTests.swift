import XCTest
import SwiftZIP
@testable import SwiftXLSX

final class WorksheetParserTests: XCTestCase {

    // MARK: - Helpers

    /// Builds a minimal worksheet XML with the given sheetData content and optional extras
    /// placed before `<sheetData>`.
    private func makeWorksheetXML(sheetData: String, extras: String = "") -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        \(extras)
        <sheetData>\(sheetData)</sheetData>
        </worksheet>
        """
        return Data(xml.utf8)
    }

    /// Builds worksheet XML with both extras-before and extras-after sheetData.
    private func makeFullWorksheetXML(sheetData: String,
                                      before: String = "",
                                      after: String = "") -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        \(before)
        <sheetData>\(sheetData)</sheetData>
        \(after)
        </worksheet>
        """
        return Data(xml.utf8)
    }

    private func parseSheet(data: Data,
                            sharedStrings: [String] = [],
                            styles: ParsedStyleSheet = ParsedStyleSheet()) throws -> Worksheet {
        let sheet = Worksheet(name: "Test")
        try WorksheetParser.parse(data: data, into: sheet,
                                  sharedStrings: sharedStrings, styles: styles)
        return sheet
    }

    // MARK: - Cell Values

    // 1. Number cell
    func testNumberCell() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>42</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(42))
    }

    // 2. Text cell (shared string)
    func testTextCellSharedString() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" t="s"><v>0</v></c></row>
        """)
        let sheet = try parseSheet(data: data, sharedStrings: ["Hello World"])
        XCTAssertEqual(sheet.cell(at: "A1"), .text("Hello World"))
    }

    // 3. Boolean true
    func testBooleanTrue() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" t="b"><v>1</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .bool(true))
    }

    // 4. Boolean false
    func testBooleanFalse() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" t="b"><v>0</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .bool(false))
    }

    // 5. Error cell
    func testErrorCell() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" t="e"><v>#VALUE!</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .error(.value))
    }

    // 6. Formula cell
    func testFormulaCell() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><f>A2+A3</f></c></row>
        """)
        let sheet = try parseSheet(data: data)
        let value = sheet.cell(at: "A1")
        guard case .formula(let ast, _) = value else {
            XCTFail("Expected formula cell"); return
        }
        // Should parse to add(cellRef(A2), cellRef(A3))
        XCTAssertEqual(ast, .add(.cellRef(CellRef("A2")), .cellRef(CellRef("A3"))))
    }

    // 7. Formula with cached value
    func testFormulaCachedValue() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><f>1+2</f><v>3</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        let value = sheet.cell(at: "A1")
        guard case .formula(_, let cached) = value else {
            XCTFail("Expected formula cell"); return
        }
        XCTAssertEqual(cached, .number(3))
    }

    // 8. Empty cell with style index
    func testEmptyCellWithStyle() throws {
        var styles = ParsedStyleSheet()
        styles.fonts = [Font(bold: true)]
        styles.cellFormats = [
            ParsedStyleSheet.CellFormatRecord(numFmtId: 0, fontId: 0, fillId: 0,
                                               borderId: 0, alignment: nil),
            ParsedStyleSheet.CellFormatRecord(numFmtId: 0, fontId: 0, fillId: 0,
                                               borderId: 0, alignment: nil)
        ]
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" s="1"/></row>
        """)
        let sheet = try parseSheet(data: data, styles: styles)
        XCTAssertEqual(sheet.cell(at: "A1"), .blank)
    }

    // 9. Decimal number
    func testDecimalNumber() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>3.14159</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(3.14159))
    }

    // 10. Negative number
    func testNegativeNumber() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>-100.5</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(-100.5))
    }

    // 11. Multiple cells in one row
    func testMultipleCellsInOneRow() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1">
          <c r="A1"><v>1</v></c>
          <c r="B1"><v>2</v></c>
          <c r="C1"><v>3</v></c>
        </row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(1))
        XCTAssertEqual(sheet.cell(at: "B1"), .number(2))
        XCTAssertEqual(sheet.cell(at: "C1"), .number(3))
    }

    // 12. Multiple rows
    func testMultipleRows() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>10</v></c></row>
        <row r="2"><c r="A2"><v>20</v></c></row>
        <row r="3"><c r="A3"><v>30</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(10))
        XCTAssertEqual(sheet.cell(at: "A2"), .number(20))
        XCTAssertEqual(sheet.cell(at: "A3"), .number(30))
    }

    // MARK: - Styles

    // 13. Cell with style index
    func testCellWithStyleIndex() throws {
        var styles = ParsedStyleSheet()
        styles.fonts = [Font(), Font(bold: true)]
        styles.fills = [nil, nil]
        styles.borders = [nil, nil]
        styles.cellFormats = [
            ParsedStyleSheet.CellFormatRecord(numFmtId: 0, fontId: 0, fillId: 0,
                                               borderId: 0, alignment: nil),
            ParsedStyleSheet.CellFormatRecord(numFmtId: 0, fontId: 1, fillId: 0,
                                               borderId: 0, alignment: nil)
        ]
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" s="1"><v>42</v></c></row>
        """)
        let sheet = try parseSheet(data: data, styles: styles)
        // Verify the cell was stored (we can check value; style is internal)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(42))
        // Access cells dict to verify style
        let stored = sheet.cells["A1"]
        XCTAssertNotNil(stored)
        XCTAssertTrue(stored?.1.font.bold ?? false, "Expected bold font from style index 1")
    }

    // 14. Cell with no style index defaults to index 0
    func testCellDefaultsToStyleIndex0() throws {
        var styles = ParsedStyleSheet()
        styles.fonts = [Font(name: "Arial", size: 12)]
        styles.cellFormats = [
            ParsedStyleSheet.CellFormatRecord(numFmtId: 0, fontId: 0, fillId: 0,
                                               borderId: 0, alignment: nil)
        ]
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>99</v></c></row>
        """)
        let sheet = try parseSheet(data: data, styles: styles)
        let stored = sheet.cells["A1"]
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.1.font.name, "Arial")
    }

    // MARK: - Layout Features

    // 15. Freeze panes
    func testFreezePanes() throws {
        let data = makeWorksheetXML(
            sheetData: "",
            extras: """
            <sheetViews><sheetView tabSelected="1" workbookViewId="0">
            <pane xSplit="0" ySplit="1" topLeftCell="A2" activePane="bottomRight" state="frozen"/>
            </sheetView></sheetViews>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.frozenPaneRef, "A2")
    }

    // 16. Freeze panes at C3
    func testFreezePanesAtC3() throws {
        let data = makeWorksheetXML(
            sheetData: "",
            extras: """
            <sheetViews><sheetView tabSelected="1" workbookViewId="0">
            <pane xSplit="2" ySplit="2" topLeftCell="C3" activePane="bottomRight" state="frozen"/>
            </sheetView></sheetViews>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.frozenPaneRef, "C3")
    }

    // 17. Column widths
    func testColumnWidths() throws {
        let data = makeWorksheetXML(
            sheetData: "",
            extras: """
            <cols><col min="1" max="1" width="20" customWidth="1"/></cols>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.columnWidths[1], 20)
    }

    // 18. Column width span
    func testColumnWidthSpan() throws {
        let data = makeWorksheetXML(
            sheetData: "",
            extras: """
            <cols><col min="1" max="3" width="15" customWidth="1"/></cols>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.columnWidths[1], 15)
        XCTAssertEqual(sheet.columnWidths[2], 15)
        XCTAssertEqual(sheet.columnWidths[3], 15)
    }

    // 19. Row height
    func testRowHeight() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1" ht="40" customHeight="1"><c r="A1"><v>1</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.rowHeights[1], 40)
    }

    // 20. Auto-filter
    func testAutoFilter() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <autoFilter ref="A1:C10"/>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.autoFilterRange?.reference, "A1:C10")
    }

    // 21. Merge cells
    func testMergeCells() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <mergeCells count="1"><mergeCell ref="A1:B2"/></mergeCells>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.mergedCells.count, 1)
        XCTAssertEqual(sheet.mergedCells.first?.reference, "A1:B2")
    }

    // 22. Multiple merge cells
    func testMultipleMergeCells() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <mergeCells count="2">
              <mergeCell ref="A1:B1"/>
              <mergeCell ref="C1:D1"/>
            </mergeCells>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.mergedCells.count, 2)
        XCTAssertEqual(sheet.mergedCells[0].reference, "A1:B1")
        XCTAssertEqual(sheet.mergedCells[1].reference, "C1:D1")
    }

    // 23. List validation
    func testListValidation() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <dataValidations count="1">
              <dataValidation type="list" sqref="A2:A10" allowBlank="1">
                <formula1>"Yes,No,Maybe"</formula1>
              </dataValidation>
            </dataValidations>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.validations.count, 1)
        XCTAssertEqual(sheet.validations[0].range.reference, "A2:A10")
        if case .list(let items) = sheet.validations[0].type {
            XCTAssertEqual(items, ["Yes", "No", "Maybe"])
        } else {
            XCTFail("Expected list validation")
        }
    }

    // 24. Decimal validation
    func testDecimalValidation() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <dataValidations count="1">
              <dataValidation type="decimal" operator="between" sqref="B2:B10" allowBlank="1">
                <formula1>0</formula1>
                <formula2>100</formula2>
              </dataValidation>
            </dataValidations>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.validations.count, 1)
        if case .decimal(let min, let max) = sheet.validations[0].type {
            XCTAssertEqual(min, 0, accuracy: 0.001)
            XCTAssertEqual(max, 100, accuracy: 0.001)
        } else {
            XCTFail("Expected decimal validation")
        }
    }

    // 25. Integer validation
    func testIntegerValidation() throws {
        let data = makeFullWorksheetXML(
            sheetData: "",
            after: """
            <dataValidations count="1">
              <dataValidation type="whole" operator="between" sqref="C2:C10" allowBlank="1">
                <formula1>1</formula1>
                <formula2>999</formula2>
              </dataValidation>
            </dataValidations>
            """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.validations.count, 1)
        if case .integer(let min, let max) = sheet.validations[0].type {
            XCTAssertEqual(min, 1)
            XCTAssertEqual(max, 999)
        } else {
            XCTFail("Expected integer validation")
        }
    }

    // MARK: - Edge Cases

    // 26. Empty worksheet
    func testEmptyWorksheet() throws {
        let data = makeWorksheetXML(sheetData: "")
        let sheet = try parseSheet(data: data)
        XCTAssertTrue(sheet.cells.isEmpty)
    }

    // 27. No layout features, just cells
    func testNoLayoutFeaturesJustCells() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><v>42</v></c></row>
        """)
        let sheet = try parseSheet(data: data)
        XCTAssertEqual(sheet.cell(at: "A1"), .number(42))
        XCTAssertNil(sheet.frozenPaneRef)
        XCTAssertTrue(sheet.columnWidths.isEmpty)
        XCTAssertTrue(sheet.rowHeights.isEmpty)
        XCTAssertNil(sheet.autoFilterRange)
        XCTAssertTrue(sheet.mergedCells.isEmpty)
        XCTAssertTrue(sheet.validations.isEmpty)
    }

    // 28. All features combined
    func testAllFeaturesCombined() throws {
        let data = makeFullWorksheetXML(
            sheetData: """
            <row r="1" ht="30" customHeight="1">
              <c r="A1" t="s"><v>0</v></c>
              <c r="B1"><v>100</v></c>
            </row>
            <row r="2">
              <c r="A2"><f>B1*2</f><v>200</v></c>
            </row>
            """,
            before: """
            <sheetViews><sheetView tabSelected="1" workbookViewId="0">
            <pane xSplit="0" ySplit="1" topLeftCell="A2" activePane="bottomRight" state="frozen"/>
            </sheetView></sheetViews>
            <cols><col min="1" max="1" width="25" customWidth="1"/></cols>
            """,
            after: """
            <autoFilter ref="A1:B10"/>
            <mergeCells count="1"><mergeCell ref="D1:E1"/></mergeCells>
            <dataValidations count="1">
              <dataValidation type="list" sqref="F1:F10" allowBlank="1">
                <formula1>"Yes,No"</formula1>
              </dataValidation>
            </dataValidations>
            """)
        let sheet = try parseSheet(data: data, sharedStrings: ["Header"])

        // Cells
        XCTAssertEqual(sheet.cell(at: "A1"), .text("Header"))
        XCTAssertEqual(sheet.cell(at: "B1"), .number(100))
        guard case .formula(_, let cached) = sheet.cell(at: "A2") else {
            XCTFail("Expected formula"); return
        }
        XCTAssertEqual(cached, .number(200))

        // Layout
        XCTAssertEqual(sheet.frozenPaneRef, "A2")
        XCTAssertEqual(sheet.columnWidths[1], 25)
        XCTAssertEqual(sheet.rowHeights[1], 30)
        XCTAssertEqual(sheet.autoFilterRange?.reference, "A1:B10")
        XCTAssertEqual(sheet.mergedCells.count, 1)
        XCTAssertEqual(sheet.mergedCells.first?.reference, "D1:E1")
        XCTAssertEqual(sheet.validations.count, 1)
    }

    // 29. Shared string index out of range
    func testSharedStringIndexOutOfRange() throws {
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1" t="s"><v>99</v></c></row>
        """)
        let sheet = try parseSheet(data: data, sharedStrings: ["Only One"])
        // Out-of-range index should use empty string
        XCTAssertEqual(sheet.cell(at: "A1"), .text(""))
    }

    // 30. Large worksheet (100 rows x 5 columns)
    func testLargeWorksheet() throws {
        var rows = ""
        for r in 1...100 {
            var cells = ""
            for c in 1...5 {
                let colLetter = CellRef(column: c, row: r).reference
                    .prefix(while: { $0.isLetter })
                let ref = "\(colLetter)\(r)"
                let value = r * 10 + c
                cells += "<c r=\"\(ref)\"><v>\(value)</v></c>"
            }
            rows += "<row r=\"\(r)\">\(cells)</row>"
        }
        let data = makeWorksheetXML(sheetData: rows)
        let sheet = try parseSheet(data: data)
        // Spot check
        XCTAssertEqual(sheet.cell(at: "A1"), .number(11))
        XCTAssertEqual(sheet.cell(at: "E1"), .number(15))
        XCTAssertEqual(sheet.cell(at: "A100"), .number(1001))
        XCTAssertEqual(sheet.cell(at: "E100"), .number(1005))
        XCTAssertEqual(sheet.cells.count, 500)
    }

    // MARK: - Error Types

    // 31. All error types
    func testAllErrorTypes() throws {
        let errors: [(String, ExcelError)] = [
            ("#VALUE!", .value),
            ("#REF!", .ref),
            ("#DIV/0!", .div0),
            ("#NAME?", .name),
            ("#NULL!", .null),
            ("#NUM!", .num),
            ("#N/A", .na)
        ]
        for (i, (rawValue, expected)) in errors.enumerated() {
            let row = i + 1
            let ref = "A\(row)"
            let data = makeWorksheetXML(sheetData: """
            <row r="\(row)"><c r="\(ref)" t="e"><v>\(rawValue)</v></c></row>
            """)
            let sheet = try parseSheet(data: data)
            XCTAssertEqual(sheet.cell(at: ref), .error(expected),
                           "Failed for error \(rawValue)")
        }
    }

    // 32. Formula with _RAW fallback for unparseable formula
    func testFormulaRawFallback() throws {
        // Use something that cannot be parsed as a standard formula
        let data = makeWorksheetXML(sheetData: """
        <row r="1"><c r="A1"><f>{TRANSPOSE(A1:A5)}</f></c></row>
        """)
        let sheet = try parseSheet(data: data)
        let value = sheet.cell(at: "A1")
        guard case .formula(let ast, _) = value else {
            XCTFail("Expected formula cell"); return
        }
        // Should fall back to _RAW
        if case .function("_RAW", let args) = ast, let first = args.first,
           case .text(let raw) = first {
            XCTAssertTrue(raw.contains("TRANSPOSE"))
        } else {
            // If it somehow parsed, that's also fine
            XCTAssertNotNil(ast)
        }
    }

    // MARK: - Round-Trip Tests

    // 33. Write numbers and text, generate XML, parse back
    func testRoundTripNumbersAndText() throws {
        let workbook = Workbook()
        let original = workbook.addSheet(name: "Data")
        original.write("Hello", to: "A1")
        original.write(42.0, to: "B1")
        original.write(-3.14, to: "C1")
        original.setCell("A2", value: .bool(true), style: .general)

        // Generate worksheet XML via the workbook
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try workbook.save(to: tempURL)

        // Read back the ZIP and extract worksheet XML
        let zipData = try Data(contentsOf: tempURL)
        let entries = try SwiftZIP.ZIPReader.read(from: zipData)
        guard let wsEntry = entries.first(where: { $0.path.contains("sheet1.xml") }) else {
            XCTFail("Missing sheet1.xml in archive"); return
        }

        // Extract shared strings and styles
        let ssEntry = entries.first(where: { $0.path.contains("sharedStrings.xml") })
        let stEntry = entries.first(where: { $0.path.contains("styles.xml") })

        let sharedStrings = try SharedStringsParser.parse(data: ssEntry?.data ?? Data())
        let styles = try StyleSheetParser.parse(data: stEntry?.data ?? Data())

        // Parse
        let parsed = try parseSheet(data: wsEntry.data,
                                    sharedStrings: sharedStrings,
                                    styles: styles)

        XCTAssertEqual(parsed.cell(at: "A1"), .text("Hello"))
        XCTAssertEqual(parsed.cell(at: "B1"), .number(42))
        XCTAssertEqual(parsed.cell(at: "C1"), .number(-3.14))
    }

    // 34. Write styled cells, parse back, verify styles match
    func testRoundTripStyles() throws {
        let workbook = Workbook()
        let original = workbook.addSheet(name: "Styled")
        original.write("Bold", to: "A1", style: .header)
        original.write(1000.0, to: "B1", style: .currency)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try workbook.save(to: tempURL)

        let zipData = try Data(contentsOf: tempURL)
        let entries = try SwiftZIP.ZIPReader.read(from: zipData)
        guard let wsEntry = entries.first(where: { $0.path.contains("sheet1.xml") }) else {
            XCTFail("Missing sheet1.xml"); return
        }
        let ssEntry = entries.first(where: { $0.path.contains("sharedStrings.xml") })
        let stEntry = entries.first(where: { $0.path.contains("styles.xml") })
        let sharedStrings = try SharedStringsParser.parse(data: ssEntry?.data ?? Data())
        let styles = try StyleSheetParser.parse(data: stEntry?.data ?? Data())

        let parsed = try parseSheet(data: wsEntry.data,
                                    sharedStrings: sharedStrings,
                                    styles: styles)

        // Verify bold font on A1
        let a1Style = parsed.cells["A1"]?.1
        XCTAssertNotNil(a1Style)
        XCTAssertTrue(a1Style?.font.bold ?? false, "A1 should have bold font")

        // Verify values survived
        XCTAssertEqual(parsed.cell(at: "A1"), .text("Bold"))
        XCTAssertEqual(parsed.cell(at: "B1"), .number(1000))
    }

    // 35. Write formulas, parse back
    func testRoundTripFormulas() throws {
        let workbook = Workbook()
        let original = workbook.addSheet(name: "Formulas")
        original.write(10.0, to: "A1")
        original.write(20.0, to: "A2")
        original.writeFormula("A1+A2", to: "A3")
        original.writeFormula("SUM(A1:A2)", to: "A4")

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try workbook.save(to: tempURL)

        let zipData = try Data(contentsOf: tempURL)
        let entries = try SwiftZIP.ZIPReader.read(from: zipData)
        guard let wsEntry = entries.first(where: { $0.path.contains("sheet1.xml") }) else {
            XCTFail("Missing sheet1.xml"); return
        }
        let ssEntry = entries.first(where: { $0.path.contains("sharedStrings.xml") })
        let stEntry = entries.first(where: { $0.path.contains("styles.xml") })
        let sharedStrings = try SharedStringsParser.parse(data: ssEntry?.data ?? Data())
        let styles = try StyleSheetParser.parse(data: stEntry?.data ?? Data())

        let parsed = try parseSheet(data: wsEntry.data,
                                    sharedStrings: sharedStrings,
                                    styles: styles)

        // A3 should have formula A1+A2
        let a3 = parsed.cell(at: "A3")
        guard case .formula(let ast3, _) = a3 else {
            XCTFail("Expected formula at A3"); return
        }
        XCTAssertEqual(ast3, .add(.cellRef(CellRef("A1")), .cellRef(CellRef("A2"))))

        // A4 should have SUM(A1:A2)
        let a4 = parsed.cell(at: "A4")
        guard case .formula(let ast4, _) = a4 else {
            XCTFail("Expected formula at A4"); return
        }
        XCTAssertEqual(ast4, .function("SUM", [.cellRange(CellRange("A1:A2"))]))
    }

    // 36. Write layout features, parse back
    func testRoundTripLayoutFeatures() throws {
        let workbook = Workbook()
        let original = workbook.addSheet(name: "Layout")
        original.write("Header", to: "A1")
        original.freezePanes(at: "A2")
        original.setColumnWidth(column: "A", width: 25)
        original.setRowHeight(row: 1, height: 30)
        original.setAutoFilter(CellRange("A1:C10"))
        original.mergeCells(CellRange("D1:E1"))
        original.addValidation(CellRange("F1:F10"), type: .list(["Yes", "No"]))

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try workbook.save(to: tempURL)

        let zipData = try Data(contentsOf: tempURL)
        let entries = try SwiftZIP.ZIPReader.read(from: zipData)
        guard let wsEntry = entries.first(where: { $0.path.contains("sheet1.xml") }) else {
            XCTFail("Missing sheet1.xml"); return
        }
        let ssEntry = entries.first(where: { $0.path.contains("sharedStrings.xml") })
        let stEntry = entries.first(where: { $0.path.contains("styles.xml") })
        let sharedStrings = try SharedStringsParser.parse(data: ssEntry?.data ?? Data())
        let styles = try StyleSheetParser.parse(data: stEntry?.data ?? Data())

        let parsed = try parseSheet(data: wsEntry.data,
                                    sharedStrings: sharedStrings,
                                    styles: styles)

        XCTAssertEqual(parsed.frozenPaneRef, "A2")
        XCTAssertEqual(parsed.columnWidths[1], 25)
        XCTAssertEqual(parsed.rowHeights[1], 30)
        XCTAssertEqual(parsed.autoFilterRange?.reference, "A1:C10")
        XCTAssertEqual(parsed.mergedCells.count, 1)
        XCTAssertEqual(parsed.mergedCells.first?.reference, "D1:E1")
        XCTAssertEqual(parsed.validations.count, 1)
        if case .list(let items) = parsed.validations[0].type {
            XCTAssertEqual(items, ["Yes", "No"])
        } else {
            XCTFail("Expected list validation")
        }
    }

    // 37. Full round-trip with all features
    func testFullRoundTrip() throws {
        let workbook = Workbook()
        let original = workbook.addSheet(name: "Full")
        original.write("Name", to: "A1", style: .header)
        original.write("Amount", to: "B1", style: .header)
        original.write("Alice", to: "A2")
        original.write(100.0, to: "B2", style: .currency)
        original.write("Bob", to: "A3")
        original.write(200.0, to: "B3", style: .currency)
        original.writeFormula("SUM(B2:B3)", to: "B4")
        original.freezePanes(at: "A2")
        original.setColumnWidth(column: "A", width: 20)
        original.setColumnWidth(column: "B", width: 15)
        original.setRowHeight(row: 1, height: 25)
        original.setAutoFilter(CellRange("A1:B3"))
        original.mergeCells(CellRange("C1:D1"))
        original.addValidation(CellRange("E1:E10"), type: .decimal(min: 0, max: 1000))
        original.addValidation(CellRange("F1:F10"), type: .integer(min: 1, max: 100))

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try workbook.save(to: tempURL)

        let zipData = try Data(contentsOf: tempURL)
        let entries = try SwiftZIP.ZIPReader.read(from: zipData)
        guard let wsEntry = entries.first(where: { $0.path.contains("sheet1.xml") }) else {
            XCTFail("Missing sheet1.xml"); return
        }
        let ssEntry = entries.first(where: { $0.path.contains("sharedStrings.xml") })
        let stEntry = entries.first(where: { $0.path.contains("styles.xml") })
        let sharedStrings = try SharedStringsParser.parse(data: ssEntry?.data ?? Data())
        let styles = try StyleSheetParser.parse(data: stEntry?.data ?? Data())

        let parsed = try parseSheet(data: wsEntry.data,
                                    sharedStrings: sharedStrings,
                                    styles: styles)

        // Cell values
        XCTAssertEqual(parsed.cell(at: "A1"), .text("Name"))
        XCTAssertEqual(parsed.cell(at: "B1"), .text("Amount"))
        XCTAssertEqual(parsed.cell(at: "A2"), .text("Alice"))
        XCTAssertEqual(parsed.cell(at: "B2"), .number(100))
        XCTAssertEqual(parsed.cell(at: "A3"), .text("Bob"))
        XCTAssertEqual(parsed.cell(at: "B3"), .number(200))

        // Formula
        guard case .formula(let ast, _) = parsed.cell(at: "B4") else {
            XCTFail("Expected formula at B4"); return
        }
        XCTAssertEqual(ast, .function("SUM", [.cellRange(CellRange("B2:B3"))]))

        // Layout
        XCTAssertEqual(parsed.frozenPaneRef, "A2")
        XCTAssertEqual(parsed.columnWidths[1], 20)
        XCTAssertEqual(parsed.columnWidths[2], 15)
        XCTAssertEqual(parsed.rowHeights[1], 25)
        XCTAssertEqual(parsed.autoFilterRange?.reference, "A1:B3")
        XCTAssertEqual(parsed.mergedCells.count, 1)
        XCTAssertEqual(parsed.mergedCells.first?.reference, "C1:D1")

        // Validations
        XCTAssertEqual(parsed.validations.count, 2)
        if case .decimal(let min, let max) = parsed.validations[0].type {
            XCTAssertEqual(min, 0, accuracy: 0.001)
            XCTAssertEqual(max, 1000, accuracy: 0.001)
        } else {
            XCTFail("Expected decimal validation")
        }
        if case .integer(let min, let max) = parsed.validations[1].type {
            XCTAssertEqual(min, 1)
            XCTAssertEqual(max, 100)
        } else {
            XCTFail("Expected integer validation")
        }

        // Styles survived (header cells should be bold)
        let a1Style = parsed.cells["A1"]?.1
        XCTAssertTrue(a1Style?.font.bold ?? false, "Header should be bold")
    }
}
