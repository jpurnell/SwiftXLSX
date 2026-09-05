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

    // MARK: - Array formulas

    // A legacy array formula is entered over a range and stored once: the top-left
    // cell carries the text and a `ref` naming the span, and every other cell in
    // the span carries an empty `<f/>` with its cached value.
    //   <c r="D55"><f t="array" ref="D55:D174">TRANSPOSE(x)</f><v>0</v></c>
    //   <c r="D56"><f ca="1"/><v>-0.5</v></c>
    // The members fail the way a shared-formula member would: fall through to the
    // cached value, and 119 computed cells read as constants.

    func testArrayFormulaAnchorKeepsItsFormula() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>
            """)

        guard case .function(let name, _) =
            try XCTUnwrap(sheet.cell(at: "A1")?.formulaAST) else {
            return XCTFail("A1 became \(String(describing: sheet.cell(at: "A1")))")
        }
        XCTAssertEqual(name, "TRANSPOSE", "the anchor keeps the formula it was written with")
    }

    func testArrayFormulaMemberIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>\
            <row r="3"><c r="A3"><f ca="1"/><v>30</v></c></row>
            """)

        guard case .formula = sheet.cell(at: "A2") else {
            return XCTFail("A2 became \(String(describing: sheet.cell(at: "A2")))")
        }
        guard case .formula = sheet.cell(at: "A3") else {
            return XCTFail("A3 became \(String(describing: sheet.cell(at: "A3")))")
        }
    }

    func testArrayFormulaMemberNamesItsAnchor() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>
            """)

        guard case .function(let name, let args) =
            try XCTUnwrap(sheet.cell(at: "A2")?.formulaAST) else {
            return XCTFail("Expected a marker function")
        }
        XCTAssertEqual(name, "_ARRAY")
        XCTAssertEqual(args.first, .cellRef(CellRef("A1")),
                       "the anchor is the cell this one is computed by")
        XCTAssertEqual(args.dropFirst().first, .text("A1:A3"), "and the span it belongs to")
    }

    func testArrayFormulaMemberKeepsItsCachedValue() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>
            """)

        guard case .formula(_, let cached) = try XCTUnwrap(sheet.cell(at: "A2")) else {
            return XCTFail("expected a formula")
        }
        XCTAssertEqual(cached, .number(20), "the value Excel recorded is the test oracle")
    }

    /// A span across columns, since the members are found by rectangle not by row.
    func testArrayFormulaAcrossARow() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="5"><c r="E5">\
            <f t="array" ref="E5:G5" ca="1">TRANSPOSE(A1:A3)</f><v>1</v></c>\
            <c r="F5"><f ca="1"/><v>2</v></c>\
            <c r="G5"><f ca="1"/><v>3</v></c></row>
            """)

        for ref in ["F5", "G5"] {
            guard case .function(let name, _) =
                try XCTUnwrap(sheet.cell(at: ref)?.formulaAST) else {
                return XCTFail("\(ref) became \(String(describing: sheet.cell(at: ref)))")
            }
            XCTAssertEqual(name, "_ARRAY", "\(ref) is inside the span")
        }
    }

    /// A single-cell array formula owns only itself, so nothing else is claimed.
    func testASingleCellArrayFormulaClaimsNothingElse() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1" ca="1">SUM(B1:D1)</f><v>10</v></c>\
            <c r="B1"><v>5</v></c></row>
            """)

        XCTAssertEqual(sheet.cell(at: "B1"), .number(5), "B1 is a constant and stays one")
    }

    /// An empty `<f/>` outside any span keeps whatever it did before — this change
    /// must not reclassify cells it knows nothing about.
    func testAnEmptyFormulaOutsideAnySpanIsUnchanged() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><f ca="1"/><v>7</v></c></row>
            """)

        XCTAssertNotNil(sheet.cell(at: "A1"), "still read, one way or another")
    }

    // MARK: - Array formulas, written

    // Reading one is only half a round trip. Written back, the anchor must carry
    // `t="array"` and its `ref`, and the members must be empty `<f/>` elements —
    // otherwise the `_ARRAY` marker that makes them computed cells in memory is
    // serialized into the file as if it were a function Excel knows.

    private func roundTripped(_ build: (Worksheet) -> Void) throws -> Worksheet {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        build(sheet)
        let reread = try Workbook(xlsxData: try workbook.save())
        return try XCTUnwrap(reread.sheets.first)
    }

    func testAnArrayFormulaSurvivesARoundTrip() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        }

        guard case .function(let name, _) =
            try XCTUnwrap(sheet.cell(at: "A1")?.formulaAST) else {
            return XCTFail("A1 became \(String(describing: sheet.cell(at: "A1")))")
        }
        XCTAssertEqual(name, "TRANSPOSE", "the anchor keeps its formula")

        for ref in ["A2", "A3"] {
            guard case .function(let marker, let args) =
                try XCTUnwrap(sheet.cell(at: ref)?.formulaAST) else {
                return XCTFail("\(ref) became \(String(describing: sheet.cell(at: ref)))")
            }
            XCTAssertEqual(marker, "_ARRAY", "\(ref) is still a member")
            XCTAssertEqual(args.first, .cellRef(CellRef("A1")))
        }
    }

    /// The marker must never reach the file as a formula.
    ///
    /// `_ARRAY` is an internal mark, not something Excel could evaluate, so writing
    /// it out would produce a workbook Excel opens with `#NAME?` in every member.
    func testTheArrayMarkerIsNeverSerialized() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        let xml = String(decoding: try workbook.save(), as: UTF8.self)

        XCTAssertFalse(xml.contains("_ARRAY"), "the marker leaked into the file")
    }

    func testTheAnchorIsWrittenWithItsSpan() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        let entries = try SwiftZIP.ZIPReader.read(from: try workbook.save())
        let sheetXML = try XCTUnwrap(
            entries.first { $0.path.hasSuffix("sheet1.xml") }.map {
                String(decoding: $0.data, as: UTF8.self)
            })

        XCTAssertTrue(sheetXML.contains("t=\"array\""), "the anchor must say what it is")
        XCTAssertTrue(sheetXML.contains("ref=\"A1:A3\""), "and name the span it fills")
    }

    /// A single-cell array formula is still an array formula.
    func testASingleCellArrayFormulaRoundTrips() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("SUM(B1:D1)", over: CellRange(from: "A1", to: "A1"))
        }
        guard case .function(let name, _) =
            try XCTUnwrap(sheet.cell(at: "A1")?.formulaAST) else {
            return XCTFail("A1 became \(String(describing: sheet.cell(at: "A1")))")
        }
        XCTAssertEqual(name, "SUM")
    }

    /// An ordinary formula is unaffected — no `t="array"` appears where none belongs.
    func testAnOrdinaryFormulaIsNotMarkedAsAnArray() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeFormula("SUM(B1:D1)", to: "A1")
        let xml = String(decoding: try workbook.save(), as: UTF8.self)

        XCTAssertFalse(xml.contains("t=\"array\""))
    }

    // MARK: - Spilling a result

    // Reading and writing an array formula leaves one thing undone: the cells it
    // fills have no values until something evaluates it. `spill(_:over:)` takes an
    // already-evaluated result and writes it across the span, which is what makes
    // a workbook this library produced open with numbers in it rather than blanks.

    func testSpillWritesTheResultAcrossTheSpan() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A3)", over: CellRange(from: "C1", to: "E1"))
        sheet.spill(CellMatrix(row: [.number(10), .number(20), .number(30)]),
                    over: CellRange(from: "C1", to: "E1"))

        for (ref, expected) in [("C1", 10.0), ("D1", 20.0), ("E1", 30.0)] {
            guard case .formula(_, let cached)? = sheet.cell(at: ref) else {
                return XCTFail("\(ref) is not a formula: \(String(describing: sheet.cell(at: ref)))")
            }
            XCTAssertEqual(cached, .number(expected), "\(ref)")
        }
    }

    /// Spilling keeps each cell's formula — the anchor's text, the members' marker.
    func testSpillDoesNotDisturbTheFormulas() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A2)", over: CellRange(from: "C1", to: "D1"))
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "D1"))

        guard case .function(let anchor, _) = try XCTUnwrap(sheet.formulaAST(at: "C1")) else {
            return XCTFail("C1 lost its formula")
        }
        XCTAssertEqual(anchor, "TRANSPOSE")
        guard case .function(let marker, _) = try XCTUnwrap(sheet.formulaAST(at: "D1")) else {
            return XCTFail("D1 lost its marker")
        }
        XCTAssertEqual(marker, "_ARRAY")
    }

    /// A span larger than the result shows `#N/A` where nothing reached.
    func testSpillPadsAShortResult() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A2)", over: CellRange(from: "C1", to: "E1"))
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "E1"))

        guard case .formula(_, let cached)? = sheet.cell(at: "E1") else {
            return XCTFail("E1 is not a formula")
        }
        XCTAssertEqual(cached, .error(.na))
    }

    /// Spilling onto cells that hold no formula writes plain values, so the same
    /// call serves a caller who just wants a block of numbers written.
    func testSpillOntoEmptyCellsWritesValues() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "D1"))

        XCTAssertEqual(sheet.cell(at: "C1"), .number(1))
        XCTAssertEqual(sheet.cell(at: "D1"), .number(2))
    }

    /// And the values survive a save and reload, which is the whole point.
    func testASpilledArrayFormulaRoundTripsWithItsValues() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("TRANSPOSE(A1:A3)", over: CellRange(from: "C1", to: "E1"))
            sheet.spill(CellMatrix(row: [.number(10), .number(20), .number(30)]),
                        over: CellRange(from: "C1", to: "E1"))
        }

        for (ref, expected) in [("C1", 10.0), ("D1", 20.0), ("E1", 30.0)] {
            guard case .formula(_, let cached)? = sheet.cell(at: ref) else {
                return XCTFail("\(ref) came back as \(String(describing: sheet.cell(at: ref)))")
            }
            XCTAssertEqual(cached, .number(expected), "\(ref)")
        }
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
