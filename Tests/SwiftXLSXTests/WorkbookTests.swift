import XCTest
@testable import SwiftXLSX
import Foundation
import SwiftZIP

final class WorkbookTests: XCTestCase {

    // MARK: - Workbook Construction

    func testEmptyWorkbook() {
        let wb = Workbook()
        XCTAssertTrue(wb.sheets.isEmpty)
    }

    func testAddSheet() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Summary")
        XCTAssertEqual(wb.sheets.count, 1)
        XCTAssertEqual(sheet.name, "Summary")
    }

    func testMultipleSheets() {
        let wb = Workbook()
        _ = wb.addSheet(name: "Inputs")
        _ = wb.addSheet(name: "Calculations")
        _ = wb.addSheet(name: "Results")
        XCTAssertEqual(wb.sheets.count, 3)
        XCTAssertEqual(wb.sheets[0].name, "Inputs")
        XCTAssertEqual(wb.sheets[2].name, "Results")
    }

    // MARK: - Cell Writing

    func testWriteString() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")
        let value = sheet.cell(at: "A1")
        XCTAssertEqual(value, .text("Hello"))
    }

    func testWriteNumber() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(1_950_000.0, to: "B3")
        let value = sheet.cell(at: "B3")
        XCTAssertEqual(value, .number(1_950_000))
    }

    func testWriteFormula() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.writeFormula("=B1*0.2", to: "B2")
        let value = try XCTUnwrap(sheet.cell(at: "B2"))
        XCTAssertTrue(value.isFormula)
    }

    func testWriteInteger() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(42, to: "C1")
        let value = sheet.cell(at: "C1")
        XCTAssertEqual(value, .number(42))
    }

    // MARK: - Cell References

    func testCellRefParsing() {
        let ref = CellRef("C5")
        XCTAssertEqual(ref.column, 3)
        XCTAssertEqual(ref.row, 5)
    }

    func testCellRefMultiColumn() {
        let ref = CellRef("AA1")
        XCTAssertEqual(ref.column, 27)
        XCTAssertEqual(ref.row, 1)
    }

    // MARK: - Save to File

    func testSaveCreatesFile() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Revenue", to: "A1")
        sheet.write(1_000_000.0, to: "B1")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
            .standardizedFileURL
        defer { try? FileManager.default.removeItem(at: url) }

        try wb.save(to: url)
        XCTAssertTrue(try url.checkResourceIsReachable())
    }

    func testSavedFileIsZIP() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        try wb.save(to: url)

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        // ZIP magic bytes: PK (0x50, 0x4B)
        XCTAssertEqual(data[0], 0x50)
        XCTAssertEqual(data[1], 0x4B)
    }

    func testSavedFileContainsRequiredEntries() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        try wb.save(to: url)

        // Read the archive directly rather than extracting it: the entry names are
        // what this test is about, and nothing needs to touch the filesystem.
        let entryPaths = Set(try SwiftZIP.ZIPReader.read(from: url).map(\.path))

        let requiredFiles = [
            "[Content_Types].xml",
            "_rels/.rels",
            "xl/workbook.xml",
            "xl/_rels/workbook.xml.rels",
            "xl/worksheets/sheet1.xml",
            "xl/styles.xml",
            "xl/sharedStrings.xml",
        ]
        for file in requiredFiles {
            XCTAssertTrue(entryPaths.contains(file), "Missing required file: \(file)")
        }
    }

    func testSheetXMLContainsCellData() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Revenue", to: "A1")
        sheet.write(500_000.0, to: "B1")
        sheet.writeFormula("=B1*2", to: "B2")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }
        try wb.save(to: url)

        let entries = try SwiftZIP.ZIPReader.read(from: url)

        let sheetEntry = try XCTUnwrap(
            entries.first { $0.path == "xl/worksheets/sheet1.xml" },
            "Missing xl/worksheets/sheet1.xml"
        )
        let sheetXML = try XCTUnwrap(String(data: sheetEntry.data, encoding: .utf8))
        XCTAssertTrue(sheetXML.contains("<v>500000"), "Should contain numeric value")
        XCTAssertTrue(sheetXML.contains("B1*2"), "Should contain formula")

        let stringsEntry = try XCTUnwrap(
            entries.first { $0.path == "xl/sharedStrings.xml" },
            "Missing xl/sharedStrings.xml"
        )
        let stringsXML = try XCTUnwrap(String(data: stringsEntry.data, encoding: .utf8))
        XCTAssertTrue(stringsXML.contains("Revenue"), "Shared strings should contain 'Revenue'")
    }
}
