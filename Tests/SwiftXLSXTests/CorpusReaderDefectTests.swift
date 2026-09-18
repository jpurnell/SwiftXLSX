import XCTest
import SwiftExcelCore
@testable import SwiftXLSX

/// Two defects the corpus work found and left standing.
///
/// Neither is exotic. Both are shapes that appear in ordinary spreadsheets and read wrongly
/// without saying so, which is the class this package cares most about.
final class CorpusReaderDefectTests: XCTestCase {

    // MARK: - A whole column does not move down

    /// `D:D` in a shared formula, shifted down a row, is still `D:D`.
    ///
    /// A shared formula is stored once and translated for each cell it covers, by adding the
    /// row and column offsets to every relative reference. A whole-column reference is held as
    /// rows 1 through 1,048,576 — the full span — so the translation adds the offset to both
    /// ends and walks the column off the bottom of the sheet.
    ///
    /// Excel does not do that. A whole column is a whole column wherever the formula sits;
    /// there is no row to move because it already covers every row.
    func testAWholeColumnDoesNotShiftDown() throws {
        let column = FormulaAST.cellRange(CellRange(
            from: CellRef(column: 4, row: 1, absoluteColumn: false, absoluteRow: false),
            to: CellRef(column: 4, row: CellRef.lastOnSheet.row,
                        absoluteColumn: false, absoluteRow: false)))

        let shifted = SharedFormula.translate(column, rowDelta: 5, columnDelta: 0)
        guard case .cellRange(let range) = shifted else {
            return XCTFail("expected a range, got \(shifted)")
        }
        XCTAssertEqual(range.start.row, 1)
        XCTAssertEqual(range.end.row, CellRef.lastOnSheet.row)
        XCTAssertEqual(range.start.column, 4, "the column is what a row shift leaves alone")
    }

    /// Shifted sideways it does move, because that is the direction it has.
    func testAWholeColumnShiftsSideways() throws {
        let column = FormulaAST.cellRange(CellRange(
            from: CellRef(column: 4, row: 1, absoluteColumn: false, absoluteRow: false),
            to: CellRef(column: 4, row: CellRef.lastOnSheet.row,
                        absoluteColumn: false, absoluteRow: false)))

        guard case .cellRange(let range) = SharedFormula.translate(
            column, rowDelta: 3, columnDelta: 2) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.start.column, 6)
        XCTAssertEqual(range.end.column, 6)
        XCTAssertEqual(range.end.row, CellRef.lastOnSheet.row, "still the whole column")
    }

    /// A whole row is the same rule the other way up.
    func testAWholeRowDoesNotShiftSideways() throws {
        let row = FormulaAST.cellRange(CellRange(
            from: CellRef(column: 1, row: 3, absoluteColumn: false, absoluteRow: false),
            to: CellRef(column: CellRef.lastOnSheet.column, row: 3,
                        absoluteColumn: false, absoluteRow: false)))

        guard case .cellRange(let range) = SharedFormula.translate(
            row, rowDelta: 0, columnDelta: 4) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.start.column, 1)
        XCTAssertEqual(range.end.column, CellRef.lastOnSheet.column)
    }

    func testAWholeRowShiftsDown() throws {
        let row = FormulaAST.cellRange(CellRange(
            from: CellRef(column: 1, row: 3, absoluteColumn: false, absoluteRow: false),
            to: CellRef(column: CellRef.lastOnSheet.column, row: 3,
                        absoluteColumn: false, absoluteRow: false)))

        guard case .cellRange(let range) = SharedFormula.translate(
            row, rowDelta: 2, columnDelta: 0) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.start.row, 5)
        XCTAssertEqual(range.end.row, 5)
    }

    /// An ordinary range still shifts in both directions.
    func testAnOrdinaryRangeIsUnaffected() throws {
        let range = FormulaAST.cellRange(CellRange(from: "B2", to: "C4"))
        guard case .cellRange(let shifted) = SharedFormula.translate(
            range, rowDelta: 1, columnDelta: 1) else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(shifted.start.reference, "C3")
        XCTAssertEqual(shifted.end.reference, "D5")
    }

    /// A reference pushed off the bottom of the sheet is `#REF!`, not a row that cannot exist.
    func testShiftingPastTheLastRowIsARefError() throws {
        let nearBottom = FormulaAST.cellRef(
            CellRef(column: 1, row: CellRef.lastOnSheet.row, absoluteColumn: false,
                    absoluteRow: false))
        XCTAssertEqual(SharedFormula.translate(nearBottom, rowDelta: 1, columnDelta: 0),
                       .error(.ref))
    }

    func testShiftingPastTheLastColumnIsARefError() throws {
        let nearEdge = FormulaAST.cellRef(
            CellRef(column: CellRef.lastOnSheet.column, row: 1, absoluteColumn: false,
                    absoluteRow: false))
        XCTAssertEqual(SharedFormula.translate(nearEdge, rowDelta: 0, columnDelta: 1),
                       .error(.ref))
    }

    // MARK: - A newline in a cell is a newline

    /// Excel writes an embedded carriage return as the literal text `_x000D_`.
    ///
    /// It is the format's escape for a character XML cannot carry unchanged, and a reader that
    /// does not decode it hands the caller a string with `_x000D_` sitting in the middle of
    /// it. A cell that reads `Total_x000D_(net of tax)` in a report is the visible symptom;
    /// the invisible one is any comparison, `SUMIF` criterion or lookup key that now contains
    /// eight characters nobody typed.
    func testTheCarriageReturnEscapeIsDecoded() {
        XCTAssertEqual(XMLText.decoded("Total_x000D_(net of tax)"), "Total\r(net of tax)")
        XCTAssertEqual(XMLText.decoded("a_x000D__x000A_b"), "a\r\nb")
    }

    /// The general form, since Excel uses it for any character it cannot write.
    func testAnyEscapedCharacterIsDecoded() {
        XCTAssertEqual(XMLText.decoded("tab_x0009_here"), "tab\there")
        XCTAssertEqual(XMLText.decoded("_x0041_BC"), "ABC")
    }

    /// **The escape for the escape.** A cell whose text really is `_x000D_` is written
    /// `_x005F_x000D_` — `_x005F_` is an underscore — so decoding must not turn it into a
    /// carriage return.
    func testTheEscapedUnderscoreIsRespected() {
        XCTAssertEqual(XMLText.decoded("_x005F_x000D_"), "_x000D_")
    }

    /// Text that merely looks like an escape is left alone.
    func testOrdinaryTextIsUntouched() {
        XCTAssertEqual(XMLText.decoded("x000D"), "x000D")
        XCTAssertEqual(XMLText.decoded("_x00D_"), "_x00D_", "four digits, not three")
        XCTAssertEqual(XMLText.decoded("_xZZZZ_"), "_xZZZZ_")
        XCTAssertEqual(XMLText.decoded("plain"), "plain")
    }

    /// And a string read from a file comes back with the newline in it.
    func testACellWithANewlineReadsBack() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write("Total\r\n(net of tax)", to: "A1")

        let reread = try Workbook(xlsxData: try workbook.save())
        let back = try XCTUnwrap(reread.sheets.first { $0.name == "Sheet1" })
        XCTAssertEqual(back.cell(at: "A1"), .text("Total\r\n(net of tax)"))
    }
}
