import Testing
import Foundation
import SwiftZIP
@testable import SwiftXLSX

@Suite
struct WorksheetXMLTests {

    // MARK: - Helpers

    private func generateXML(configure: (Worksheet) -> Void) throws -> String {
        let wb = Workbook()
        let ws = wb.addSheet(name: "Sheet1")
        configure(ws)
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
        try wb.save(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        return try extractSheetXML(from: data)
    }

    private func extractSheetXML(from zipData: Data) throws -> String {
        guard let entry = try ZIPReader.readEntry(
            named: "xl/worksheets/sheet1.xml", from: zipData
        ) else { return "" }
        return String(data: entry.data, encoding: .utf8) ?? ""
    }

    // MARK: - Empty Sheet (Baseline)

    @Test("Empty sheet baseline")
    func testEmptySheetBaseline() throws {
        let xml = try generateXML { _ in }
        #expect(xml.contains("<sheetData>"))
        #expect(xml.contains("</worksheet>"))
        #expect(!(xml.contains("<sheetViews>")))
        #expect(!(xml.contains("<autoFilter")))
        #expect(!(xml.contains("<mergeCells")))
        #expect(!(xml.contains("<dataValidations")))
    }

    // MARK: - Freeze Panes

    @Test("Freeze panes XML")
    func testFreezePanesXML() throws {
        let xml = try generateXML { ws in
            ws.write("Header", to: "A1")
            ws.freezePanes(at: "A2")
        }
        #expect(xml.contains("<sheetViews>"))
        #expect(xml.contains("state=\"frozen\""))
        #expect(xml.contains("ySplit=\"1\""))
        #expect(xml.contains("xSplit=\"0\""))
        #expect(xml.contains("topLeftCell=\"A2\""))
    }

    @Test("Freeze panes at C 3")
    func testFreezePanesAtC3() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.freezePanes(at: "C3")
        }
        #expect(xml.contains("xSplit=\"2\""))
        #expect(xml.contains("ySplit=\"2\""))
        #expect(xml.contains("topLeftCell=\"C3\""))
    }

    @Test("Freeze panes before cols")
    func testFreezePanesBeforeCols() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.freezePanes(at: "A2")
            ws.setColumnWidth(column: "A", width: 20)
        }
        guard let viewsPos = xml.range(of: "<sheetViews>"),
              let colsPos = xml.range(of: "<cols>") else {
            Issue.record("Missing sheetViews or cols")
            return
        }
        #expect(viewsPos.lowerBound < colsPos.lowerBound)
    }

    // MARK: - Row Heights

    @Test("Row height XML")
    func testRowHeightXML() throws {
        let xml = try generateXML { ws in
            ws.write("Title", to: "A1")
            ws.setRowHeight(row: 1, height: 40)
        }
        #expect(xml.contains("ht=\"40\""))
        #expect(xml.contains("customHeight=\"1\""))
    }

    @Test("Row height decimal")
    func testRowHeightDecimal() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setRowHeight(row: 1, height: 25.5)
        }
        #expect(xml.contains("ht=\"25.5\""))
    }

    // MARK: - Auto-Filter

    @Test("Auto filter XML")
    func testAutoFilterXML() throws {
        let xml = try generateXML { ws in
            ws.write("Name", to: "A1")
            ws.write("Value", to: "B1")
            ws.setAutoFilter(CellRange(from: "A1", to: "B10"))
        }
        #expect(xml.contains("<autoFilter ref=\"A1:B10\"/>"))
    }

    @Test("Auto filter after sheet data")
    func testAutoFilterAfterSheetData() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setAutoFilter(CellRange(from: "A1", to: "A10"))
        }
        guard let dataEnd = xml.range(of: "</sheetData>"),
              let filterPos = xml.range(of: "<autoFilter") else {
            Issue.record("Missing sheetData end or autoFilter")
            return
        }
        #expect(dataEnd.upperBound <= filterPos.lowerBound)
    }

    // MARK: - Merge Cells

    @Test("Merge cells XML")
    func testMergeCellsXML() throws {
        let xml = try generateXML { ws in
            ws.write("Merged", to: "A1")
            ws.mergeCells(CellRange(from: "A1", to: "B2"))
        }
        #expect(xml.contains("<mergeCells count=\"1\">"))
        #expect(xml.contains("<mergeCell ref=\"A1:B2\"/>"))
    }

    @Test("Multiple merge cells")
    func testMultipleMergeCells() throws {
        let xml = try generateXML { ws in
            ws.write("A", to: "A1")
            ws.write("B", to: "C1")
            ws.mergeCells(CellRange(from: "A1", to: "B1"))
            ws.mergeCells(CellRange(from: "C1", to: "D1"))
        }
        #expect(xml.contains("<mergeCells count=\"2\">"))
    }

    @Test("Merge cells after auto filter")
    func testMergeCellsAfterAutoFilter() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setAutoFilter(CellRange(from: "A1", to: "A10"))
            ws.mergeCells(CellRange(from: "B1", to: "C1"))
        }
        guard let filterPos = xml.range(of: "<autoFilter"),
              let mergePos = xml.range(of: "<mergeCells") else {
            Issue.record("Missing autoFilter or mergeCells")
            return
        }
        #expect(filterPos.lowerBound < mergePos.lowerBound)
    }

    // MARK: - Data Validations

    @Test("List validation XML")
    func testListValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Choice", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .list(["Yes", "No", "Maybe"]))
        }
        #expect(xml.contains("<dataValidations count=\"1\">"))
        #expect(xml.contains("type=\"list\""))
        #expect(xml.contains("sqref=\"A2:A10\""))
        #expect(xml.contains("\"Yes,No,Maybe\""))
    }

    @Test("Decimal validation XML")
    func testDecimalValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Rate", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .decimal(min: 0, max: 100))
        }
        #expect(xml.contains("type=\"decimal\""))
        #expect(xml.contains("operator=\"between\""))
        #expect(xml.contains("<formula1>0</formula1>"))
        #expect(xml.contains("<formula2>100</formula2>"))
    }

    @Test("Integer validation XML")
    func testIntegerValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Qty", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .integer(min: 1, max: 999))
        }
        #expect(xml.contains("type=\"whole\""))
        #expect(xml.contains("<formula1>1</formula1>"))
        #expect(xml.contains("<formula2>999</formula2>"))
    }

    @Test("Validations after merge cells")
    func testValidationsAfterMergeCells() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.mergeCells(CellRange(from: "A1", to: "B1"))
            ws.addValidation(CellRange(from: "C1", to: "C10"), type: .list(["A", "B"]))
        }
        guard let mergePos = xml.range(of: "<mergeCells"),
              let validPos = xml.range(of: "<dataValidations") else {
            Issue.record("Missing mergeCells or dataValidations")
            return
        }
        #expect(mergePos.lowerBound < validPos.lowerBound)
    }

    // MARK: - Combined Features

    @Test("All features XML order")
    func testAllFeaturesXMLOrder() throws {
        let xml = try generateXML { ws in
            ws.write("Title", to: "A1")
            ws.write("Data", to: "A2")
            ws.freezePanes(at: "A2")
            ws.setColumnWidth(column: "A", width: 20)
            ws.setRowHeight(row: 1, height: 40)
            ws.setAutoFilter(CellRange(from: "A1", to: "A10"))
            ws.mergeCells(CellRange(from: "B1", to: "C1"))
            ws.addValidation(CellRange(from: "D1", to: "D10"), type: .list(["X", "Y"]))
        }
        #expect(xml.contains("<sheetViews>"))
        #expect(xml.contains("<cols>"))
        #expect(xml.contains("ht=\"40\""))
        #expect(xml.contains("<autoFilter"))
        #expect(xml.contains("<mergeCells"))
        #expect(xml.contains("<dataValidations"))

        let positions = [
            xml.range(of: "<sheetViews>")?.lowerBound,
            xml.range(of: "<cols>")?.lowerBound,
            xml.range(of: "<sheetData>")?.lowerBound,
            xml.range(of: "</sheetData>")?.lowerBound,
            xml.range(of: "<autoFilter")?.lowerBound,
            xml.range(of: "<mergeCells")?.lowerBound,
            xml.range(of: "<dataValidations")?.lowerBound,
        ].compactMap { $0 }

        for i in 1..<positions.count {
            #expect(positions[i-1] < positions[i], "OOXML element order violation at index \(i)")
        }
    }
}
