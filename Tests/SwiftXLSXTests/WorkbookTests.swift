import Testing
import Foundation
@testable import SwiftXLSX
import SwiftZIP

@Suite
struct WorkbookTests {

    // MARK: - Workbook Construction

    @Test("Empty workbook")
    func testEmptyWorkbook() {
        let wb = Workbook()
        #expect(wb.sheets.isEmpty)
    }

    @Test("Add sheet")
    func testAddSheet() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Summary")
        #expect(wb.sheets.count == 1)
        #expect(sheet.name == "Summary")
    }

    @Test("Multiple sheets")
    func testMultipleSheets() {
        let wb = Workbook()
        _ = wb.addSheet(name: "Inputs")
        _ = wb.addSheet(name: "Calculations")
        _ = wb.addSheet(name: "Results")
        #expect(wb.sheets.count == 3)
        #expect(wb.sheets[0].name == "Inputs")
        #expect(wb.sheets[2].name == "Results")
    }

    // MARK: - Cell Writing

    @Test("Write string")
    func testWriteString() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")
        let value = sheet.cell(at: "A1")
        #expect(value == .text("Hello"))
    }

    @Test("Write number")
    func testWriteNumber() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(1_950_000.0, to: "B3")
        let value = sheet.cell(at: "B3")
        #expect(value == .number(1_950_000))
    }

    @Test("Write formula")
    func testWriteFormula() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.writeFormula("=B1*0.2", to: "B2")
        let value = try #require(sheet.cell(at: "B2"))
        #expect(value.isFormula)
    }

    @Test("Write integer")
    func testWriteInteger() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(42, to: "C1")
        let value = sheet.cell(at: "C1")
        #expect(value == .number(42))
    }

    // MARK: - Cell References

    @Test("Cell ref parsing")
    func testCellRefParsing() {
        let ref = CellRef("C5")
        #expect(ref.column == 3)
        #expect(ref.row == 5)
    }

    @Test("Cell ref multi column")
    func testCellRefMultiColumn() {
        let ref = CellRef("AA1")
        #expect(ref.column == 27)
        #expect(ref.row == 1)
    }

    // MARK: - Save to File

    @Test("Save creates file")
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
        #expect(try url.checkResourceIsReachable())
    }

    @Test("Saved file is ZIP")
    func testSavedFileIsZIP() throws {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: url) }

        try wb.save(to: url)

        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
        // ZIP magic bytes: PK (0x50, 0x4B)
        #expect(data[0] == 0x50)
        #expect(data[1] == 0x4B)
    }

    @Test("Saved file contains required entries")
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
            #expect(entryPaths.contains(file), "Missing required file: \(file)")
        }
    }

    @Test("Sheet XML contains cell data")
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

        let sheetEntry = try #require(
            entries.first { $0.path == "xl/worksheets/sheet1.xml" },
            "Missing xl/worksheets/sheet1.xml"
        )
        let sheetXML = try #require(String(data: sheetEntry.data, encoding: .utf8))
        #expect(sheetXML.contains("<v>500000"), "Should contain numeric value")
        #expect(sheetXML.contains("B1*2"), "Should contain formula")

        let stringsEntry = try #require(
            entries.first { $0.path == "xl/sharedStrings.xml" },
            "Missing xl/sharedStrings.xml"
        )
        let stringsXML = try #require(String(data: stringsEntry.data, encoding: .utf8))
        #expect(stringsXML.contains("Revenue"), "Shared strings should contain 'Revenue'")
    }
}
