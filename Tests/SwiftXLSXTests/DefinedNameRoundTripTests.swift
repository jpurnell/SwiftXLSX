import XCTest
import SwiftExcelCore
@testable import SwiftXLSX

/// A workbook keeps its defined names.
///
/// The writer emitted no `<definedName>` at all, so a file read by this package and written
/// back came out with an empty Name Manager. Measured across 2,240 workbooks: **1,022 of them
/// define names, 161,901 in all**, and the largest single model has 47,106. The loss was
/// silent, the file opened, and nothing said so.
///
/// These tests are what licenses the design. A name is held **once** — the target is its
/// meaning — and the refers-to text is reconstructed from it rather than copied, so every
/// rule the writer applies has to be right. Each test below is one rule with its evidence.
final class DefinedNameRoundTripTests: XCTestCase {

    // MARK: - Reading

    /// A whole column is a reference, and reading it as anything else was a live defect.
    ///
    /// `isReference` wanted a letter *and* a digit in each half, so `$D` failed and
    /// `amounts = Expenditures!$D:$D` became a text constant — which is why
    /// `SUMIFS(amounts, …)` answered zero across 1,058 cells in one corpus workbook.
    func testAWholeColumnReads() throws {
        let target = DefinedNameResolver.namedRange(
            from: DefinedNameInfo(name: "amounts", formula: "Expenditures!$D:$D",
                                  localSheetId: nil, isHidden: false, attributes: [:]),
            sheets: [])?.reference

        guard case .sheetRange(let reference)? = target else {
            return XCTFail("expected a sheet range, got \(String(describing: target))")
        }
        XCTAssertEqual(reference.sheetName, "Expenditures")
        XCTAssertEqual(reference.range.start.column, 4)
        XCTAssertEqual(reference.range.start.row, 1)
        XCTAssertEqual(reference.range.end.row, CellRef.lastOnSheet.row)
        XCTAssertTrue(reference.range.start.absoluteColumn, "the $ is part of what was written")
    }

    /// A whole row, likewise.
    func testAWholeRowReads() throws {
        let target = DefinedNameResolver.namedRange(
            from: DefinedNameInfo(name: "header", formula: "Sheet1!$3:$3",
                                  localSheetId: nil, isHidden: false, attributes: [:]),
            sheets: [])?.reference

        guard case .sheetRange(let reference)? = target else {
            return XCTFail("expected a sheet range")
        }
        XCTAssertEqual(reference.range.start.row, 3)
        XCTAssertEqual(reference.range.end.column, CellRef.lastOnSheet.column)
    }

    /// What cannot be read says so, rather than posing as a text constant.
    func testWhatCannotBeReadIsUnparsed() throws {
        for formula in ["_xlfn.LAMBDA(_xlpm.x,_xlpm.x+1)",
                        "OFFSET(Sheet1!$A$1,0,0,COUNTA(Sheet1!$A:$A),1)"] {
            let target = DefinedNameResolver.namedRange(
                from: DefinedNameInfo(name: "n", formula: formula, localSheetId: nil,
                                      isHidden: false, attributes: [:]),
                sheets: [])?.reference
            guard case .unparsed(let kept)? = target else {
                return XCTFail("expected .unparsed for \(formula)")
            }
            XCTAssertEqual(kept, formula)
        }
    }

    // MARK: - Writing

    /// Every shape, written back exactly as the file had it.
    ///
    /// These are the promises the design makes. A shape not in this list is one the reader
    /// should leave `.unparsed`, where the round trip is the identity and no rule applies.
    func testEveryPromisedShapeRoundTripsExactly() throws {
        let shapes = [
            "Definitions!$B$53",
            "Definitions!$B$19:$C$51",
            "'2018 - Sorted by Area'!$J$2:$J$333",
            "Expenditures!$D:$D",
            "Sheet1!$3:$3",
            "_xlfn.LAMBDA(_xlpm.arr,_xlpm.y,MAX(_xlpm.arr)^_xlpm.y)",
            "OFFSET(Sheet1!$A$1,0,0,COUNTA(Sheet1!$A:$A),1)",
        ]
        for formula in shapes {
            guard let name = DefinedNameResolver.namedRange(
                from: DefinedNameInfo(name: "n", formula: formula, localSheetId: nil,
                                      isHidden: false, attributes: [:]),
                sheets: []) else {
                return XCTFail("did not read \(formula)")
            }
            XCTAssertEqual(DefinedNameWriter.refersTo(name.reference), formula, formula)
        }
    }

    /// A sheet name is quoted only where Excel quotes it.
    ///
    /// The one rule here that is a judgement rather than a fact about the data: quoting a
    /// name that needs no quotes is accepted by Excel and is still not what the file said.
    func testSheetNamesAreQuotedOnlyWhenTheyMustBe() {
        XCTAssertFalse(DefinedNameWriter.needsQuoting("Definitions"))
        XCTAssertFalse(DefinedNameWriter.needsQuoting("Sheet_1"))
        XCTAssertFalse(DefinedNameWriter.needsQuoting("Q3"))
        XCTAssertTrue(DefinedNameWriter.needsQuoting("2018 - Sorted by Area"))
        XCTAssertTrue(DefinedNameWriter.needsQuoting("P&L"))
        XCTAssertTrue(DefinedNameWriter.needsQuoting("3M"), "a leading digit needs quoting")
        XCTAssertTrue(DefinedNameWriter.needsQuoting(""))
    }

    /// A full span is written short, because the expansion is visible to the user.
    ///
    /// `D1:D1048576` selects the same cells as `$D:$D` and reads as a mistake in the Name
    /// Manager.
    func testAFullSpanIsWrittenInItsShortForm() {
        let column = NamedRangeTarget.range(CellRange(
            from: CellRef(column: 4, row: 1, absoluteColumn: true, absoluteRow: false),
            to: CellRef(column: 4, row: CellRef.lastOnSheet.row,
                        absoluteColumn: true, absoluteRow: false)))
        XCTAssertEqual(DefinedNameWriter.refersTo(column), "$D:$D")

        let ordinary = NamedRangeTarget.range(CellRange(from: CellRef("$B$2"), to: CellRef("$C$9")))
        XCTAssertEqual(DefinedNameWriter.refersTo(ordinary), "$B$2:$C$9")
    }

    /// A span covering the whole sheet is two short forms at once, and the `$`s say which.
    ///
    /// `[1]AVP!$1:$1048576` is every row, and every row is also every column, so both branches
    /// of the short-form rule match it and the first one written won. It wrote `A:XFD` —
    /// the same cells, a different form, and the absolute markers gone.
    ///
    /// Found by the corpus round trip: 54 names across three versions of one operating model,
    /// the only names in 158,132 that came back changed. They are `_bdm.<guid>.edm` entries,
    /// which Excel writes for external-workbook links and which no user typed — so the loss
    /// would have been silent twice over.
    ///
    /// Which form the file used is not recoverable from the cells, because the two forms
    /// select the same ones. It is recoverable from the markers: `$1:$1048576` has absolute
    /// rows and relative columns, and `$A:$XFD` is the other way round. So the ambiguity is
    /// resolved by the half that carries a `$`, which is evidence rather than preference.
    func testAWholeSheetSpanKeepsTheFormItWasWrittenIn() {
        let everyRow = NamedRangeTarget.range(CellRange(
            from: CellRef(column: 1, row: 1, absoluteColumn: false, absoluteRow: true),
            to: CellRef(column: CellRef.lastOnSheet.column, row: CellRef.lastOnSheet.row,
                        absoluteColumn: false, absoluteRow: true)))
        XCTAssertEqual(DefinedNameWriter.refersTo(everyRow), "$1:$1048576")

        let everyColumn = NamedRangeTarget.range(CellRange(
            from: CellRef(column: 1, row: 1, absoluteColumn: true, absoluteRow: false),
            to: CellRef(column: CellRef.lastOnSheet.column, row: CellRef.lastOnSheet.row,
                        absoluteColumn: true, absoluteRow: false)))
        XCTAssertEqual(DefinedNameWriter.refersTo(everyColumn), "$A:$XFD")
    }

    /// The name that found it, read and written as the file has it.
    func testTheExternalLinkNameFromTheCorpusRoundTrips() throws {
        for formula in ["[1]AVP!$1:$1048576",
                        "'[2]LBO Sources and Uses'!$1:$1048576"] {
            guard let name = DefinedNameResolver.namedRange(
                from: DefinedNameInfo(name: "_bdm.x.edm", formula: formula, localSheetId: nil,
                                      isHidden: true, attributes: [:]),
                sheets: []) else {
                return XCTFail("did not read \(formula)")
            }
            XCTAssertEqual(DefinedNameWriter.refersTo(name.reference), formula)
        }
    }

    // MARK: - Through a file

    /// The whole path: define, save, read back.
    func testNamesSurviveAFile() throws {
        let workbook = Workbook()
        let definitions = workbook.addSheet(name: "Definitions")
        definitions.write(0.0825, to: "C8")
        workbook.addSheet(name: "Expenditures")

        workbook.define("taxRate", as: .sheetCell(
            SheetReference(sheet: "Definitions", cell: CellRef("$C$8"))))
        workbook.define("amounts", as: .unparsed("Expenditures!$D:$D"))
        workbook.define("normal", as: .unparsed("_xlfn.LAMBDA(_xlpm.x,_xlpm.x+1)"))
        workbook.define("_xlnm._FilterDatabase", as: .unparsed("Expenditures!$A$2:$W$99"),
                        scope: .sheet("Expenditures"), hidden: true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("names-\(UUID().uuidString).xlsx")
        try workbook.save(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reread = try Workbook(contentsOf: url)
        XCTAssertEqual(reread.namedRanges.all.count, 4)

        XCTAssertEqual(DefinedNameWriter.refersTo(
            try XCTUnwrap(reread.namedRanges.resolve("taxRate"))), "Definitions!$C$8")
        XCTAssertEqual(DefinedNameWriter.refersTo(
            try XCTUnwrap(reread.namedRanges.resolve("amounts"))), "Expenditures!$D:$D")
        XCTAssertEqual(DefinedNameWriter.refersTo(
            try XCTUnwrap(reread.namedRanges.resolve("normal"))),
            "_xlfn.LAMBDA(_xlpm.x,_xlpm.x+1)")

        // The hidden one, which is 46% of the corpus and the easiest thing to lose.
        let filter = try XCTUnwrap(
            reread.namedRanges.all.first { $0.name == "_xlnm._FilterDatabase" })
        XCTAssertTrue(filter.isHidden, "a hidden name must come back hidden")
        XCTAssertEqual(filter.scope, .sheet("Expenditures"))
    }

    /// Writing a workbook twice gives the same bytes, or a round trip cannot be diffed.
    func testTheOutputIsStable() throws {
        func build() throws -> Data {
            let workbook = Workbook()
            workbook.addSheet(name: "Sheet1")
            workbook.define("b", as: .cell(CellRef("$B$2")), attributes: ["comment": "two"])
            workbook.define("a", as: .cell(CellRef("$A$1")),
                            attributes: ["description": "one", "comment": "first"])
            return try workbook.save()
        }
        XCTAssertEqual(try build(), try build())
    }

    /// A workbook with no names writes no element at all.
    func testNoNamesMeansNoElement() {
        XCTAssertEqual(DefinedNameWriter.element(for: [], sheets: []), "")
    }
}
