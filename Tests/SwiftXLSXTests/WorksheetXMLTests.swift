import XCTest
import SwiftZIP
@testable import SwiftXLSX

final class WorksheetXMLTests: XCTestCase {

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

    func testEmptySheetBaseline() throws {
        let xml = try generateXML { _ in }
        XCTAssertTrue(xml.contains("<sheetData>"))
        XCTAssertTrue(xml.contains("</worksheet>"))
        XCTAssertFalse(xml.contains("<sheetViews>"))
        XCTAssertFalse(xml.contains("<autoFilter"))
        XCTAssertFalse(xml.contains("<mergeCells"))
        XCTAssertFalse(xml.contains("<dataValidations"))
    }

    // MARK: - Freeze Panes

    func testFreezePanesXML() throws {
        let xml = try generateXML { ws in
            ws.write("Header", to: "A1")
            ws.freezePanes(at: "A2")
        }
        XCTAssertTrue(xml.contains("<sheetViews>"))
        XCTAssertTrue(xml.contains("state=\"frozen\""))
        XCTAssertTrue(xml.contains("ySplit=\"1\""))
        XCTAssertTrue(xml.contains("xSplit=\"0\""))
        XCTAssertTrue(xml.contains("topLeftCell=\"A2\""))
    }

    func testFreezePanesAtC3() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.freezePanes(at: "C3")
        }
        XCTAssertTrue(xml.contains("xSplit=\"2\""))
        XCTAssertTrue(xml.contains("ySplit=\"2\""))
        XCTAssertTrue(xml.contains("topLeftCell=\"C3\""))
    }

    func testFreezePanesBeforeCols() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.freezePanes(at: "A2")
            ws.setColumnWidth(column: "A", width: 20)
        }
        guard let viewsPos = xml.range(of: "<sheetViews>"),
              let colsPos = xml.range(of: "<cols>") else {
            XCTFail("Missing sheetViews or cols")
            return
        }
        XCTAssertTrue(viewsPos.lowerBound < colsPos.lowerBound)
    }

    // MARK: - Row Heights

    func testRowHeightXML() throws {
        let xml = try generateXML { ws in
            ws.write("Title", to: "A1")
            ws.setRowHeight(row: 1, height: 40)
        }
        XCTAssertTrue(xml.contains("ht=\"40\""))
        XCTAssertTrue(xml.contains("customHeight=\"1\""))
    }

    func testRowHeightDecimal() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setRowHeight(row: 1, height: 25.5)
        }
        XCTAssertTrue(xml.contains("ht=\"25.5\""))
    }

    // MARK: - Auto-Filter

    func testAutoFilterXML() throws {
        let xml = try generateXML { ws in
            ws.write("Name", to: "A1")
            ws.write("Value", to: "B1")
            ws.setAutoFilter(CellRange(from: "A1", to: "B10"))
        }
        XCTAssertTrue(xml.contains("<autoFilter ref=\"A1:B10\"/>"))
    }

    func testAutoFilterAfterSheetData() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setAutoFilter(CellRange(from: "A1", to: "A10"))
        }
        guard let dataEnd = xml.range(of: "</sheetData>"),
              let filterPos = xml.range(of: "<autoFilter") else {
            XCTFail("Missing sheetData end or autoFilter")
            return
        }
        XCTAssertTrue(dataEnd.upperBound <= filterPos.lowerBound)
    }

    // MARK: - Merge Cells

    func testMergeCellsXML() throws {
        let xml = try generateXML { ws in
            ws.write("Merged", to: "A1")
            ws.mergeCells(CellRange(from: "A1", to: "B2"))
        }
        XCTAssertTrue(xml.contains("<mergeCells count=\"1\">"))
        XCTAssertTrue(xml.contains("<mergeCell ref=\"A1:B2\"/>"))
    }

    func testMultipleMergeCells() throws {
        let xml = try generateXML { ws in
            ws.write("A", to: "A1")
            ws.write("B", to: "C1")
            ws.mergeCells(CellRange(from: "A1", to: "B1"))
            ws.mergeCells(CellRange(from: "C1", to: "D1"))
        }
        XCTAssertTrue(xml.contains("<mergeCells count=\"2\">"))
    }

    func testMergeCellsAfterAutoFilter() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.setAutoFilter(CellRange(from: "A1", to: "A10"))
            ws.mergeCells(CellRange(from: "B1", to: "C1"))
        }
        guard let filterPos = xml.range(of: "<autoFilter"),
              let mergePos = xml.range(of: "<mergeCells") else {
            XCTFail("Missing autoFilter or mergeCells")
            return
        }
        XCTAssertTrue(filterPos.lowerBound < mergePos.lowerBound)
    }

    // MARK: - Data Validations

    func testListValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Choice", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .list(["Yes", "No", "Maybe"]))
        }
        XCTAssertTrue(xml.contains("<dataValidations count=\"1\">"))
        XCTAssertTrue(xml.contains("type=\"list\""))
        XCTAssertTrue(xml.contains("sqref=\"A2:A10\""))
        XCTAssertTrue(xml.contains("\"Yes,No,Maybe\""))
    }

    func testDecimalValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Rate", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .decimal(min: 0, max: 100))
        }
        XCTAssertTrue(xml.contains("type=\"decimal\""))
        XCTAssertTrue(xml.contains("operator=\"between\""))
        XCTAssertTrue(xml.contains("<formula1>0</formula1>"))
        XCTAssertTrue(xml.contains("<formula2>100</formula2>"))
    }

    func testIntegerValidationXML() throws {
        let xml = try generateXML { ws in
            ws.write("Qty", to: "A1")
            ws.addValidation(CellRange(from: "A2", to: "A10"), type: .integer(min: 1, max: 999))
        }
        XCTAssertTrue(xml.contains("type=\"whole\""))
        XCTAssertTrue(xml.contains("<formula1>1</formula1>"))
        XCTAssertTrue(xml.contains("<formula2>999</formula2>"))
    }

    func testValidationsAfterMergeCells() throws {
        let xml = try generateXML { ws in
            ws.write("Data", to: "A1")
            ws.mergeCells(CellRange(from: "A1", to: "B1"))
            ws.addValidation(CellRange(from: "C1", to: "C10"), type: .list(["A", "B"]))
        }
        guard let mergePos = xml.range(of: "<mergeCells"),
              let validPos = xml.range(of: "<dataValidations") else {
            XCTFail("Missing mergeCells or dataValidations")
            return
        }
        XCTAssertTrue(mergePos.lowerBound < validPos.lowerBound)
    }

    // MARK: - Combined Features

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
        XCTAssertTrue(xml.contains("<sheetViews>"))
        XCTAssertTrue(xml.contains("<cols>"))
        XCTAssertTrue(xml.contains("ht=\"40\""))
        XCTAssertTrue(xml.contains("<autoFilter"))
        XCTAssertTrue(xml.contains("<mergeCells"))
        XCTAssertTrue(xml.contains("<dataValidations"))

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
            XCTAssertTrue(positions[i-1] < positions[i], "OOXML element order violation at index \(i)")
        }
    }
}
