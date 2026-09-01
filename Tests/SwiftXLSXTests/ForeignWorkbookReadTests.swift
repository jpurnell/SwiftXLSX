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
}
