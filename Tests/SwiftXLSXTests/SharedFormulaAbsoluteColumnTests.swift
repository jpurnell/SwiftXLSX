import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore

/// A shared formula must not move a column its master pinned with `$`.
///
/// ## The measurement
///
/// `Display vs Paid Performance Excel.xlsx` carries **13,821 shared followers** on one sheet,
/// and 120 of its cells disagreed with Excel — every one of them reading `0` where Excel had a
/// number. The master is
///
/// ```xml
/// <c r="BP11"><f t="shared" ref="BP11:BZ11" si="34">
///   SUMIFS($BE:$BE,$AZ:$AZ,BP$2,$AY:$AY,BP$3)
/// </f></c>
/// <c r="BV11"><f t="shared" si="34"/><v>43375</v></c>
/// ```
///
/// Every range in it is **column-absolute**: `$BE`, `$AZ`, `$AY` name the data and stay put,
/// while `BP$2` and `BP$3` are relative and walk across with each copy. `BV11` sits six columns
/// right of the master, so Excel reads `$BE:$BE` against `BV$2` and `BV$3`.
///
/// We moved all five, producing `SUMIFS(BK:BK, BF:BF, BV$2, BE:BE, BV$3)` — criteria columns
/// holding page-region names against a year of `2013`, which matches nothing. Hence `0`, on
/// every one of the 120, in a formula whose parts were each individually plausible.
///
/// The `$` was lost in the **lexer**: `parsePartialReference` stripped `$` to read the column
/// letters and never recorded that it had been there, so `$BE` and a hypothetical bare `BE`
/// arrived at the parser identically. `SharedFormula.shift(_:rowDelta:columnDelta:)` honours
/// `absoluteColumn` correctly and always did — it was never told.
@Suite
struct SharedFormulaAbsoluteColumnTests {

    private func range(_ formula: String, at index: Int) throws -> CellRange {
        let ast = try FormulaParser.parse(formula)
        guard case .function(_, let args) = ast, index < args.count,
              case .cellRange(let range) = args[index] else {
            Issue.record("argument \(index) of \(formula) is not a range")
            return CellRange(from: CellRef("A1"), to: CellRef("A1"))
        }
        return range
    }

    @Test("a whole-column reference keeps the $ it was written with")
    func parsesAbsoluteWholeColumns() throws {
        let pinned = try range("SUM($BE:$BE)", at: 0)
        #expect(pinned.start.absoluteColumn)
        #expect(pinned.end.absoluteColumn)
    }

    @Test("and a relative one keeps its lack of one")
    func parsesRelativeWholeColumns() throws {
        let loose = try range("SUM(BE:BE)", at: 0)
        #expect(!loose.start.absoluteColumn)
        #expect(!loose.end.absoluteColumn)
    }

    /// Excel allows one end pinned and the other not, and they travel separately.
    @Test("the two ends are independent")
    func parsesAMixedSpan() throws {
        let mixed = try range("SUM($BE:BG)", at: 0)
        #expect(mixed.start.absoluteColumn)
        #expect(!mixed.end.absoluteColumn)
    }

    @Test("whole-row references work the same way")
    func parsesAbsoluteWholeRows() throws {
        let pinned = try range("SUM($2:$3)", at: 0)
        #expect(pinned.start.absoluteRow)
        #expect(pinned.end.absoluteRow)
        let loose = try range("SUM(2:3)", at: 0)
        #expect(!loose.start.absoluteRow)
        #expect(!loose.end.absoluteRow)
    }

    // MARK: - The corpus formula, end to end

    /// **The exact master and offset from the workbook.** `BV11` is six columns right of
    /// `BP11`, so the criteria cells move and the data columns do not.
    @Test("the corpus shared formula translates to what Excel computed")
    func translatesTheCorpusFormula() throws {
        let master = try FormulaParser.parse("SUMIFS($BE:$BE,$AZ:$AZ,BP$2,$AY:$AY,BP$3)")
        let moved = SharedFormula.translate(master, rowDelta: 0, columnDelta: 6)

        guard case .function(let name, let args) = moved, name == "SUMIFS", args.count == 5 else {
            Issue.record("translation changed the shape of the call")
            return
        }
        func column(_ ast: FormulaAST) -> Int? {
            switch ast {
            case .cellRange(let range): return range.start.column
            case .cellRef(let ref): return ref.column
            default: return nil
            }
        }
        #expect(column(args[0]) == CellRef("BE1").column, "$BE:$BE is pinned")
        #expect(column(args[1]) == CellRef("AZ1").column, "$AZ:$AZ is pinned")
        #expect(column(args[3]) == CellRef("AY1").column, "$AY:$AY is pinned")
        #expect(column(args[2]) == CellRef("BV1").column, "BP$2 walks six columns right")
        #expect(column(args[4]) == CellRef("BV1").column, "and so does BP$3")
    }

    /// A whole column still spans every row after translating, which is what makes it whole.
    @Test("a pinned column still covers the sheet")
    func keepsTheFullRowSpan() throws {
        let master = try FormulaParser.parse("SUM($BE:$BE)")
        let moved = SharedFormula.translate(master, rowDelta: 4, columnDelta: 6)
        guard case .function(_, let args) = moved, case .cellRange(let range) = args[0] else {
            Issue.record("not a range after translation")
            return
        }
        #expect(range.start.row == 1)
        #expect(range.end.row == 1_048_576)
        #expect(range.start.column == CellRef("BE1").column)
    }
}
