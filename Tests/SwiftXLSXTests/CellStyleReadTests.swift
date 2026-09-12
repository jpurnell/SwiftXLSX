import XCTest
@testable import SwiftXLSX
import SwiftZIP
import Foundation

/// A cell's presentation survives the read.
///
/// The reader has resolved each cell's style since it was written — including
/// Excel's built-in number formats, so `numFmtId="9"` arrives as `0%` — and then
/// stored it where no caller could reach it. `Worksheet.cells` is `private(set)`
/// and internal, and nothing else exposed the style.
///
/// The format is not decoration. It is often the only statement a workbook makes
/// about what a number *is*: `0.4` in a cell formatted `0%` is a margin, the same
/// `0.4` formatted `$#,##0` is money, and the label beside it may say neither.
final class CellStyleReadTests: XCTestCase {

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
        </Types>
        """

    private static let packageRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """

    private static let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="Model" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        </Relationships>
        """

    /// Style 1 is Excel's built-in percent; style 2 is a custom currency format.
    private static let stylesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <numFmts count="1"><numFmt numFmtId="164" formatCode="&quot;$&quot;#,##0"/></numFmts>\
        <cellXfs count="3">\
        <xf numFmtId="0"/><xf numFmtId="9"/><xf numFmtId="164"/>\
        </cellXfs></styleSheet>
        """

    private static let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1">\
        <c r="A1"><v>5</v></c>\
        <c r="B1" s="1"><v>0.4</v></c>\
        <c r="C1" s="2"><v>1000000</v></c>\
        </row></sheetData></worksheet>
        """

    private func workbook() throws -> Workbook {
        let entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/styles.xml", data: Data(Self.stylesXML.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheetXML.utf8)),
        ]
        return try Workbook(xlsxData: ZIPWriter.write(entries: entries))
    }

    func testABuiltInNumberFormatIsReadable() throws {
        let sheet = try XCTUnwrap(workbook().sheets.first)
        XCTAssertEqual(
            sheet.style(at: "B1")?.numberFormat.formatString, "0%",
            "numFmtId 9 is Excel's own percent and never appears in numFmts"
        )
    }

    func testACustomNumberFormatIsReadable() throws {
        let sheet = try XCTUnwrap(workbook().sheets.first)
        XCTAssertEqual(sheet.style(at: "C1")?.numberFormat.formatString, "\"$\"#,##0")
    }

    func testAnUnstyledCellIsGeneral() throws {
        let sheet = try XCTUnwrap(workbook().sheets.first)
        XCTAssertEqual(sheet.style(at: "A1")?.numberFormat, .general)
    }

    func testAnEmptyCellHasNoStyle() throws {
        let sheet = try XCTUnwrap(workbook().sheets.first)
        XCTAssertNil(sheet.style(at: "Z99"), "nothing is there to have one")
    }

    func testAWrittenCellKeepsTheStyleItWasGiven() throws {
        let book = Workbook()
        let sheet = book.addSheet(name: "Model")
        sheet.write(0.4, to: "A1", style: .general.with(numberFormat: .percent))

        XCTAssertEqual(sheet.style(at: "A1")?.numberFormat, .percent)
    }
}
