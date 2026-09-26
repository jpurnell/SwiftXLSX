import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// Step 3 of `PROPOSAL_surgical_save.md`: saving a workbook you did not create.
///
/// ## The gate
///
/// **Open a file, save it, change nothing.** Not "lose little" — nothing. Every part that came
/// in goes out, byte for byte, in the order it arrived. Measured over a fifty-workbook corpus
/// sample, today's `save()` drops 57% of all parts and 98% of workbooks lose at least one, so
/// this is the test that turns the proposal from an argument into a fact.
///
/// ## Why preserving is not the same as regenerating carefully
///
/// The parts this library owns are preserved too, not rebuilt, whenever nothing has changed
/// that would make them wrong. `xl/workbook.xml` is the clearest case: regenerating it emits a
/// correct `<sheets>` list and silently drops `<calcPr>`, `<bookViews>` and
/// `<externalReferences>` — the last of which is the table saying what `[2]` means in
/// `'[2]Oil&Gas'!AZ3`, so the formula survives as a reference to nothing.
///
/// It also fixes the chartsheet defect for free. A chart tab is a `<sheet>` entry pointing at
/// `xl/chartsheets/sheetN.xml`; the reader cannot parse that part, so the sheet arrives empty
/// and the writer emitted it as `xl/worksheets/sheetN.xml` — a blank grid where a chart was,
/// with every part number after it shifted by one. Preserving the original parts and the
/// original `workbook.xml` leaves it alone.
@Suite
struct SurgicalSaveTests {

    // MARK: - A package with a chart, a chartsheet, an external link and a theme

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        <Override PartName="/xl/chartsheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.chartsheet+xml"/>\
        </Types>
        """

    private static let packageRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """

    /// Two sheets, the first a chart tab; a calculation chain; an external reference table; a
    /// `<calcPr>`. Everything a rebuild throws away.
    private static let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <bookViews><workbookView xWindow="0" yWindow="0"/></bookViews>\
        <sheets><sheet name="Subs Chart" sheetId="1" r:id="rId3"/>\
        <sheet name="Data" sheetId="2" r:id="rId1"/></sheets>\
        <externalReferences><externalReference r:id="rId4"/></externalReferences>\
        <calcPr calcId="191029"/></workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chartsheet" Target="chartsheets/sheet1.xml"/>\
        <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink" Target="externalLinks/externalLink1.xml"/>\
        <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
        </Relationships>
        """

    /// The `<drawing>` anchor is the point of §2.1: preserve the chart part and regenerate the
    /// sheet, and the chart survives in the archive with nothing pointing at it.
    private static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetData><row r="1"><c r="A1"><v>2</v></c></row>\
        <row r="2"><c r="B2"><f>A1*3</f><v>6</v></c></row></sheetData>\
        <conditionalFormatting sqref="A1:A9"><cfRule type="top10" priority="1" rank="3"/>\
        </conditionalFormatting><drawing r:id="rId1"/></worksheet>
        """

    /// Every part the library does not model, plus the two it does but must not rebuild.
    static let mustSurvive = [
        "docProps/core.xml", "docProps/app.xml", "xl/theme/theme1.xml",
        "xl/charts/chart1.xml", "xl/drawings/drawing1.xml",
        "xl/chartsheets/sheet1.xml", "xl/chartsheets/_rels/sheet1.xml.rels",
        "xl/externalLinks/externalLink1.xml",
        "xl/worksheets/_rels/sheet1.xml.rels", "xl/styles.xml",
    ]

    private static func entries() -> [ZIPEntry] {
        var entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8)),
            ZIPEntry(path: "xl/calcChain.xml", data: Data("<calcChain/>".utf8)),
        ]
        for path in mustSurvive {
            entries.append(ZIPEntry(path: path, data: Data("<part path=\"\(path)\"/>".utf8)))
        }
        return entries
    }

    private func package() throws -> Data { try ZIPWriter.write(entries: Self.entries()) }
    private func opened() throws -> Workbook { try Workbook(xlsxData: try package()) }

    private func parts(_ data: Data) throws -> [String: Data] {
        Dictionary(uniqueKeysWithValues: try ZIPReader.read(from: data).map { ($0.path, $0.data) })
    }

    /// The bytes the fixture puts in each foreign part, so a test can assert the content came
    /// through rather than merely that something did.
    private static func body(of path: String) -> Data {
        Data("<part path=\"\(path)\"/>".utf8)
    }

    // MARK: - The gate

    /// **Open and save, and the archive is the one that came in.**
    @Test("a workbook saved without edits is unchanged, part for part")
    func noEditFidelity() throws {
        let before = try parts(try package())
        let after = try parts(try opened().save())

        let lost = Set(before.keys).subtracting(after.keys).sorted()
        let gained = Set(after.keys).subtracting(before.keys).sorted()
        #expect(Set(after.keys) == Set(before.keys), "lost \(lost), gained \(gained)")
        for (path, data) in before {
            #expect(after[path] == data, "\(path) was rewritten")
        }
    }

    @Test("the parts arrive in the order they were stored in")
    func keepsEntryOrder() throws {
        let before = try ZIPReader.read(from: try package()).map(\.path)
        let after = try ZIPReader.read(from: try opened().save()).map(\.path)
        #expect(after == before)
    }

    /// A chart tab stays a chart tab. It used to come back as `xl/worksheets/sheet2.xml` — a
    /// blank grid — which also shifted every part number after it.
    @Test("a chartsheet is still a chartsheet")
    func chartsheetSurvives() throws {
        let after = try parts(try opened().save())
        #expect(after["xl/chartsheets/sheet1.xml"] == Self.body(of: "xl/chartsheets/sheet1.xml"))
        #expect(!after.keys.contains("xl/worksheets/sheet2.xml"),
                "the chart tab was rewritten as a worksheet")
    }

    /// The table that says what `[1]` means in a formula. Without it the formula text survives
    /// and refers to nothing.
    @Test("the external reference table and its link part survive")
    func externalReferencesSurvive() throws {
        let after = try parts(try opened().save())
        let workbook = String(decoding: try #require(after["xl/workbook.xml"]), as: UTF8.self)
        #expect(workbook.contains("<externalReferences>"))
        #expect(workbook.contains("<calcPr"))
        #expect(workbook.contains("<bookViews>"))
        #expect(after["xl/externalLinks/externalLink1.xml"]
                    == Self.body(of: "xl/externalLinks/externalLink1.xml"))
    }

    // MARK: - With an edit

    /// The worksheet, as opposed to the chart tab that sits in front of it.
    private func dataSheet(of workbook: Workbook) throws -> Worksheet {
        try #require(workbook.sheets.first { $0.originPart?.hasPrefix("xl/worksheets/") == true })
    }

    /// Editing one cell must not cost the other thirty parts.
    @Test("an edit preserves everything it did not touch")
    func editPreservesTheRest() throws {
        let workbook = try opened()
        try dataSheet(of: workbook).write(99.0, to: "A1")
        let after = try parts(try workbook.save())
        for path in Self.mustSurvive where path != "xl/styles.xml" {
            #expect(after[path] == Self.body(of: path),
                    "\(path) did not survive an edit to one cell unchanged")
        }
        // The styles table is the one owned part an edit does rewrite, because a regenerated
        // sheet writes fresh style indices into it. Step 4's splice touches neither table.
        #expect(after.keys.contains("xl/styles.xml"))
    }

    /// A stale calculation chain makes Excel repair the file, and it is a regenerable cache.
    @Test("an edit drops the calculation chain, and no edit keeps it")
    func dropsTheCalculationChain() throws {
        let unedited = try parts(try opened().save())
        #expect(unedited["xl/calcChain.xml"] == Data("<calcChain/>".utf8), "nothing was edited")

        let workbook = try opened()
        try dataSheet(of: workbook).write(99.0, to: "A1")
        let edited = try parts(try workbook.save())
        #expect(!edited.keys.contains("xl/calcChain.xml"))
        let types = String(decoding: try #require(edited["[Content_Types].xml"]), as: UTF8.self)
        #expect(!types.contains("calcChain"),
                "a declared part that is not in the archive makes Excel repair the file")
    }

    // MARK: - Refusing what it cannot do

    /// Adding a sheet moves part paths that preserved relationships and unspliced sheets still
    /// point at. §13 chose to refuse rather than guess.
    @Test("adding a sheet to a workbook that was read is refused")
    func structuralChangeIsRefused() throws {
        let workbook = try opened()
        workbook.addSheet(name: "Extra")
        #expect(throws: SaveError.self) { _ = try workbook.save() }
    }

    /// **A chart tab is not a worksheet, even though the reader hands one over as if it were.**
    ///
    /// It is a `<sheet>` entry pointing at `xl/chartsheets/sheetN.xml`, and nothing here parses
    /// that part — so it arrives as an empty worksheet, and in the corpus workbook this was
    /// found in it arrives *first*, which is what `sheets.first` reaches for. Writing worksheet
    /// XML over that part would put a blank grid where a chart was, so it is refused.
    @Test("editing a chart tab is refused rather than turning it into a blank grid")
    func editingAChartsheetIsRefused() throws {
        let workbook = try opened()
        let chartTab = try #require(
            workbook.sheets.first { $0.originPart == "xl/chartsheets/sheet1.xml" })
        chartTab.write(1.0, to: "A1")
        #expect(throws: SaveError.spliceFailed(
            part: "xl/chartsheets/sheet1.xml",
            reason: "'Subs Chart' is not a worksheet — this library can read its cells but "
                + "cannot write the part back")) {
            _ = try workbook.save()
        }
    }

    /// The old behaviour stays reachable on purpose, for a caller who wants a clean rebuild.
    @Test("the generated strategy still rebuilds from the model")
    func generatedStrategyStillRebuilds() throws {
        let after = try parts(try opened().save(strategy: .generated))
        #expect(!after.keys.contains("xl/theme/theme1.xml"), "that is what .generated means")
        #expect(Set(after.keys) == Set(try ZIPReader.read(from: try opened()
            .save(strategy: .generated)).map(\.path)))
        #expect(after.keys.contains("xl/worksheets/sheet1.xml"))
    }

    /// A workbook composed in code has no origin, so nothing above applies to it.
    @Test("a workbook composed in code saves exactly as it always did")
    func composedInCodeIsUnaffected() throws {
        let workbook = Workbook()
        workbook.addSheet(name: "Sheet1").write(1.0, to: "A1")
        let after = try parts(try workbook.save())
        #expect(after.keys.contains("xl/worksheets/sheet1.xml"))
        #expect(after.keys.contains("xl/workbook.xml"))
        let sheet = String(decoding: try #require(after["xl/worksheets/sheet1.xml"]),
                           as: UTF8.self)
        #expect(sheet.contains("<c r=\"A1\""), "the cell it was given is in it")
    }
}
