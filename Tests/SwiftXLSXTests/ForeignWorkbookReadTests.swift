import XCTest
@testable import SwiftXLSX
import SwiftZIP
import Foundation

/// Reading `.xlsx` packages this library did **not** write.
///
/// Every other reader test round-trips through ``Workbook/save()``, so they only
/// ever exercise the narrow package shape this library emits. Excel's packages
/// differ in ways that are legal OOXML, and those differences are what break in
/// the field. These tests assemble packages by hand to cover that gap.
final class ForeignWorkbookReadTests: XCTestCase {

    // MARK: - Package Assembly

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        </Types>
        """

    /// The package-level relationships exactly as Excel orders them: the
    /// extended-properties relationship first, the workbook itself last.
    private static let excelShapedRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """

    /// `docProps/app.xml` as Excel writes it. It is well-formed XML that parses
    /// cleanly and contains no `<sheet>` elements, so mistaking it for the
    /// workbook part yields an empty workbook rather than an error.
    private static let appProperties = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">\
        <Application>Microsoft Excel</Application><DocSecurity>0</DocSecurity>\
        <TitlesOfParts><vt:vector size="1" baseType="lpstr" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">\
        <vt:lpstr>Model</vt:lpstr></vt:vector></TitlesOfParts>\
        </Properties>
        """

    private static let coreProperties = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" \
        xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:creator>Excel</dc:creator></cp:coreProperties>
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

    private static let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="A1"><v>1950000</v></c></row></sheetData></worksheet>
        """

    /// Builds an `.xlsx` package with the given package-level relationships XML.
    private func package(rels: String) throws -> Data {
        let entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(rels.utf8)),
            ZIPEntry(path: "docProps/app.xml", data: Data(Self.appProperties.utf8)),
            ZIPEntry(path: "docProps/core.xml", data: Data(Self.coreProperties.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheetXML.utf8)),
        ]
        return try ZIPWriter.write(entries: entries)
    }

    // MARK: - Package Relationship Resolution

    func testReadsWorkbookWhenExtendedPropertiesRelationshipComesFirst() throws {
        let workbook = try Workbook(xlsxData: package(rels: Self.excelShapedRels))

        XCTAssertEqual(
            workbook.sheets.map(\.name), ["Model"],
            "The extended-properties relationship type also contains the substring "
                + "\"officeDocument\"; matching on that substring selects docProps/app.xml "
                + "and yields an empty workbook with no error."
        )
    }

    func testReadsCellValuesFromAForeignPackage() throws {
        let workbook = try Workbook(xlsxData: package(rels: Self.excelShapedRels))
        let sheet = try XCTUnwrap(workbook.sheets.first)

        XCTAssertEqual(sheet.cell(at: "A1"), .number(1_950_000))
    }

    func testResolvesAbsoluteRelationshipTargets() throws {
        // OOXML permits a relationship Target to be package-absolute. Naive
        // concatenation onto the workbook's directory turns "/xl/workbook.xml"
        // into "xl//xl/workbook.xml", which matches no part.
        let absoluteTargets = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="/docProps/app.xml"/>\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="/xl/workbook.xml"/>\
            </Relationships>
            """

        let workbook = try Workbook(xlsxData: package(rels: absoluteTargets))
        XCTAssertEqual(workbook.sheets.map(\.name), ["Model"])
    }

    func testWorkbookRelationshipIsFoundRegardlessOfOrdering() throws {
        // The same three relationships with the workbook first, which is the
        // ordering this library's own writer happens to emit.
        let workbookFirst = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>\
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>\
            </Relationships>
            """

        let workbook = try Workbook(xlsxData: package(rels: workbookFirst))
        XCTAssertEqual(workbook.sheets.map(\.name), ["Model"])
    }

    // MARK: - Relationship Target Resolution

    func testResolvePartJoinsRelativeTargets() {
        XCTAssertEqual(
            WorkbookReader.resolvePart("worksheets/sheet1.xml", relativeTo: "xl"),
            "xl/worksheets/sheet1.xml"
        )
    }

    func testResolvePartTreatsLeadingSlashAsPackageRoot() {
        XCTAssertEqual(
            WorkbookReader.resolvePart("/xl/workbook.xml", relativeTo: "xl"),
            "xl/workbook.xml",
            "A package-absolute target discards the base rather than appending to it"
        )
    }

    func testResolvePartCollapsesTraversal() {
        XCTAssertEqual(
            WorkbookReader.resolvePart("../worksheets/sheet1.xml", relativeTo: "xl/charts"),
            "xl/worksheets/sheet1.xml"
        )
        XCTAssertEqual(
            WorkbookReader.resolvePart("./sheet1.xml", relativeTo: "xl/worksheets"),
            "xl/worksheets/sheet1.xml"
        )
    }

    func testResolvePartHandlesAnEmptyBase() {
        XCTAssertEqual(
            WorkbookReader.resolvePart("xl/workbook.xml", relativeTo: ""),
            "xl/workbook.xml"
        )
    }

    func testResolvePartNeverReturnsALeadingSlash() {
        // ZIP entry paths carry no leading slash, so a result with one matches nothing.
        for target in ["/xl/workbook.xml", "/docProps/app.xml", "xl/workbook.xml"] {
            XCTAssertFalse(
                WorkbookReader.resolvePart(target, relativeTo: "").hasPrefix("/"),
                "Resolved \(target) kept a leading slash"
            )
        }
    }

    // MARK: - Shared Formulas

    // Excel writes a repeated formula once, on the group's master cell, as
    // `<f t="shared" ref="B2:B4" si="0">A2*2</f>`. Every other cell in the group
    // carries only `<f t="shared" si="0"/>` with no formula text; its formula is
    // the master's, with relative references shifted by the offset between them.
    // A reader that ignores `t="shared"` sees an empty `<f>`, falls through to the
    // cached `<v>`, and turns a computed cell into a constant without saying so.

    private func sharedFormulaSheet(_ sheetData: String) throws -> Worksheet {
        let sheet = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
            <sheetData>\(sheetData)</sheetData></worksheet>
            """
        let entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.excelShapedRels.utf8)),
            ZIPEntry(path: "docProps/app.xml", data: Data(Self.appProperties.utf8)),
            ZIPEntry(path: "docProps/core.xml", data: Data(Self.coreProperties.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8)),
        ]
        let workbook = try Workbook(xlsxData: ZIPWriter.write(entries: entries))
        return try XCTUnwrap(workbook.sheets.first)
    }

    func testSharedFormulaDependentIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><v>10</v></c></row>\
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        guard case .formula = sheet.cell(at: "B3") else {
            return XCTFail(
                "B3 became \(String(describing: sheet.cell(at: "B3"))). A cell with an <f> "
                    + "element is a formula cell; falling back to its cached value silently "
                    + "turns computation into data."
            )
        }
    }

    func testSharedFormulaDependentTranslatesRelativeReferences() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><v>10</v></c></row>\
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try XCTUnwrap(sheet.cell(at: "B3")?.formulaAST)
        XCTAssertEqual(
            FormulaSerializer.serialize(ast), "A3*2",
            "One row below the master, so the relative A2 shifts to A3"
        )
    }

    func testSharedFormulaMasterKeepsItsOwnFormula() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try XCTUnwrap(sheet.cell(at: "B2")?.formulaAST)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A2*2")
    }

    func testSharedFormulaDoesNotTranslateAbsoluteReferences() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="B2"><f t="shared" ref="B2:B3" si="0">A2*$D$1</f><v>40</v></c></row>\
            <row r="3"><c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try XCTUnwrap(sheet.cell(at: "B3")?.formulaAST)
        XCTAssertEqual(
            FormulaSerializer.serialize(ast), "A3*$D$1",
            "The $ markers are what pin a reference against the shift"
        )
    }

    func testSharedFormulaTranslatesAcrossColumns() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="B2"><f t="shared" ref="B2:D2" si="0">B1+1</f><v>2</v></c>\
            <c r="C2"><f t="shared" si="0"/><v>3</v></c>\
            <c r="D2"><f t="shared" si="0"/><v>4</v></c></row>
            """)

        XCTAssertEqual(
            FormulaSerializer.serialize(try XCTUnwrap(sheet.cell(at: "C2")?.formulaAST)), "C1+1")
        XCTAssertEqual(
            FormulaSerializer.serialize(try XCTUnwrap(sheet.cell(at: "D2")?.formulaAST)), "D1+1")
    }

    func testSharedFormulaTranslatesRanges() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="5"><c r="B5"><f t="shared" ref="B5:C5" si="0">SUM(B1:B4)</f><v>10</v></c>\
            <c r="C5"><f t="shared" si="0"/><v>20</v></c></row>
            """)

        XCTAssertEqual(
            FormulaSerializer.serialize(try XCTUnwrap(sheet.cell(at: "C5")?.formulaAST)),
            "SUM(C1:C4)"
        )
    }

    // MARK: - Data Tables

    // A What-If data table is written as a single self-closing formula element
    // carrying the table's span and its input cells:
    //   <f t="dataTable" ref="P6:T10" dt2D="1" r1="D11" r2="D21"/>
    // It has no formula text either, so it fails the same way a shared-formula
    // member does: fall through to the cached value and the table becomes a
    // grid of unexplained constants.

    func testDataTableCellIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6">\
            <f t="dataTable" ref="P6:T10" dt2D="1" dtr="1" r1="D11" r2="D21" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        guard case .formula = sheet.cell(at: "P6") else {
            return XCTFail("P6 became \(String(describing: sheet.cell(at: "P6")))")
        }
    }

    func testDataTableCellRetainsItsSpanAndInputCells() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6">\
            <f t="dataTable" ref="P6:T10" dt2D="1" dtr="1" r1="D11" r2="D21" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        guard case .function(let name, let args) =
            try XCTUnwrap(sheet.cell(at: "P6")?.formulaAST) else {
            return XCTFail("Expected a marker function")
        }
        XCTAssertEqual(name, "_DATATABLE")
        XCTAssertEqual(args.first, .text("P6:T10"), "The table's span is the recognition signal")
        XCTAssertEqual(args.dropFirst().first, .cellRef(CellRef("D11")))
        XCTAssertEqual(args.dropFirst(2).first, .cellRef(CellRef("D21")))
    }

    func testOneDimensionalDataTableCarriesASingleInput() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6"><f t="dataTable" ref="P6:P10" r1="D11" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        guard case .function(let name, let args) =
            try XCTUnwrap(sheet.cell(at: "P6")?.formulaAST) else {
            return XCTFail("Expected a marker function")
        }
        XCTAssertEqual(name, "_DATATABLE")
        XCTAssertEqual(args.count, 2, "Span plus one input cell")
    }
}
