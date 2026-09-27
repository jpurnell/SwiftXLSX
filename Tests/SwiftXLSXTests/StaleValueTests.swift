import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore
import SwiftZIP

/// What an edit does about the values it has just made wrong.
///
/// Every formula cell carries the value Excel last computed for it. Change a precedent and its
/// dependents' caches are lies — and a surgical save deliberately does not touch those cells,
/// so nothing in the file says so. Excel is told to recalculate on open, via
/// `fullCalcOnLoad="1"` on `<calcPr>`.
///
/// ## Why this is a choice and not a rule
///
/// §18.4 of `PROPOSAL_surgical_save.md` amended §3.3 on the strength of a real workbook.
/// Forcing a recalculation is honest when Excel can resolve every function in the file. It is
/// destructive when it cannot: a Risk Solver model opened without the add-in recalculates
/// `_xll.PsiNormal(…)` to `#NAME?` and cascades that through everything downstream, and the
/// stale cache was more useful than the honest recalculation. So the caller can decline.
///
/// A caller who has an evaluator does not need a third option: they write the recomputed
/// values in as ordinary cell edits, and the splicer puts them where they belong.
@Suite
struct StaleValueTests {

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

    private static let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData><row r="1"><c r="A1"><v>2</v></c>\
        <c r="B1"><f>A1*3</f><v>6</v></c></row></sheetData></worksheet>
        """

    /// The workbook part, with whatever `<calcPr>` the case needs.
    private static func workbookXML(_ tail: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>\(tail)</workbook>
        """
    }

    private func package(_ tail: String) throws -> Data {
        try ZIPWriter.write(entries: [
            ZIPEntry(path: "[Content_Types].xml", data: Data(Self.contentTypes.utf8)),
            ZIPEntry(path: "_rels/.rels", data: Data(Self.packageRels.utf8)),
            ZIPEntry(path: "xl/workbook.xml", data: Data(Self.workbookXML(tail).utf8)),
            ZIPEntry(path: "xl/_rels/workbook.xml.rels", data: Data(Self.workbookRels.utf8)),
            ZIPEntry(path: "xl/worksheets/sheet1.xml", data: Data(Self.sheet.utf8)),
        ])
    }

    /// Opens, optionally edits, saves, and returns the workbook part as written.
    private func workbookPart(_ tail: String, edit: Bool = true,
                             staleValues: StaleValuePolicy = .markForRecalculation) throws
        -> String {
        let workbook = try Workbook(xlsxData: try package(tail))
        if edit { try #require(workbook.sheets.first).write(99.0, to: "A1") }
        let saved = try workbook.save(strategy: nil, staleValues: staleValues)
        let entries = try ZIPReader.read(from: saved)
        let part = try #require(entries.first { $0.path == "xl/workbook.xml" })
        return String(decoding: part.data, as: UTF8.self)
    }

    // MARK: - Marking

    @Test("an edit sets fullCalcOnLoad on an existing calcPr")
    func setsItOnAnExistingCalcPr() throws {
        let after = try workbookPart("<calcPr calcId=\"191029\"/>")
        #expect(after.contains("fullCalcOnLoad=\"1\""), "\(after)")
        #expect(after.contains("calcId=\"191029\""),
                "the attributes that were already there must survive: \(after)")
        #expect(after.components(separatedBy: "<calcPr").count - 1 == 1,
                "one calcPr, not two: \(after)")
    }

    /// A workbook with no `<calcPr>` gets one. It is the last child before `<extLst>`, which
    /// is where the schema puts it — Excel repairs a file whose elements are out of order by
    /// deleting what it could not place.
    @Test("an edit adds a calcPr when there is none")
    func addsACalcPr() throws {
        let after = try workbookPart("")
        #expect(after.contains("<calcPr fullCalcOnLoad=\"1\"/></workbook>"), "\(after)")
    }

    @Test("the calcPr goes before an extLst rather than after it")
    func insertsBeforeExtLst() throws {
        let after = try workbookPart("<extLst><ext uri=\"{140A7094}\"/></extLst>")
        let calc = try #require(after.range(of: "<calcPr"))
        let ext = try #require(after.range(of: "<extLst"))
        #expect(calc.lowerBound < ext.lowerBound, "\(after)")
    }

    /// An existing `fullCalcOnLoad="0"` is an instruction not to recalculate, and an edit
    /// makes it wrong.
    @Test("an explicit fullCalcOnLoad of zero is corrected")
    func correctsAnExplicitZero() throws {
        let after = try workbookPart("<calcPr calcId=\"1\" fullCalcOnLoad=\"0\"/>")
        #expect(after.contains("fullCalcOnLoad=\"1\""), "\(after)")
        #expect(!after.contains("fullCalcOnLoad=\"0\""), "\(after)")
    }

    // MARK: - Leaving alone

    /// **Nothing changed, so nothing is stale.** An unedited save must still be byte-identical,
    /// which is step 3's gate and must not be spent on a recalculation nobody needs.
    @Test("a save with no edits does not touch the workbook part")
    func anUneditedSaveIsUntouched() throws {
        let before = Self.workbookXML("<calcPr calcId=\"191029\"/>")
        #expect(try workbookPart("<calcPr calcId=\"191029\"/>", edit: false) == before)
    }

    /// **The escape hatch, and the reason it exists.** A workbook whose formulas Excel cannot
    /// resolve on its own — an add-in's functions — recalculates to `#NAME?` and cascades. For
    /// those, a stale cache is worth more than an honest one.
    @Test("the caller can decline the recalculation")
    func theCallerCanDecline() throws {
        let before = Self.workbookXML("<calcPr calcId=\"191029\"/>")
        let after = try workbookPart("<calcPr calcId=\"191029\"/>", staleValues: .untouched)
        #expect(after == before, "declining must leave the part exactly as it was")
    }

    // MARK: - Saying so

    @Test("the manifest reports the workbook part as rewritten when an edit marks it")
    func manifestReportsIt() throws {
        let workbook = try Workbook(xlsxData: try package("<calcPr calcId=\"1\"/>"))
        try #require(workbook.sheets.first).write(99.0, to: "A1")
        let manifest = try workbook.saveManifest(strategy: .surgical)
        #expect(manifest.rewritten.contains("xl/workbook.xml"),
                "a caller shown this manifest should see that the part will change")
        #expect(manifest.forcesRecalculation)
    }

    /// `.generated` has nothing to preserve, so the policy does not apply to it.
    @Test("the generated strategy is unaffected")
    func generatedIsUnaffected() throws {
        let workbook = try Workbook(xlsxData: try package("<calcPr calcId=\"1\"/>"))
        try #require(workbook.sheets.first).write(99.0, to: "A1")
        let saved = try workbook.save(strategy: .generated, staleValues: .markForRecalculation)
        #expect(try ZIPReader.read(from: saved).contains { $0.path == "xl/workbook.xml" })
    }
}
