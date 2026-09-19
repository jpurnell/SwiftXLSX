import Testing
import Foundation
@testable import SwiftXLSX

/// A whole row written without `$` — `1:1`.
///
/// The support existed and could never run: the case sat below `case .number(let value)` in
/// `parsePrimary`, and a `switch` takes the first case that matches. `1:1` lexes as a number,
/// matched there, and the colon became a parse error. Written, reviewed, dead.
///
/// Found from the other end — a conformance question, `COLUMNS(1:1)`, that could not even be
/// written into the workbook to ask Excel.
@Suite
struct WholeRowReferenceTests {

    private func range(_ formula: String) throws -> CellRange {
        let ast = try FormulaParser.parse(formula)
        guard case .cellRange(let range) = ast else {
            Issue.record("\(formula) parsed as \(ast), expected a range")
            throw FormulaParseError(kind: .unexpectedToken(expected: "range", found: "\(ast)"),
                                    offset: 0, formula: formula)
        }
        return range
    }

    @Test("A whole row parses")
    func testAWholeRowParses() throws {
        let single = try range("1:1")
        #expect(single.rowCount == 1)
        #expect(single.columnCount == 16384)
    }

    @Test("A span of rows parses")
    func testASpanOfRowsParses() throws {
        let span = try range("2:5")
        #expect(span.rowCount == 4)
        #expect(span.columnCount == 16384)
    }

    @Test("The order is normalised")
    func testTheOrderIsNormalised() throws {
        #expect(try range("5:2").rowCount == 4)
    }

    /// The `$` form already worked and must keep working.
    @Test("The absolute form still parses")
    func testTheAbsoluteFormStillParses() throws {
        #expect(try range("$3:$3").rowCount == 1)
    }

    /// A bare number is still a number — the rewind path.
    @Test("A plain number is unaffected")
    func testAPlainNumberIsUnaffected() throws {
        let ast = try FormulaParser.parse("1")
        guard case .number(let value) = ast else {
            Issue.record("1 parsed as \(ast)")
            return
        }
        #expect(value == 1)
    }

    @Test("Arithmetic with numbers is unaffected")
    func testArithmeticWithNumbersIsUnaffected() throws {
        let ast = try FormulaParser.parse("1+2*3")
        #expect(ast == .add(.number(1), .multiply(.number(2), .number(3))),
                "the colon path must not swallow a number, and * still binds tighter than +")
    }

    /// Past the grid's last row is not a row reference.
    @Test("Beyond the grid is not A row")
    func testBeyondTheGridIsNotARow() throws {
        let ast = try FormulaParser.parse("SUM(1:1048576)")
        #expect(ast == .function("SUM", [.cellRange(
            CellRange(from: CellRef(column: 1, row: 1),
                      to: CellRef(column: 16384, row: 1_048_576)))]),
                "the last row is still a row, so the whole span is a range across every column")
        #expect(throws: (any Error).self) { try FormulaParser.parse("1048577:1048577") }
    }
}
