import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// Step 4 of `PROPOSAL_surgical_save.md`: editing a sheet instead of regenerating it.
///
/// Step 3 stopped an edit costing the whole workbook. It still costs the sheet: the one sheet a
/// caller touched is rebuilt from the in-memory model, so its conditional formatting, its
/// hyperlinks, its page setup and — worst — its `<drawing>` anchor go, and the chart that
/// anchor points at becomes an orphan in an archive that still opens.
///
/// So a changed sheet is **edited**: find the `<c>` elements whose cells changed, replace those,
/// and leave every other byte where it was. The fidelity of the change is bounded by the cells
/// the caller actually touched, which is a far smaller thing to get right than "reproduce an
/// arbitrary worksheet".
///
/// ## Where the splicer lives
///
/// Open question 15.2 offered two homes: a separate splicer, or extending the reader into a
/// rewriter that retains source offsets. The second is faithful by construction and the first
/// is testable in isolation — and this is a correctness feature whose whole claim is "it
/// changed nothing else", so being able to assert that on a string beats being fast.
@Suite
struct WorksheetSpliceTests {

    // MARK: - A sheet with something in every corner

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

    private static let sharedStrings = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="2" uniqueCount="2">\
        <si><t>Region</t></si><si><t>North</t></si></sst>
        """

    /// `A2` masters a shared formula over `A2:A3`; `A3` follows it. Row 1 has a gap at `B1`.
    /// Everything around `<sheetData>` is something this library does not model.
    static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetPr><tabColor rgb="FF00B050"/></sheetPr>\
        <dimension ref="A1:C3"/>\
        <sheetViews><sheetView tabSelected="1" workbookViewId="0"/></sheetViews>\
        <cols><col min="1" max="1" width="20.5" customWidth="1"/></cols>\
        <sheetData>\
        <row r="1" ht="30" customHeight="1"><c r="A1" t="s" s="5"><v>0</v></c>\
        <c r="C1" s="7"><v>3</v></c></row>\
        <row r="2"><c r="A2" s="9"><f t="shared" ref="A2:A3" si="0">C1*2</f><v>6</v></c></row>\
        <row r="3"><c r="A3" s="9"><f t="shared" si="0"/><v>6</v></c>\
        <c r="B3" s="4"><f>A3+1</f><v>7</v></c></row>\
        </sheetData>\
        <conditionalFormatting sqref="A1:A9"><cfRule type="top10" priority="1" rank="3"/>\
        </conditionalFormatting>\
        <hyperlinks><hyperlink ref="C1" r:id="rId9"/></hyperlinks>\
        <pageSetup orientation="landscape" paperSize="9"/>\
        <drawing r:id="rId1"/></worksheet>
        """

    private func package() throws -> Data {
        try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/sharedStrings.xml", data: Data(Self.sharedStrings.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheet.utf8)),
        ])
    }

    /// Opens the fixture, hands the sheet to `edit`, saves, and returns the sheet XML.
    private func spliced(_ edit: (Worksheet) -> Void) throws -> String {
        let workbook = try Workbook(xlsxData: try package())
        edit(try #require(workbook.sheets.first))
        let entries = try ZIPReader.read(from: try workbook.save())
        let part = try #require(entries.first { $0.path == "xl/worksheets/sheet1.xml" })
        return String(decoding: part.data, as: UTF8.self)
    }

    private func workbookAfter(_ edit: (Worksheet) -> Void) throws -> [String: Data] {
        let workbook = try Workbook(xlsxData: try package())
        edit(try #require(workbook.sheets.first))
        return Dictionary(uniqueKeysWithValues:
            try ZIPReader.read(from: try workbook.save()).map { ($0.path, $0.data) })
    }

    // MARK: - The claim: nothing else moved

    /// **One cell changed, and the file says so and nothing more.** Asserted by rebuilding the
    /// expected XML from the original with a single textual substitution — if any other byte
    /// moved, this fails and prints where.
    @Test("changing a value rewrites that cell and no other byte")
    func onlyTheCellChanges() throws {
        let after = try spliced { $0.write(42.0, to: "C1") }
        let expected = Self.sheet.replacingOccurrences(
            of: "<c r=\"C1\" s=\"7\"><v>3</v></c>",
            with: "<c r=\"C1\" s=\"7\"><v>42</v></c>")
        #expect(after == expected, "spliced:\n\(after)\n\nexpected:\n\(expected)")
    }

    /// The elements a regenerated sheet loses, named one at a time so a failure says which.
    @Test("every element the writer does not model survives an edit")
    func unmodelledElementsSurvive() throws {
        let after = try spliced { $0.write(42.0, to: "C1") }
        for fragment in ["<sheetPr><tabColor rgb=\"FF00B050\"/></sheetPr>",
                         "<col min=\"1\" max=\"1\" width=\"20.5\" customWidth=\"1\"/>",
                         "<cfRule type=\"top10\" priority=\"1\" rank=\"3\"/>",
                         "<hyperlink ref=\"C1\" r:id=\"rId9\"/>",
                         "<pageSetup orientation=\"landscape\" paperSize=\"9\"/>",
                         "<drawing r:id=\"rId1\"/>",
                         "<row r=\"1\" ht=\"30\" customHeight=\"1\">"] {
            #expect(after.contains(fragment), "lost \(fragment)")
        }
    }

    /// A value edit is not a formatting edit. The cell keeps the style index it had, because
    /// the caller changed what the cell says and not how it looks.
    @Test("an edited cell keeps its style index")
    func keepsTheStyleIndex() throws {
        let after = try spliced { $0.write(42.0, to: "C1") }
        #expect(after.contains("<c r=\"C1\" s=\"7\">"), "C1 lost s=\"7\"")
    }

    // MARK: - The kinds of edit

    /// A formula replaces the old formula *and* the value it cached, which is now a lie.
    @Test("writing a formula replaces the cached value too")
    func writingAFormula() throws {
        let after = try spliced { $0.writeFormula("A3+2", to: "B3") }
        #expect(after.contains("<f>A3+2</f>"))
        #expect(!after.contains("<f>A3+1</f>"), "the old formula is still there")
        #expect(!after.contains("<f>A3+2</f><v>7</v>"),
                "the cached 7 belonged to the old formula")
    }

    /// Writing text puts it in the shared table, and the indices already in the file keep
    /// their positions — a sheet copied through unspliced still reads `<v>0</v>` as "Region".
    @Test("writing text appends to the shared strings and moves nothing")
    func writingText() throws {
        let after = try workbookAfter { $0.write("South", to: "C1") }
        let table = String(decoding: try #require(after["xl/sharedStrings.xml"]), as: UTF8.self)
        let region = try #require(table.range(of: "Region"))
        let north = try #require(table.range(of: "North"))
        let south = try #require(table.range(of: "South"))
        #expect(region.lowerBound < north.lowerBound && north.lowerBound < south.lowerBound,
                "a new string must go on the end: \(table)")

        let sheet = String(decoding: try #require(after["xl/worksheets/sheet1.xml"]), as: UTF8.self)
        #expect(sheet.contains("<c r=\"C1\" s=\"7\" t=\"s\"><v>2</v></c>"),
                "C1 should read index 2, the appended string: \(sheet)")
        #expect(sheet.contains("<c r=\"A1\" t=\"s\" s=\"5\"><v>0</v></c>"),
                "A1's index must not have been renumbered")
    }

    /// A cell that was not in the file is inserted in column order inside its row — out of
    /// order, Excel repairs the sheet.
    @Test("a new cell is inserted in column order within its row")
    func insertsACellInOrder() throws {
        let after = try spliced { $0.write(7.0, to: "B1") }
        let a1 = try #require(after.range(of: "r=\"A1\""))
        let b1 = try #require(after.range(of: "r=\"B1\""))
        let c1 = try #require(after.range(of: "r=\"C1\""))
        #expect(a1.lowerBound < b1.lowerBound && b1.lowerBound < c1.lowerBound,
                "B1 landed out of order: \(after)")
    }

    /// And a row that was not in the file is inserted in row order, with the dimension widened
    /// to cover it.
    @Test("a new row is inserted in row order and widens the dimension")
    func insertsARowInOrder() throws {
        let after = try spliced { $0.write(5.0, to: "D5") }
        let row3 = try #require(after.range(of: "<row r=\"3\""))
        let row5 = try #require(after.range(of: "<row r=\"5\""))
        #expect(row3.lowerBound < row5.lowerBound, "row 5 landed before row 3")
        #expect(after.contains("<dimension ref=\"A1:D5\"/>"),
                "the dimension still claims A1:C3: \(after)")
    }

    /// Writing nothing into a styled cell leaves the style and takes the value, which is what
    /// Excel does for a formatted empty cell.
    @Test("clearing a cell keeps its formatting")
    func clearingACell() throws {
        let after = try spliced { $0.apply([CellRef("C1"): .blank]) }
        #expect(after.contains("<c r=\"C1\" s=\"7\"/>"), "C1 should be empty and still styled")
    }

    // MARK: - Refusing what would break other cells

    /// **A shared formula's master carries the text its followers use.** `A2` holds
    /// `<f t="shared" ref="A2:A3" si="0">C1*2</f>` and `A3` holds only `<f t="shared" si="0"/>`.
    /// Replacing `A2`'s formula leaves `A3` pointing at an `si` whose text is gone, so the
    /// splice is refused rather than quietly breaking a cell the caller never touched.
    @Test("editing a shared formula's master is refused")
    func refusesToEditASharedMaster() throws {
        let workbook = try Workbook(xlsxData: try package())
        try #require(workbook.sheets.first).writeFormula("C1*3", to: "A2")
        #expect(throws: SaveError.self) { _ = try workbook.save() }
    }

    /// **A style index is positional, and this workbook's style table is not the file's.** The
    /// reader parses `xl/styles.xml` into its own type and never fills the workbook's
    /// `StyleSheet`, so allocating an index for a brand-new cell's style would hand it `0` —
    /// and `s="0"` in the file means that file's first format, which every cell already using
    /// it would then be claimed to share. Refused until the reader loads the table.
    @Test("a new cell with a style is refused rather than given a colliding index")
    func refusesANewStyledCell() throws {
        let workbook = try Workbook(xlsxData: try package())
        var style = CellStyle.general
        style.numberFormat = .percent
        try #require(workbook.sheets.first).write(0.5, to: "D9", style: style)
        #expect(throws: SaveError.self) { _ = try workbook.save() }
    }

    /// A new cell with no style is fine: no `s` attribute means the default format, which is
    /// what an unformatted cell in any file carries.
    @Test("a new cell without a style is written with no style index")
    func newCellWithoutAStyle() throws {
        let after = try spliced { $0.write(7.0, to: "B1") }
        #expect(after.contains("<c r=\"B1\"><v>7</v></c>"), "B1 should carry no s=: \(after)")
    }

    /// A follower is its own cell, though: editing `A3` takes it out of the group and leaves
    /// the master alone.
    @Test("editing a shared formula's follower is allowed")
    func allowsEditingAFollower() throws {
        let after = try spliced { $0.writeFormula("C1*9", to: "A3") }
        #expect(after.contains("<f>C1*9</f>"))
        #expect(after.contains("<f t=\"shared\" ref=\"A2:A3\" si=\"0\">C1*2</f>"),
                "the master must be untouched")
    }
}
