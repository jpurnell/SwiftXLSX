import Testing
import Foundation
@testable import SwiftXLSX
import SwiftZIP

/// Reading `.xlsx` packages this library did **not** write.
///
/// Every other reader test round-trips through ``Workbook/save()``, so they only
/// ever exercise the narrow package shape this library emits. Excel's packages
/// differ in ways that are legal OOXML, and those differences are what break in
/// the field. These tests assemble packages by hand to cover that gap.
@Suite
struct ForeignWorkbookReadTests {

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

    @Test("Reads workbook when extended properties relationship comes first")
    func testReadsWorkbookWhenExtendedPropertiesRelationshipComesFirst() throws {
        let workbook = try Workbook(xlsxData: package(rels: Self.excelShapedRels))

        #expect(workbook.sheets.map(\.name) == ["Model"], "The extended-properties relationship type also contains the substring \"officeDocument\"; matching on that substring selects docProps/app.xml and yields an empty workbook with no error.")
    }

    @Test("Reads cell values from A foreign package")
    func testReadsCellValuesFromAForeignPackage() throws {
        let workbook = try Workbook(xlsxData: package(rels: Self.excelShapedRels))
        let sheet = try #require(workbook.sheets.first)

        #expect(sheet.cell(at: "A1") == .number(1_950_000))
    }

    @Test("Resolves absolute relationship targets")
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
        #expect(workbook.sheets.map(\.name) == ["Model"])
    }

    @Test("Workbook relationship is found regardless of ordering")
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
        #expect(workbook.sheets.map(\.name) == ["Model"])
    }

    // MARK: - Relationship Target Resolution

    @Test("Resolve part joins relative targets")
    func testResolvePartJoinsRelativeTargets() {
        #expect(WorkbookReader.resolvePart("worksheets/sheet1.xml", relativeTo: "xl") == "xl/worksheets/sheet1.xml")
    }

    @Test("Resolve part treats leading slash as package root")
    func testResolvePartTreatsLeadingSlashAsPackageRoot() {
        #expect(WorkbookReader.resolvePart("/xl/workbook.xml", relativeTo: "xl") == "xl/workbook.xml", "A package-absolute target discards the base rather than appending to it")
    }

    @Test("Resolve part collapses traversal")
    func testResolvePartCollapsesTraversal() {
        #expect(WorkbookReader.resolvePart("../worksheets/sheet1.xml", relativeTo: "xl/charts") == "xl/worksheets/sheet1.xml")
        #expect(WorkbookReader.resolvePart("./sheet1.xml", relativeTo: "xl/worksheets") == "xl/worksheets/sheet1.xml")
    }

    @Test("Resolve part handles an empty base")
    func testResolvePartHandlesAnEmptyBase() {
        #expect(WorkbookReader.resolvePart("xl/workbook.xml", relativeTo: "") == "xl/workbook.xml")
    }

    @Test("Resolve part never returns A leading slash")
    func testResolvePartNeverReturnsALeadingSlash() {
        // ZIP entry paths carry no leading slash, so a result with one matches nothing.
        for target in ["/xl/workbook.xml", "/docProps/app.xml", "xl/workbook.xml"] {
            #expect(!(WorkbookReader.resolvePart(target, relativeTo: "").hasPrefix("/")), "Resolved \(target) kept a leading slash")
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
        return try #require(workbook.sheets.first)
    }

    @Test("Shared formula dependent is A formula not A constant")
    func testSharedFormulaDependentIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><v>10</v></c></row>\
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let b3 = try #require(sheet.cell(at: "B3"))
        guard case .formula(_, let cached) = b3 else {
            Issue.record("B3 became \(b3). A cell with an <f> element is a formula cell; falling back to its cached value silently turns computation into data.")
            return
        }
        #expect(cached == .number(60), "and it keeps the value Excel cached for it")
    }

    @Test("Shared formula dependent translates relative references")
    func testSharedFormulaDependentTranslatesRelativeReferences() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><v>10</v></c></row>\
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try #require(sheet.cell(at: "B3")?.formulaAST)
        #expect(FormulaSerializer.serialize(ast) == "A3*2", "One row below the master, so the relative A2 shifts to A3")
    }

    @Test("Shared formula master keeps its own formula")
    func testSharedFormulaMasterKeepsItsOwnFormula() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="A2"><v>20</v></c>\
            <c r="B2"><f t="shared" ref="B2:B3" si="0">A2*2</f><v>40</v></c></row>\
            <row r="3"><c r="A3"><v>30</v></c>\
            <c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try #require(sheet.cell(at: "B2")?.formulaAST)
        #expect(FormulaSerializer.serialize(ast) == "A2*2")
    }

    @Test("Shared formula does not translate absolute references")
    func testSharedFormulaDoesNotTranslateAbsoluteReferences() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="B2"><f t="shared" ref="B2:B3" si="0">A2*$D$1</f><v>40</v></c></row>\
            <row r="3"><c r="B3"><f t="shared" si="0"/><v>60</v></c></row>
            """)

        let ast = try #require(sheet.cell(at: "B3")?.formulaAST)
        #expect(FormulaSerializer.serialize(ast) == "A3*$D$1", "The $ markers are what pin a reference against the shift")
    }

    @Test("Shared formula translates across columns")
    func testSharedFormulaTranslatesAcrossColumns() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="2"><c r="B2"><f t="shared" ref="B2:D2" si="0">B1+1</f><v>2</v></c>\
            <c r="C2"><f t="shared" si="0"/><v>3</v></c>\
            <c r="D2"><f t="shared" si="0"/><v>4</v></c></row>
            """)

        #expect(FormulaSerializer.serialize(try #require(sheet.cell(at: "C2")?.formulaAST)) == "C1+1")
        #expect(FormulaSerializer.serialize(try #require(sheet.cell(at: "D2")?.formulaAST)) == "D1+1")
    }

    @Test("Shared formula translates ranges")
    func testSharedFormulaTranslatesRanges() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="5"><c r="B5"><f t="shared" ref="B5:C5" si="0">SUM(B1:B4)</f><v>10</v></c>\
            <c r="C5"><f t="shared" si="0"/><v>20</v></c></row>
            """)

        #expect(FormulaSerializer.serialize(try #require(sheet.cell(at: "C5")?.formulaAST)) == "SUM(C1:C4)")
    }

    // MARK: - Array formulas

    // A legacy array formula is entered over a range and stored once: the top-left
    // cell carries the text and a `ref` naming the span, and every other cell in
    // the span carries an empty `<f/>` with its cached value.
    //   <c r="D55"><f t="array" ref="D55:D174">TRANSPOSE(x)</f><v>0</v></c>
    //   <c r="D56"><f ca="1"/><v>-0.5</v></c>
    // The members fail the way a shared-formula member would: fall through to the
    // cached value, and 119 computed cells read as constants.

    @Test("Array formula anchor keeps its formula")
    func testArrayFormulaAnchorKeepsItsFormula() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>
            """)

        guard case .function(let name, _) =
            try #require(sheet.cell(at: "A1")?.formulaAST) else {
            Issue.record("A1 became \(String(describing: sheet.cell(at: "A1")))")
            return
        }
        #expect(name == "TRANSPOSE", "the anchor keeps the formula it was written with")
    }

    @Test("Array formula member is A formula not A constant")
    func testArrayFormulaMemberIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>\
            <row r="3"><c r="A3"><f ca="1"/><v>30</v></c></row>
            """)

        for (ref, expected) in [("A2", 20.0), ("A3", 30.0)] {
            let cell = try #require(sheet.cell(at: ref))
            guard case .formula(_, let cached) = cell else {
                Issue.record("\(ref) became \(cell)")
                return
            }
            #expect(cached == .number(expected), "\(ref) keeps the value Excel cached for it")
        }
    }

    @Test("Array formula member names its anchor")
    func testArrayFormulaMemberNamesItsAnchor() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>
            """)

        guard case .function(let name, let args) =
            try #require(sheet.cell(at: "A2")?.formulaAST) else {
            Issue.record("Expected a marker function")
            return
        }
        #expect(name == "_ARRAY")
        #expect(args.first == .cellRef(CellRef("A1")), "the anchor is the cell this one is computed by")
        #expect(args.dropFirst().first == .text("A1:A3"), "and the span it belongs to")
    }

    @Test("Array formula member keeps its cached value")
    func testArrayFormulaMemberKeepsItsCachedValue() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1:A3" ca="1">TRANSPOSE(B1:D1)</f><v>10</v></c></row>\
            <row r="2"><c r="A2"><f ca="1"/><v>20</v></c></row>
            """)

        guard case .formula(_, let cached) = try #require(sheet.cell(at: "A2")) else {
            Issue.record("expected a formula")
            return
        }
        #expect(cached == .number(20), "the value Excel recorded is the test oracle")
    }

    /// A span across columns, since the members are found by rectangle not by row.
    @Test("Array formula across A row")
    func testArrayFormulaAcrossARow() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="5"><c r="E5">\
            <f t="array" ref="E5:G5" ca="1">TRANSPOSE(A1:A3)</f><v>1</v></c>\
            <c r="F5"><f ca="1"/><v>2</v></c>\
            <c r="G5"><f ca="1"/><v>3</v></c></row>
            """)

        for ref in ["F5", "G5"] {
            guard case .function(let name, _) =
                try #require(sheet.cell(at: ref)?.formulaAST) else {
                Issue.record("\(ref) became \(String(describing: sheet.cell(at: ref)))")
                return
            }
            #expect(name == "_ARRAY", "\(ref) is inside the span")
        }
    }

    /// A single-cell array formula owns only itself, so nothing else is claimed.
    @Test("A single cell array formula claims nothing else")
    func testASingleCellArrayFormulaClaimsNothingElse() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1">\
            <f t="array" ref="A1" ca="1">SUM(B1:D1)</f><v>10</v></c>\
            <c r="B1"><v>5</v></c></row>
            """)

        #expect(sheet.cell(at: "B1") == .number(5), "B1 is a constant and stays one")
    }

    /// An empty `<f/>` outside any span keeps whatever it did before — this change
    /// must not reclassify cells it knows nothing about.
    @Test("An empty formula outside any span is unchanged")
    func testAnEmptyFormulaOutsideAnySpanIsUnchanged() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="1"><c r="A1"><f ca="1"/><v>7</v></c></row>
            """)

        #expect(sheet.cell(at: "A1") == .number(7), "still read, one way or another — with no span to belong to, the cached value is all there is")
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
        return try #require(reread.sheets.first)
    }

    @Test("An array formula survives A round trip")
    func testAnArrayFormulaSurvivesARoundTrip() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        }

        guard case .function(let name, _) =
            try #require(sheet.cell(at: "A1")?.formulaAST) else {
            Issue.record("A1 became \(String(describing: sheet.cell(at: "A1")))")
            return
        }
        #expect(name == "TRANSPOSE", "the anchor keeps its formula")

        for ref in ["A2", "A3"] {
            guard case .function(let marker, let args) =
                try #require(sheet.cell(at: ref)?.formulaAST) else {
                Issue.record("\(ref) became \(String(describing: sheet.cell(at: ref)))")
                return
            }
            #expect(marker == "_ARRAY", "\(ref) is still a member")
            #expect(args.first == .cellRef(CellRef("A1")))
        }
    }

    /// The marker must never reach the file as a formula.
    ///
    /// `_ARRAY` is an internal mark, not something Excel could evaluate, so writing
    /// it out would produce a workbook Excel opens with `#NAME?` in every member.
    @Test("The array marker is never serialized")
    func testTheArrayMarkerIsNeverSerialized() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        let xml = String(decoding: try workbook.save(), as: UTF8.self)

        #expect(!(xml.contains("_ARRAY")), "the marker leaked into the file")
    }

    @Test("The anchor is written with its span")
    func testTheAnchorIsWrittenWithItsSpan() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
        let entries = try SwiftZIP.ZIPReader.read(from: try workbook.save())
        let sheetXML = try #require(
            entries.first { $0.path.hasSuffix("sheet1.xml") }.map {
                String(decoding: $0.data, as: UTF8.self)
            })

        #expect(sheetXML.contains("t=\"array\""), "the anchor must say what it is")
        #expect(sheetXML.contains("ref=\"A1:A3\""), "and name the span it fills")
    }

    /// A single-cell array formula is still an array formula.
    @Test("A single cell array formula round trips")
    func testASingleCellArrayFormulaRoundTrips() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("SUM(B1:D1)", over: CellRange(from: "A1", to: "A1"))
        }
        guard case .function(let name, _) =
            try #require(sheet.cell(at: "A1")?.formulaAST) else {
            Issue.record("A1 became \(String(describing: sheet.cell(at: "A1")))")
            return
        }
        #expect(name == "SUM")
    }

    /// An ordinary formula is unaffected — no `t="array"` appears where none belongs.
    @Test("An ordinary formula is not marked as an array")
    func testAnOrdinaryFormulaIsNotMarkedAsAnArray() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeFormula("SUM(B1:D1)", to: "A1")
        let xml = String(decoding: try workbook.save(), as: UTF8.self)

        #expect(!(xml.contains("t=\"array\"")))
    }

    // MARK: - Spilling a result

    // Reading and writing an array formula leaves one thing undone: the cells it
    // fills have no values until something evaluates it. `spill(_:over:)` takes an
    // already-evaluated result and writes it across the span, which is what makes
    // a workbook this library produced open with numbers in it rather than blanks.

    @Test("Spill writes the result across the span")
    func testSpillWritesTheResultAcrossTheSpan() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A3)", over: CellRange(from: "C1", to: "E1"))
        sheet.spill(CellMatrix(row: [.number(10), .number(20), .number(30)]),
                    over: CellRange(from: "C1", to: "E1"))

        for (ref, expected) in [("C1", 10.0), ("D1", 20.0), ("E1", 30.0)] {
            guard case .formula(_, let cached)? = sheet.cell(at: ref) else {
                Issue.record("\(ref) is not a formula: \(String(describing: sheet.cell(at: ref)))")
                return
            }
            #expect(cached == .number(expected), "\(ref)")
        }
    }

    /// Spilling keeps each cell's formula — the anchor's text, the members' marker.
    @Test("Spill does not disturb the formulas")
    func testSpillDoesNotDisturbTheFormulas() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A2)", over: CellRange(from: "C1", to: "D1"))
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "D1"))

        guard case .function(let anchor, _) = try #require(sheet.formulaAST(at: "C1")) else {
            Issue.record("C1 lost its formula")
            return
        }
        #expect(anchor == "TRANSPOSE")
        guard case .function(let marker, _) = try #require(sheet.formulaAST(at: "D1")) else {
            Issue.record("D1 lost its marker")
            return
        }
        #expect(marker == "_ARRAY")
    }

    /// A span larger than the result shows `#N/A` where nothing reached.
    @Test("Spill pads A short result")
    func testSpillPadsAShortResult() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A2)", over: CellRange(from: "C1", to: "E1"))
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "E1"))

        guard case .formula(_, let cached)? = sheet.cell(at: "E1") else {
            Issue.record("E1 is not a formula")
            return
        }
        #expect(cached == .error(.na))
    }

    /// Spilling onto cells that hold no formula writes plain values, so the same
    /// call serves a caller who just wants a block of numbers written.
    @Test("Spill onto empty cells writes values")
    func testSpillOntoEmptyCellsWritesValues() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.spill(CellMatrix(row: [.number(1), .number(2)]),
                    over: CellRange(from: "C1", to: "D1"))

        #expect(sheet.cell(at: "C1") == .number(1))
        #expect(sheet.cell(at: "D1") == .number(2))
    }

    /// And the values survive a save and reload, which is the whole point.
    @Test("A spilled array formula round trips with its values")
    func testASpilledArrayFormulaRoundTripsWithItsValues() throws {
        let sheet = try roundTripped { sheet in
            sheet.writeArrayFormula("TRANSPOSE(A1:A3)", over: CellRange(from: "C1", to: "E1"))
            sheet.spill(CellMatrix(row: [.number(10), .number(20), .number(30)]),
                        over: CellRange(from: "C1", to: "E1"))
        }

        for (ref, expected) in [("C1", 10.0), ("D1", 20.0), ("E1", 30.0)] {
            guard case .formula(_, let cached)? = sheet.cell(at: ref) else {
                Issue.record("\(ref) came back as \(String(describing: sheet.cell(at: ref)))")
                return
            }
            #expect(cached == .number(expected), "\(ref)")
        }
    }

    /// `apply` is the shape an evaluator's output arrives in.
    @Test("Apply writes values into their cells")
    func testApplyWritesValuesIntoTheirCells() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.writeArrayFormula("TRANSPOSE(A1:A2)", over: CellRange(from: "C1", to: "D1"))
        sheet.apply([CellRef("C1"): .number(1), CellRef("D1"): .number(2)])

        guard case .formula(_, let cached)? = sheet.cell(at: "C1") else {
            Issue.record("C1 stopped being a formula")
            return
        }
        #expect(cached == .number(1))
    }

    @Test("Apply onto empty cells writes values")
    func testApplyOntoEmptyCellsWritesValues() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.apply([CellRef("C1"): .text("hello")])
        #expect(sheet.cell(at: "C1") == .text("hello"))
    }

    /// A formula whose result is an error keeps that result through a save.
    ///
    /// It did not: only numbers and text were written back, so `#N/A` returned as a
    /// formula with no value at all — and a mis-sized array formula lost the only
    /// evidence that it was mis-sized.
    @Test("A cached error survives A round trip")
    func testACachedErrorSurvivesARoundTrip() throws {
        let sheet = try roundTripped { sheet in
            sheet.setCell("A1", value: .formula(.function("NA", []), cached: .error(.na)),
                          style: .general)
        }
        guard case .formula(_, let cached)? = sheet.cell(at: "A1") else {
            Issue.record("A1 came back as \(String(describing: sheet.cell(at: "A1")))")
            return
        }
        #expect(cached == .error(.na))
    }

    @Test("A cached boolean survives A round trip")
    func testACachedBooleanSurvivesARoundTrip() throws {
        let sheet = try roundTripped { sheet in
            sheet.setCell("A1", value: .formula(.function("TRUE", []), cached: .bool(true)),
                          style: .general)
        }
        guard case .formula(_, let cached)? = sheet.cell(at: "A1") else {
            Issue.record("A1 came back as \(String(describing: sheet.cell(at: "A1")))")
            return
        }
        #expect(cached == .bool(true))
    }

    // MARK: - Absolute references

    // `$D$66` and `D66` name the same cell. `CellRef.reference` renders the markers,
    // and the cell store is keyed by the plain reference the file uses, so keying a
    // lookup on the rendered form misses every absolute reference — silently, as an
    // empty cell rather than an error.
    //
    // Found by comparing a corpus workbook against Excel's own cached values: every
    // `=D22/$D$66` answered `#DIV/0!` because the divisor came back nil.

    @Test("An absolute reference finds the cell")
    func testAnAbsoluteReferenceFindsTheCell() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(42, to: "D66")

        #expect(sheet.value(at: CellRef("D66")) == .number(42))
        #expect(sheet.value(at: CellRef("$D$66")) == .number(42), "absolute names the same cell")
        #expect(sheet.value(at: CellRef("$D66")) == .number(42), "mixed, column absolute")
        #expect(sheet.value(at: CellRef("D$66")) == .number(42), "mixed, row absolute")
    }

    @Test("An absolute reference reads through the provider")
    func testAnAbsoluteReferenceReadsThroughTheProvider() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(10, to: "D66")
        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")

        #expect(provider.value(at: CellRef("$D$66")) == .number(10))
        #expect(provider.value(at: CellRef("$D$66"), inSheet: "Sheet1") == .number(10))
    }

    /// A matrix read is derived from `value(at:)`, so it inherits the same fix.
    @Test("An absolute range reads its cells")
    func testAnAbsoluteRangeReadsItsCells() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(1, to: "A1")
        sheet.write(2, to: "A2")
        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")

        let matrix = provider.matrix(in: CellRange(from: CellRef("$A$1"), to: CellRef("$A$2")))
        #expect(matrix.elements == [.number(1), .number(2)])
    }

    /// Writing through an absolute reference lands on the same cell too, or a
    /// spilled result would be stored where nothing can read it.
    @Test("Applying to an absolute reference hits the same cell")
    func testApplyingToAnAbsoluteReferenceHitsTheSameCell() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(1, to: "B2")
        sheet.apply([CellRef("$B$2"): .number(99)])

        #expect(sheet.value(at: CellRef("B2")) == .number(99))
        #expect(sheet.cellReferences.filter { $0.contains("B2") }.count == 1, "one cell, not a second under a marked key")
    }

    // Normalising the *storage key* must not normalise the *references*. A cell has
    // no absoluteness — `$D$66` and `D66` are the same cell — but a reference does,
    // and `$` is what decides whether it moves when the formula is copied. Losing
    // the markers would silently change what every copied formula means.

    @Test("Absolute markers survive A round trip")
    func testAbsoluteMarkersSurviveARoundTrip() throws {
        let sheet = try roundTripped { sheet in
            sheet.write(5, to: "D66")
            sheet.writeFormula("$D$66*2", to: "A1")
            sheet.writeFormula("$D66+D$66", to: "A2")
        }

        #expect(FormulaSerializer.serialize(try #require(sheet.formulaAST(at: "A1"))) == "$D$66*2", "a fully absolute reference keeps both markers")
        #expect(FormulaSerializer.serialize(try #require(sheet.formulaAST(at: "A2"))) == "$D66+D$66", "mixed references keep the marker they had")
    }

    /// And the cell element itself is written unmarked, which is what Excel does.
    @Test("A cell is written with A plain reference")
    func testACellIsWrittenWithAPlainReference() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.apply([CellRef("$D$66"): .number(5)])
        let entries = try SwiftZIP.ZIPReader.read(from: try workbook.save())
        let xml = try #require(
            entries.first { $0.path.hasSuffix("sheet1.xml") }.map {
                String(decoding: $0.data, as: UTF8.self)
            })

        #expect(xml.contains("<c r=\"D66\""), "the cell is at D66")
        #expect(!(xml.contains("r=\"$D$66\"")), "a cell reference carries no markers")
    }

    /// The two together: a marked reference reads the cell, and still writes marked.
    @Test("An absolute reference both resolves and serialises")
    func testAnAbsoluteReferenceBothResolvesAndSerialises() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(7, to: "D66")
        sheet.writeFormula("$D$66", to: "A1")

        let provider = WorkbookValueProvider(workbook: workbook, currentSheet: "Sheet1")
        #expect(provider.value(at: CellRef("$D$66")) == .number(7), "it finds the cell")
        #expect(FormulaSerializer.serialize(try #require(sheet.formulaAST(at: "A1"))) == "$D$66", "and still says $D$66")
    }

    // MARK: - Data Tables

    // A What-If data table is written as a single self-closing formula element
    // carrying the table's span and its input cells:
    //   <f t="dataTable" ref="P6:T10" dt2D="1" r1="D11" r2="D21"/>
    // It has no formula text either, so it fails the same way a shared-formula
    // member does: fall through to the cached value and the table becomes a
    // grid of unexplained constants.

    @Test("Data table cell is A formula not A constant")
    func testDataTableCellIsAFormulaNotAConstant() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6">\
            <f t="dataTable" ref="P6:T10" dt2D="1" dtr="1" r1="D11" r2="D21" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        let p6 = try #require(sheet.cell(at: "P6"))
        guard case .formula(_, let cached) = p6 else {
            Issue.record("P6 became \(p6)")
            return
        }
        #expect(cached == .number(0.25), "and it keeps the value Excel cached for it")
    }

    @Test("Data table cell retains its span and input cells")
    func testDataTableCellRetainsItsSpanAndInputCells() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6">\
            <f t="dataTable" ref="P6:T10" dt2D="1" dtr="1" r1="D11" r2="D21" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        guard case .function(let name, let args) =
            try #require(sheet.cell(at: "P6")?.formulaAST) else {
            Issue.record("Expected a marker function")
            return
        }
        #expect(name == "_DATATABLE")
        #expect(args.first == .text("P6:T10"), "The table's span is the recognition signal")
        #expect(args.dropFirst().first == .cellRef(CellRef("D11")))
        #expect(args.dropFirst(2).first == .cellRef(CellRef("D21")))
    }

    @Test("One dimensional data table carries A single input")
    func testOneDimensionalDataTableCarriesASingleInput() throws {
        let sheet = try sharedFormulaSheet("""
            <row r="6"><c r="P6"><f t="dataTable" ref="P6:P10" r1="D11" ca="1"/>\
            <v>0.25</v></c></row>
            """)

        guard case .function(let name, let args) =
            try #require(sheet.cell(at: "P6")?.formulaAST) else {
            Issue.record("Expected a marker function")
            return
        }
        #expect(name == "_DATATABLE")
        #expect(args.count == 2, "Span plus one input cell")
    }
}
