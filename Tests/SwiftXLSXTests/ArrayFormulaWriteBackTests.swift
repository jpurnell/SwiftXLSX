import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// Writing an array formula back out after reading one.
///
/// ## Measured
///
/// A corpus round-trip — read with `Workbook(xlsxData:)`, written straight back with `save()`
/// — gained **13 formula cells** in one workbook and nobody could say where from. The sheet
/// holds
///
/// ```
/// <c r="E4" s="10"><f t="array" ref="E4:K5">TRANSPOSE(O3:P9)</f><v>0.818…</v></c>
/// <c r="F4" s="13"><v>0.912…</v></c>
/// ```
///
/// `E4:K5` is fourteen cells. Excel writes the formula once, at the anchor, and gives the
/// other thirteen nothing but a cached value — and thirteen is exactly the gain.
///
/// The reader is right about them. It marks each member `_ARRAY(anchor, span)`, a sentinel
/// meaning *computed by its anchor*, deliberately rather than copying the formula onto all
/// fourteen — one evaluation fills the rectangle, and claiming otherwise would say each cell
/// independently recomputes the whole thing.
///
/// **The writer has no counterpart for that sentinel.** It falls into the ordinary
/// formula-cell branch, serialises `_ARRAY(…)` to nothing, and emits `<f/>` — an `<f>` element
/// with no formula in it. That is not what Excel wrote and not something Excel writes.
///
/// The same shape is what `_DATATABLE` reads to, and it is covered here for the same reason.
@Suite
struct ArrayFormulaWriteBackTests {

    // MARK: - A package small enough to read in one screen

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

    private static let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        </Relationships>
        """

    /// `B2` anchors an array formula over `B2:C3`; `C2`, `B3` and `C3` are its members and
    /// carry only cached values, exactly as Excel writes them.
    private static let sheetData = """
        <row r="1"><c r="E1"><v>1</v></c><c r="F1"><v>2</v></c></row>\
        <row r="2"><c r="B2"><f t="array" ref="B2:C3">TRANSPOSE(E1:F2)</f><v>1</v></c>\
        <c r="C2"><v>3</v></c></row>\
        <row r="3"><c r="B3"><v>2</v></c><c r="C3"><v>4</v></c></row>
        """

    private func written(_ sheetData: String = sheetData) throws -> String {
        let sheet = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
            <sheetData>\(sheetData)</sheetData></worksheet>
            """
        let source = try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8)),
        ])
        let saved = try Workbook(xlsxData: source).save()
        let entries = try ZIPReader.read(from: saved)
        let part = try #require(entries.first { $0.path == "xl/worksheets/sheet1.xml" })
        return String(decoding: part.data, as: UTF8.self)
    }

    // MARK: - The defect

    /// **An `<f>` with nothing in it is not a formula.** Excel does not write one, and a cell
    /// that reads `<f/><v>3</v>` claims to be computed by a formula it does not carry.
    @Test("no cell is written with an empty formula element")
    func writesNoEmptyFormulaElement() throws {
        let xml = try written()
        #expect(!xml.contains("<f/>"),
                "an array member was written as an empty formula: \(xml)")
        #expect(!xml.contains("<f></f>"))
    }

    /// The members keep their values and stop claiming to be formulas of their own.
    @Test("an array member is written as its cached value alone")
    func writesMembersAsValues() throws {
        let xml = try written()
        for reference in ["C2", "B3", "C3"] {
            let cell = try #require(Self.element(reference, in: xml),
                                    "\(reference) was not written at all")
            #expect(!cell.contains("<f"),
                    "\(reference) is a member of B2's span and must carry no formula: \(cell)")
            #expect(cell.contains("<v>"), "\(reference) lost its cached value: \(cell)")
        }
    }

    /// And the anchor keeps the whole thing together: drop `t="array" ref=` and the members
    /// become unexplained constants.
    @Test("the anchor keeps its array attributes and its formula")
    func writesTheAnchor() throws {
        let xml = try written()
        let anchor = try #require(Self.element("B2", in: xml))
        #expect(anchor.contains("t=\"array\""), "B2 lost its array marking: \(anchor)")
        #expect(anchor.contains("ref=\"B2:C3\""), "B2 lost its span: \(anchor)")
        #expect(anchor.contains("TRANSPOSE"), "B2 lost its formula: \(anchor)")
    }

    /// **The span survives the trip**, which is what licenses writing the members bare: the
    /// anchor's `ref` is the only record that they belong to it, and a reader rebuilds them
    /// from it. If this fails, dropping `<f/>` really did lose something.
    @Test("a saved workbook still reads its array members as array-entered")
    func readsBackTheSpan() throws {
        let sheet = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
            <sheetData>\(Self.sheetData)</sheetData></worksheet>
            """
        let source = try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8)),
        ])
        let reopened = try Workbook(xlsxData: try Workbook(xlsxData: source).save())
        let provider = WorkbookValueProvider(workbook: reopened, currentSheet: "Sheet1")
        for reference in ["B2", "C2", "B3", "C3"] {
            #expect(provider.isArrayEntered(at: CellRef(reference), inSheet: "Sheet1"),
                    "\(reference) stopped being part of the array after a save")
        }
        #expect(!provider.isArrayEntered(at: CellRef("E1"), inSheet: "Sheet1"),
                "and a cell outside the span did not join it")
    }

    /// A data table reads to the same shape of sentinel and must not write an empty `<f>`
    /// either. Excel stores one as `<f t="dataTable" ref=… r1=… r2=…/>`.
    @Test("a data table member is not written as an empty formula")
    func writesNoEmptyFormulaForADataTable() throws {
        let xml = try written("""
            <row r="1"><c r="A1"><v>1</v></c></row>\
            <row r="2"><c r="B2"><f t="dataTable" ref="B2:C3" dt2D="1" dtr="0" r1="A1" r2="A2"/>\
            <v>5</v></c><c r="C2"><v>6</v></c></row>
            """)
        #expect(!xml.contains("<f/>"), "a data table cell was written as an empty formula: \(xml)")
    }

    // MARK: -

    /// The `<c>` element for one reference.
    ///
    /// A self-closing cell ends at the `/>` that closes its own tag; any other ends at
    /// `</c>`. Taking whichever of the two came first looked simpler and was wrong — a
    /// `<f/>` child put a `/>` inside the element and the match stopped there, which made
    /// this helper report that cells had lost values they still had.
    private static func element(_ reference: String, in xml: String) -> String? {
        guard let start = xml.range(of: "<c r=\"\(reference)\"") else { return nil }
        let rest = xml[start.lowerBound...]
        guard let tagEnd = rest.firstIndex(of: ">") else { return nil }
        if rest[rest.index(before: tagEnd)] == "/" {
            return String(rest[...tagEnd])
        }
        guard let close = rest.range(of: "</c>") else { return nil }
        return String(rest[..<close.upperBound])
    }
}
