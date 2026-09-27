import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// Giving a new cell a style, in a workbook whose style table this library did not write.
///
/// ## Why this could not simply adopt the table
///
/// A style index is positional: `s="7"` means "the eighth `<xf>` of this file's `<cellXfs>`".
/// The reader parses `xl/styles.xml` into its own type and never fills the workbook's
/// ``StyleSheet``, so `register` would have handed out index `0` — the file's *first* format,
/// which every cell already carrying `s="0"` would then be claimed to share. Until now that was
/// refused outright.
///
/// Adopting the parsed table and regenerating would be worse. `StyleSheet.toXML()` writes a
/// styles part out of `CellStyle`, which models a fraction of what a real one holds; a workbook
/// saved that way would keep its indices and lose the formatting they point at.
///
/// So the file's own `xl/styles.xml` is **appended to**: the new `<xf>` goes on the end of
/// `<cellXfs>`, its font, fill and border on the end of theirs, and every index that was
/// already in the file still means exactly what it meant. The same rule the shared strings
/// follow, and what §3.3 asks for.
@Suite
struct StyleAppendTests {

    private static let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
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
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
        </Relationships>
        """

    private static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="A1" s="2"><v>2</v></c></row></sheetData></worksheet>
        """

    /// Three `<xf>`s, two fonts, three fills, two borders, and one custom format already at
    /// 164 — so an appended custom format must not reuse that id.
    static let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.0&quot;x&quot;"/></numFmts>\
        <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>\
        <font><b/><sz val="14"/><name val="Helvetica"/></font></fonts>\
        <fills count="3"><fill><patternFill patternType="none"/></fill>\
        <fill><patternFill patternType="gray125"/></fill>\
        <fill><patternFill patternType="solid"><fgColor rgb="FFDDEEFF"/></patternFill></fill></fills>\
        <borders count="2"><border><left/><right/><top/><bottom/></border>\
        <border><left style="thin"><color rgb="FF000000"/></left><right/><top/><bottom/></border></borders>\
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
        <cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\
        <xf numFmtId="164" fontId="1" fillId="2" borderId="1" xfId="0" applyNumberFormat="1"/>\
        <xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>\
        <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\
        </styleSheet>
        """

    private func package(styles: String = styles) throws -> Data {
        try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML.utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/styles.xml", data: Data(styles.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheet.utf8)),
        ])
    }

    /// Writes `style` into a new cell and returns the styles and sheet parts as written.
    private func saving(_ style: CellStyle, styles: String = styles) throws
        -> (styles: String, sheet: String) {
        let workbook = try Workbook(xlsxData: try package(styles: styles))
        try #require(workbook.sheets.first).write(5.0, to: "B1", style: style)
        let entries = try ZIPReader.read(from: try workbook.save())
        func part(_ path: String) throws -> String {
            String(decoding: try #require(entries.first { $0.path == path }).data, as: UTF8.self)
        }
        return (try part("xl/styles.xml"), try part("xl/worksheets/sheet1.xml"))
    }

    // MARK: - It works at all

    @Test("a new cell can be given a style")
    func aNewStyledCellIsAllowed() throws {
        let written = try saving(.percent)
        #expect(written.sheet.contains("r=\"B1\""), "\(written.sheet)")
    }

    /// **The index is the end of the table**, so nothing that was already in the file moves.
    @Test("the new style takes the next index, and the old ones keep theirs")
    func appendsAtTheEnd() throws {
        let written = try saving(.percent)
        #expect(written.sheet.contains("<c r=\"B1\" s=\"3\">"),
                "the file had three xfs, so the new one is index 3: \(written.sheet)")
        #expect(written.sheet.contains("<c r=\"A1\" s=\"2\">"),
                "A1 still points at the third xf: \(written.sheet)")
        #expect(written.styles.contains("<cellXfs count=\"4\">"), "\(written.styles)")
    }

    /// Every `<xf>` the file had is still there, in order. If one moved, every cell in the
    /// workbook that pointed at it now means something else.
    @Test("the original cellXfs entries are untouched and in order")
    func originalEntriesSurvive() throws {
        let written = try saving(.percent)
        for original in ["<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>",
                         "<xf numFmtId=\"164\" fontId=\"1\" fillId=\"2\" borderId=\"1\" xfId=\"0\" applyNumberFormat=\"1\"/>",
                         "<xf numFmtId=\"14\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>"] {
            #expect(written.styles.contains(original), "lost \(original)")
        }
    }

    /// The other collections are appended to, not rebuilt: the fonts, fills and borders the
    /// file already had keep their positions too, because the surviving `<xf>`s point at them.
    @Test("fonts, fills and borders are appended to rather than rebuilt")
    func collectionsAreAppendedTo() throws {
        let written = try saving(CellStyle(font: Font(bold: true), fill: .solid("FF00FF00")))
        #expect(written.styles.contains("<font><b/><sz val=\"14\"/><name val=\"Helvetica\"/></font>"),
                "the file's second font moved or changed: \(written.styles)")
        #expect(written.styles.contains("<fgColor rgb=\"FFDDEEFF\"/>"),
                "the file's third fill moved or changed: \(written.styles)")
        #expect(written.styles.contains("<fonts count=\"3\">"), "\(written.styles)")
        #expect(written.styles.contains("<fills count=\"4\">"), "\(written.styles)")
    }

    // MARK: - Number formats

    /// A built-in format needs no `<numFmt>` — `10` is `0.00%` in every file there is.
    @Test("a built-in number format reuses its built-in id")
    func builtinFormat() throws {
        let written = try saving(.percent)
        #expect(written.styles.contains("<numFmts count=\"1\">"),
                "nothing should have been added to numFmts: \(written.styles)")
        #expect(written.styles.contains("numFmtId=\"10\""), "\(written.styles)")
    }

    /// A custom one is appended, and **must not take an id the file is already using** — 164
    /// is taken here, so the new one is 165.
    @Test("a custom number format gets an id the file is not already using")
    func customFormat() throws {
        let written = try saving(CellStyle(numberFormat: NumberFormat(formatString: "0.000_);(0.000)")))
        #expect(written.styles.contains("<numFmts count=\"2\">"), "\(written.styles)")
        #expect(written.styles.contains("numFmtId=\"165\""),
                "164 is taken by the file's own format: \(written.styles)")
        #expect(written.styles.contains("formatCode=\"#,##0.0&quot;x&quot;\""),
                "the file's own custom format must survive: \(written.styles)")
    }

    /// A file with no `<numFmts>` at all gets one, and it goes **first** — the schema fixes the
    /// order of a styleSheet's children and Excel repairs a file that gets it wrong.
    @Test("numFmts is created in the right place when the file has none")
    func createsNumFmts() throws {
        let without = Self.styles.replacingOccurrences(
            of: "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"#,##0.0&quot;x&quot;\"/></numFmts>",
            with: "")
        let written = try saving(CellStyle(numberFormat: NumberFormat(formatString: "0.0000")),
                                 styles: without)
        let numFmts = try #require(written.styles.range(of: "<numFmts"))
        let fonts = try #require(written.styles.range(of: "<fonts"))
        #expect(numFmts.lowerBound < fonts.lowerBound,
                "numFmts must precede fonts: \(written.styles)")
        #expect(written.styles.contains("numFmtId=\"164\""),
                "with none taken, the first custom id is 164: \(written.styles)")
    }

    // MARK: - Not paying for what is not used

    /// An unedited save still returns the styles part byte for byte — step 3's gate, which a
    /// style table that rewrote itself on every save would spend.
    @Test("a save that adds no style leaves the part alone")
    func noStyleNoChange() throws {
        let workbook = try Workbook(xlsxData: try package())
        try #require(workbook.sheets.first).write(9.0, to: "A1")
        let entries = try ZIPReader.read(from: try workbook.save())
        let part = try #require(entries.first { $0.path == "xl/styles.xml" })
        #expect(String(decoding: part.data, as: UTF8.self) == Self.styles,
                "editing a cell's value must not touch the style table")
    }

    /// And the manifest says when it will change.
    @Test("the manifest names the style table only when a style is appended")
    func manifestNamesTheStyleTable() throws {
        let plain = try Workbook(xlsxData: try package())
        try #require(plain.sheets.first).write(9.0, to: "A1")
        #expect(!(try plain.saveManifest().rewritten.contains("xl/styles.xml")))

        let styled = try Workbook(xlsxData: try package())
        try #require(styled.sheets.first).write(9.0, to: "B1", style: .percent)
        #expect(try styled.saveManifest().rewritten.contains("xl/styles.xml"))
    }
}
