import Testing
import Foundation
@testable import SwiftXLSX
import SwiftZIP

/// Named ranges survive the read.
///
/// `xl/workbook.xml` has been parsed for defined names since the reader was
/// written, and the result was discarded at the call site — `let (sheets, _)`.
/// A formula referring to a named range therefore reached callers as
/// `.namedRange("Circ")` with no way on the public API to find out what `Circ`
/// was, which makes the reference unresolvable rather than merely inconvenient.
/// Real models use named ranges for exactly the switches a reader most needs:
/// the Wharton LBO model's circularity toggle is one.
@Suite
struct NamedRangeReadTests {

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

    @Test("A workbook scoped name resolves to its cell")
    func testAWorkbookScopedNameResolvesToItsCell() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Circ\">"
                + "&apos;Model&apos;!$M$1</definedName></definedNames>")

        let target = try #require(book.namedRanges.resolve("Circ"))
        #expect(target == .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$M$1"))))
    }

    @Test("A sheet scoped name is scoped to its sheet")
    func testASheetScopedNameIsScopedToItsSheet() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Circ\" localSheetId=\"0\">"
                + "&apos;Model&apos;!$M$1</definedName></definedNames>")

        #expect(book.namedRanges.all.first?.scope == .sheet("Model"))
        #expect(
            book.namedRanges.resolve("Circ", inSheet: "Model")
                == .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$M$1"))),
            "localSheetId is an index into the sheets, not a name; resolving it wrong scopes the name to a sheet that may not exist"
        )
    }

    @Test("A name spanning A range resolves to A range")
    func testANameSpanningARangeResolvesToARange() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Grid\">"
                + "&apos;Model&apos;!$A$1:$U$64</definedName></definedNames>")

        let target = try #require(book.namedRanges.resolve("Grid"))
        #expect(target == .sheetRange(
                SheetReference(
                    sheet: "Model",
                    range: CellRange(from: CellRef("$A$1"), to: CellRef("$U$64")))))
    }

    /// A target that is not a reference is kept verbatim — and now *says* it is verbatim.
    ///
    /// **The instinct was right and the representation was wrong.** This asserted
    /// `.formula(.text("0.05*2"))`, which keeps the characters but claims the name **is a
    /// text constant** — and that claim is acted on. Written back out it gains quotes, so a
    /// range becomes a caption and a number becomes a string; evaluated, it hands a formula
    /// text where a range was meant. `SUMIFS(amounts, …)` answered zero across 1,058 cells in
    /// one corpus workbook for exactly that reason.
    ///
    /// `.unparsed` keeps the same characters and says the true thing about them, which makes
    /// it the one target whose round trip is exact by construction.
    ///
    /// Reversed rather than deleted, because the reasoning it carried — *keeping what the
    /// file said beats discarding the name or inventing a cell for it* — is the reasoning
    /// that survived.
    @Test("A name whose target is not A reference is kept verbatim")
    func testANameWhoseTargetIsNotAReferenceIsKeptVerbatim() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"Rate\">"
                + "0.05*2</definedName></definedNames>")

        #expect(book.namedRanges.resolve("Rate") == .unparsed("0.05*2"), "kept verbatim, and labelled as unread rather than as a text constant")
    }

    @Test("A workbook with no names has none")
    func testAWorkbookWithNoNamesHasNone() throws {
        let book = try workbook(definedNames: "")
        #expect(book.namedRanges.count == 0)
    }

    /// Excel writes its own page-setup entries here alongside the user's names.
    @Test("Built in names are kept")
    func testBuiltInNamesAreKept() throws {
        let book = try workbook(
            definedNames: "<definedNames><definedName name=\"_xlnm.Print_Area\" "
                + "localSheetId=\"0\">&apos;Model&apos;!$A$1:$U$64</definedName></definedNames>")

        #expect(book.namedRanges.all.map(\.name) == ["_xlnm.Print_Area"], "kept rather than filtered, so a caller decides what to ignore")
    }

    /// A name defined twice resolves by scope rather than by file order.
    @Test("A sheet scoped name wins over A workbook scoped one")
    func testASheetScopedNameWinsOverAWorkbookScopedOne() throws {
        let book = try workbook(
            definedNames: "<definedNames>"
                + "<definedName name=\"Circ\">&apos;Model&apos;!$M$1</definedName>"
                + "<definedName name=\"Circ\" localSheetId=\"0\">&apos;Model&apos;!$N$1</definedName>"
                + "</definedNames>")

        #expect(book.namedRanges.resolve("Circ", inSheet: "Model") == .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$N$1"))))
        #expect(book.namedRanges.resolve("Circ") == .sheetCell(SheetReference(sheet: "Model", cell: CellRef("$M$1"))), "and an unqualified lookup still finds the workbook-scoped one")
    }
}
