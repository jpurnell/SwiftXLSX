import XCTest
@testable import SwiftXLSX

/// A whole row written without `$` — `1:1`.
///
/// The support existed and could never run: the case sat below `case .number(let value)` in
/// `parsePrimary`, and a `switch` takes the first case that matches. `1:1` lexes as a number,
/// matched there, and the colon became a parse error. Written, reviewed, dead.
///
/// Found from the other end — a conformance question, `COLUMNS(1:1)`, that could not even be
/// written into the workbook to ask Excel.
final class WholeRowReferenceTests: XCTestCase {

    private func range(_ formula: String) throws -> CellRange {
        let ast = try FormulaParser.parse(formula)
        guard case .cellRange(let range) = ast else {
            XCTFail("\(formula) parsed as \(ast), expected a range")
            throw FormulaParseError(kind: .unexpectedToken(expected: "range", found: "\(ast)"),
                                    offset: 0, formula: formula)
        }
        return range
    }

    func testAWholeRowParses() throws {
        let single = try range("1:1")
        XCTAssertEqual(single.rowCount, 1)
        XCTAssertEqual(single.columnCount, 16384)
    }

    func testASpanOfRowsParses() throws {
        let span = try range("2:5")
        XCTAssertEqual(span.rowCount, 4)
        XCTAssertEqual(span.columnCount, 16384)
    }

    func testTheOrderIsNormalised() throws {
        XCTAssertEqual(try range("5:2").rowCount, 4)
    }

    /// The `$` form already worked and must keep working.
    func testTheAbsoluteFormStillParses() throws {
        XCTAssertEqual(try range("$3:$3").rowCount, 1)
    }

    /// A bare number is still a number — the rewind path.
    func testAPlainNumberIsUnaffected() throws {
        let ast = try FormulaParser.parse("1")
        guard case .number(let value) = ast else {
            return XCTFail("1 parsed as \(ast)")
        }
        XCTAssertEqual(value, 1)
    }

    func testArithmeticWithNumbersIsUnaffected() throws {
        let ast = try FormulaParser.parse("1+2*3")
        XCTAssertNotNil(ast)
    }

    /// Past the grid's last row is not a row reference.
    func testBeyondTheGridIsNotARow() throws {
        let ast = try FormulaParser.parse("SUM(1:1048576)")
        XCTAssertNotNil(ast)
        XCTAssertThrowsError(try FormulaParser.parse("1048577:1048577"))
    }
}
