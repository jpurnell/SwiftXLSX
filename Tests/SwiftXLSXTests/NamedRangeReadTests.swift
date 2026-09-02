import XCTest
@testable import SwiftXLSX
import SwiftZIP
import Foundation

/// Named ranges survive the read.
///
/// `xl/workbook.xml` has been parsed for defined names since the reader was
/// written, and the result was discarded at the call site — `let (sheets, _)`.
/// A formula referring to a named range therefore reached callers as
/// `.namedRange("Circ")` with no way on the public API to find out what `Circ`
/// was, which makes the reference unresolvable rather than merely inconvenient.
/// Real models use named ranges for exactly the switches a reader most needs:
/// the Wharton LBO model's circularity toggle is one.
final class NamedRangeReadTests: XCTestCase {

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        </Types>
        """

    private static let packageRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        </Relationships>
        """

    private static let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="M1"><v>1</v></c></row></sheetData></worksheet>
        """

    /// A workbook whose `definedNames` element is written the way Excel writes it.
    private func workbook(definedNames: String) throws -> Workbook {
        let workbookXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
            <sheets><sheet name="Model" sheetId="1" r:id="rId1"/></sheets>\
            \(definedNames)</workbook>
            """
        let entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheetXML.utf8)),
        ]
        return try Workbook(xlsxData: ZIPWriter.write(entries: entries))
    }

    func testAWorkbookScopedNameResolvesToItsCell() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Circ\">"
                + "&apos;Model&apos;!$M$1</definedName></definedNames>")

        let target = try XCTUnwrap(book.namedRanges.resolve("Circ"))
        XCTAssertEqual(target, .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$M$1"))))
    }

    func testASheetScopedNameIsScopedToItsSheet() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Circ\" localSheetId=\"0\">"
                + "&apos;Model&apos;!$M$1</definedName></definedNames>")

        XCTAssertEqual(book.namedRanges.all.first?.scope, .sheet("Model"))
        XCTAssertNotNil(
            book.namedRanges.resolve("Circ", inSheet: "Model"),
            "localSheetId is an index into the sheets, not a name; resolving it wrong "
                + "scopes the name to a sheet that may not exist"
        )
    }

    func testANameSpanningARangeResolvesToARange() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Grid\">"
                + "&apos;Model&apos;!$A$1:$U$64</definedName></definedNames>")

        let target = try XCTUnwrap(book.namedRanges.resolve("Grid"))
        XCTAssertEqual(
            target,
            .sheetRange(
                SheetReference(
                    sheet: "Model",
                    range: CellRange(from: CellRef("$A$1"), to: CellRef("$U$64")))))
    }

    func testANameWhoseTargetIsNotAReferenceIsKeptVerbatim() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Rate\">"
                + "0.05*2</definedName></definedNames>")

        XCTAssertEqual(
            book.namedRanges.resolve("Rate"), .formula(.text("0.05*2")),
            "Excel permits any formula here. Keeping what the file said beats "
                + "discarding the name or inventing a cell for it"
        )
    }

    func testAWorkbookWithNoNamesHasNone() throws {
        let book = try workbook(definedNames: "")
        XCTAssertEqual(book.namedRanges.count, 0)
    }

    /// Excel writes its own page-setup entries here alongside the user's names.
    func testBuiltInNamesAreKept() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"_xlnm.Print_Area\" "
                + "localSheetId=\"0\">&apos;Model&apos;!$A$1:$U$64</definedName></definedNames>")

        XCTAssertEqual(
            book.namedRanges.all.map(\.name), ["_xlnm.Print_Area"],
            "kept rather than filtered, so a caller decides what to ignore"
        )
    }

    /// A name defined twice resolves by scope rather than by file order.
    func testASheetScopedNameWinsOverAWorkbookScopedOne() throws {
        let book = try workbook(
            definedNames: "<definedNames>"
                + "<definedName name=\"Circ\">&apos;Model&apos;!$M$1</definedName>"
                + "<definedName name=\"Circ\" localSheetId=\"0\">&apos;Model&apos;!$N$1</definedName>"
                + "</definedNames>")

        XCTAssertEqual(
            book.namedRanges.resolve("Circ", inSheet: "Model"),
            .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$N$1"))))
        XCTAssertEqual(
            book.namedRanges.resolve("Circ"),
            .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$M$1"))),
            "and an unqualified lookup still finds the workbook-scoped one"
        )
    }
}
