import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore

/// The forms real workbooks use that this parser cannot read.
///
/// Measured across 79 workbooks — teaching models, a production credit model and
/// a 104-sheet media model — **53% of formulas fail to parse**, 292,437 of
/// 549,059. A formula with no structure yields no dependency edges, so this is
/// the ceiling on anything built from these files.
///
/// Grouped by cause it is five gaps, not a long tail. Every formula below is
/// copied from a workbook rather than invented.
@Suite
struct FormulaParserGapTests {

    private func parses(_ formula: String) -> Bool {
        (try? FormulaParser.parse(formula)) != nil
    }

    // MARK: - Omitted arguments (~126,000 formulas)

    /// `IFERROR(x,)` means "and empty if it errors". Excel allows an argument to
    /// be left out; the comma still marks its place.
    @Test("Omitted trailing argument")
    func testOmittedTrailingArgument() {
        #expect(parses("IFERROR(B5/C5-1,)"))
    }

    /// `ADDRESS(row, col, 1, , "Sheet")` omits the fourth argument between two
    /// commas, which is the same rule in the middle rather than at the end.
    @Test("Omitted middle argument")
    func testOmittedMiddleArgument() {
        #expect(parses("ADDRESS($C27,AZ$3,1,,\"Lease Revenue\")"))
    }

    // MARK: - Defined names as operands (~95,000 formulas)

    @Test("Defined name as function argument")
    func testDefinedNameAsFunctionArgument() {
        #expect(parses("VLOOKUP(\"SS\",Production_Supply, 7, FALSE)"))
    }

    @Test("Defined name in arithmetic")
    func testDefinedNameInArithmetic() {
        #expect(parses("C36+days_per_week"))
    }

    @Test("Bare defined name is A whole formula")
    func testBareDefinedNameIsAWholeFormula() {
        #expect(parses("report_week_end_date"))
    }

    // MARK: - Whole-column and whole-row ranges (~47,000 formulas)

    /// `$E:$E` is every cell in column E. A criteria function over a column is
    /// how a spreadsheet says "look at all of it".
    @Test("Whole column range")
    func testWholeColumnRange() {
        #expect(parses("SUMIFS(Sheet2!$E:$E,Sheet2!$C:$C,$A$2)"))
    }

    @Test("Whole row range on A quoted sheet")
    func testWholeRowRangeOnAQuotedSheet() {
        #expect(parses("HLOOKUP(DW$2,'Lease Revenue'!$2:$3,2)+5"))
    }

    // MARK: - Prefixed function names (~22,800 formulas)

    /// `_xll.` marks a function supplied by an add-in — here Frontline's Risk
    /// Solver. `_xlfn.` marks one newer than the file format, which Excel writes
    /// so that older versions fail loudly rather than silently.
    @Test("Add in prefixed function")
    func testAddInPrefixedFunction() {
        #expect(parses("_xll.PsiNormal($C$3,$C$4)"))
    }

    @Test("Modern function prefix and dotted name")
    func testModernFunctionPrefixAndDottedName() {
        #expect(parses("_xlfn.COVARIANCE.P($M$5:$M$28,N5:N28)"))
    }

    // MARK: - Percent literals (~60 formulas)

    /// `0.25%` is a number with a suffix. Found only after the lexer stopped
    /// failing earlier in these formulas — the fifth gap was hiding the sixth.
    @Test("Percent literal")
    func testPercentLiteral() {
        #expect(parses("L4+0.25%"))
    }

    // MARK: - Error literals (233 formulas)

    /// A formula can name a cell whose reference broke. The error is the value.
    @Test("Error literal as A value")
    func testErrorLiteralAsAValue() {
        #expect(parses("IFERROR(#REF!,0)"))
    }

    /// The sheet is named and the reference on it is broken.
    @Test("Error literal after A sheet name")
    func testErrorLiteralAfterASheetName() {
        #expect(parses("CB_DATA_!#REF!"))
    }

    // MARK: - Bare column ranges, no dollar (~40 formulas)

    /// `A:A` is the same range as `$A:$A`. The lexer cannot tell `A` from a
    /// defined name, so the parser decides once it has seen the colon and a
    /// second word that is also a column.
    @Test("Bare column range on A quoted sheet")
    func testBareColumnRangeOnAQuotedSheet() {
        #expect(parses("MAX('Paid Cost - Input+Calc'!A:A)"))
    }

    /// `Comp!1:1` — a whole row without the `$`. A bare number lexes as a number,
    /// so the parser recognises the pair rather than the lexer recognising a half.
    @Test("Bare row range on A named sheet")
    func testBareRowRangeOnANamedSheet() {
        #expect(parses("MATCH($A5,Comp!1:1,0)"))
    }

    @Test("A bare word followed by A colon is still A name when it is not A column")
    func testABareWordFollowedByAColonIsStillANameWhenItIsNotAColumn() throws {
        // `days_per_week` is not a column, so nothing here is a range.
        let ast = try FormulaParser.parse("SUM(days_per_week)")
        #expect(ast == .function("SUM", [.namedRange("days_per_week")]))
    }

    // MARK: - Round trip

    /// Every form above must survive being written back out, or the parser has
    /// only half solved the problem.
    @Test("These forms survive A round trip")
    func testTheseFormsSurviveARoundTrip() throws {
        for formula in ["IFERROR(B5/C5-1,)", "SUM($E:$E)", "L4+0.25%", "_xll.PsiNormal(C3,C4)"] {
            let ast = try FormulaParser.parse(formula)
            let written = FormulaSerializer.serialize(ast)
            let reparsed = try FormulaParser.parse(written)
            #expect(ast == reparsed, "\(formula) → \(written)")
        }
    }
}
