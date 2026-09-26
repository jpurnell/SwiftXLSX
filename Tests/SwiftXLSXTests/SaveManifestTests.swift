import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// Step 2 of `PROPOSAL_surgical_save.md`: knowing what a save would do, before changing what
/// it does.
///
/// Nothing here alters `save()`. It adds the three things the surgical path needs to be built
/// on — the archive a workbook came from, the cells a caller has touched since, and a manifest
/// saying which parts a save would rewrite, preserve or drop — and asserts they are right on a
/// package shaped like a real one.
///
/// ## Why the owned set is the writer's and not the reader's
///
/// Open question 15.1 hoped the reader could record the paths it consumed so the writer would
/// regenerate exactly those. It cannot: the reader consumes strictly more than the writer
/// emits. It reads `xl/pivotTables/…`, `xl/pivotCache/…` and each sheet's `_rels`, none of
/// which the writer produces. Deriving the owned set from the reader would mark those as
/// rewritten and quietly drop them.
///
/// The writer, though, knows exactly what it emits — it is the same code that builds the
/// archive. So the manifest asks the writer, and adding a part to `save()` puts it in the
/// owned set with nothing to keep in step.
@Suite
struct SaveManifestTests {

    // MARK: - A package with parts this library does not model

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
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>\
        <calcPr calcId="191029"/></workbook>
        """

    private static let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
        </Relationships>
        """

    private static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="A1"><v>2</v></c></row>\
        <row r="2"><c r="B2"><f>A1*3</f><v>6</v></c></row></sheetData>\
        <drawing r:id="rId1"/></worksheet>
        """

    /// The parts a rebuild would throw away: a theme, document properties, a chart and its
    /// drawing, and the calculation chain.
    static let foreign = [
        "docProps/core.xml", "xl/theme/theme1.xml",
        "xl/charts/chart1.xml", "xl/drawings/drawing1.xml",
        "xl/worksheets/_rels/sheet1.xml.rels", "xl/calcChain.xml",
    ]

    private func package() throws -> Data {
        var entries = [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheet.utf8)),
        ]
        for path in Self.foreign {
            entries.append(ZIPEntry(path: path, data: Data("<x/>".utf8)))
        }
        return try ZIPWriter.write(entries: entries)
    }

    private func opened() throws -> Workbook { try Workbook(xlsxData: try package()) }

    // MARK: - Provenance

    @Test("a workbook composed in code has no origin and saves as it always did")
    func composedInCode() throws {
        let workbook = Workbook()
        workbook.addSheet(name: "Sheet1")
        #expect(workbook.defaultSaveStrategy == .generated)
        #expect(throws: SaveError.noOriginArchive) {
            _ = try workbook.saveManifest(strategy: .surgical)
        }
    }

    @Test("a workbook read from an archive remembers it")
    func readFromArchive() throws {
        #expect(try opened().defaultSaveStrategy == .surgical)
    }

    // MARK: - What the caller has touched

    /// **Reading a workbook is not editing it.** The parser fills the sheet through the same
    /// funnel a caller's `write` goes through, so without an explicit switch every cell in
    /// every workbook would arrive already dirty and the splicer would rewrite whole sheets.
    @Test("a freshly read sheet has no changed cells")
    func readingChangesNothing() throws {
        let sheet = try #require(try opened().sheets.first)
        #expect(sheet.changedCells.isEmpty,
                "reading marked \(sheet.changedCells.count) cells as edited")
        #expect(!sheet.hasUnsavedChanges)
    }

    @Test("writing to a read sheet records the cell")
    func writingIsRecorded() throws {
        let workbook = try opened()
        let sheet = try #require(workbook.sheets.first)
        sheet.write(41.0, to: "A1")
        sheet.writeFormula("A1*4", to: "B2")
        #expect(sheet.hasUnsavedChanges)
        #expect(Set(sheet.changedCells.map(\.reference)) == ["A1", "B2"])
    }

    /// Order is kept, and a cell written twice is named once — the splicer replaces a `<c>`,
    /// so a second write to the same cell is not a second edit to apply.
    @Test("the same cell written twice is recorded once")
    func recordsEachCellOnce() throws {
        let sheet = try #require(try opened().sheets.first)
        sheet.write(1.0, to: "A1")
        sheet.write(2.0, to: "A1")
        #expect(sheet.changedCells.map(\.reference) == ["A1"])
    }

    // MARK: - The manifest

    @Test("an unedited workbook would preserve every part it does not own")
    func manifestPreservesForeignParts() throws {
        let manifest = try opened().saveManifest(strategy: .surgical)
        for path in Self.foreign where path != "xl/calcChain.xml" {
            #expect(manifest.preserved.contains(path), "\(path) would not be preserved")
        }
        #expect(!manifest.forcesRecalculation, "nothing was edited")
        #expect(manifest.dropped.isEmpty,
                "the calculation chain is only stale once a formula has moved")
        #expect(manifest.spliced.isEmpty)
    }

    @Test("the parts the writer emits are the ones it would rewrite")
    func manifestNamesTheOwnedParts() throws {
        let manifest = try opened().saveManifest(strategy: .surgical)
        for path in ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml",
                     "xl/_rels/workbook.xml.rels", "xl/styles.xml", "xl/sharedStrings.xml"] {
            #expect(manifest.rewritten.contains(path), "\(path) would not be rewritten")
        }
        #expect(!manifest.rewritten.contains("xl/theme/theme1.xml"),
                "a theme is nothing this library writes")
    }

    /// An edited sheet is spliced rather than rewritten, and naming its cells is what lets a
    /// caller see the blast radius before agreeing to it.
    @Test("an edited sheet is spliced, and the calculation chain goes")
    func manifestAfterAnEdit() throws {
        let workbook = try opened()
        try #require(workbook.sheets.first).writeFormula("A1*4", to: "B2")
        let manifest = try workbook.saveManifest(strategy: .surgical)

        #expect(manifest.forcesRecalculation)
        #expect(manifest.dropped.contains("xl/calcChain.xml"),
                "a stale calculation chain makes Excel repair the file")
        #expect(!manifest.rewritten.contains("xl/worksheets/sheet1.xml"),
                "an edited sheet is spliced, not regenerated — that is the whole proposal")
        let spliced = try #require(manifest.spliced.first)
        #expect(spliced.part == "xl/worksheets/sheet1.xml")
        #expect(spliced.cells.map(\.reference) == ["B2"])
    }

    /// A manifest for the generated strategy tells the truth about what that strategy does:
    /// it preserves nothing.
    @Test("the generated strategy preserves nothing and splices nothing")
    func manifestForGenerated() throws {
        let manifest = try opened().saveManifest(strategy: .generated)
        #expect(manifest.preserved.isEmpty)
        #expect(manifest.spliced.isEmpty)
        #expect(manifest.rewritten.contains("xl/workbook.xml"))
    }

    // MARK: - Nothing saves differently yet

    /// Step 2 is deliberately inert. Asserted so that the step that changes it has to change
    /// this test too, on purpose rather than by accident.
    @Test("save() still rebuilds the archive and still drops foreign parts")
    func saveIsUnchanged() throws {
        let saved = try opened().save()
        let paths = Set(try ZIPReader.read(from: saved).map(\.path))
        #expect(!paths.contains("xl/theme/theme1.xml"),
                "step 3 is what makes this survive; if it passes now, the step landed early")
        #expect(paths.contains("xl/worksheets/sheet1.xml"))
    }
}
