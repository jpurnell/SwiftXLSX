import XCTest
@testable import SwiftXLSX
import SwiftExcelCore

/// Array constants — `{1,2,3;4,5,6}`.
///
/// The lexer had no `{`, `}` or `;` token at all, so the first brace ended parsing and the
/// gap looked like a decision nobody had got to. It was not one; it was simply missing.
///
/// A comma separates columns and a semicolon separates rows. Those are the **file format's**
/// separators, not the user's: a workbook saved in a locale that displays `\` between rows
/// still holds `;` in the XML, so `;` is the only spelling a reader ever sees.
final class ArrayConstantTests: XCTestCase {

    private func parse(_ formula: String) throws -> FormulaAST {
        try FormulaParser.parse(formula)
    }

    private func rows(_ formula: String) throws -> [[FormulaAST]] {
        let ast = try parse(formula)
        guard case .arrayConstant(let rows) = ast else {
            XCTFail("\(formula) parsed as \(ast), expected an array constant")
            return []
        }
        return rows
    }

    // MARK: - Shape

    func testASingleRow() throws {
        XCTAssertEqual(try rows("{1,2,3}"), [[.number(1), .number(2), .number(3)]])
    }

    func testTwoRows() throws {
        XCTAssertEqual(try rows("{1,2,3;4,5,6}"),
                       [[.number(1), .number(2), .number(3)],
                        [.number(4), .number(5), .number(6)]])
    }

    func testASingleColumn() throws {
        XCTAssertEqual(try rows("{1;2;3}"), [[.number(1)], [.number(2)], [.number(3)]])
    }

    func testOneElement() throws {
        XCTAssertEqual(try rows("{7}"), [[.number(7)]])
    }

    // MARK: - What may go inside

    func testTextBooleansAndErrors() throws {
        XCTAssertEqual(try rows("{\"a\",\"b\"}"), [[.text("a"), .text("b")]])
        XCTAssertEqual(try rows("{TRUE,FALSE}"), [[.bool(true), .bool(false)]])
        XCTAssertEqual(try rows("{#N/A,#DIV/0!}"), [[.error(.na), .error(.div0)]])
    }

    /// A negative number arrives as a minus and a number, and is folded.
    ///
    /// Kept as `.number(-1)` rather than `.negate(.number(1))` so that an element of an array
    /// constant is always a literal — which is what makes "only constants go inside" a
    /// statement about the tree and not only about the grammar.
    func testNegativeNumbersAreFolded() throws {
        XCTAssertEqual(try rows("{-1,2,-3.5}"),
                       [[.number(-1), .number(2), .number(-3.5)]])
    }

    func testAMixedArray() throws {
        XCTAssertEqual(try rows("{1,\"a\";TRUE,#N/A}"),
                       [[.number(1), .text("a")], [.bool(true), .error(.na)]])
    }

    // MARK: - What may not

    /// Excel refuses a ragged constant outright — it is a syntax error, not a hole.
    func testRaggedRowsAreRefused() {
        XCTAssertThrowsError(try parse("{1,2;3}"))
        XCTAssertThrowsError(try parse("{1;2,3}"))
    }

    func testReferencesAreRefused() {
        XCTAssertThrowsError(try parse("{A1,2}"))
        XCTAssertThrowsError(try parse("{A1:B2}"))
    }

    func testFunctionCallsAndNamesAreRefused() {
        XCTAssertThrowsError(try parse("{SUM(1),2}"))
        XCTAssertThrowsError(try parse("{MyName,2}"))
    }

    func testNestedArraysAreRefused() {
        XCTAssertThrowsError(try parse("{{1,2},3}"))
    }

    func testAnEmptyArrayIsRefused() {
        XCTAssertThrowsError(try parse("{}"))
    }

    func testAnUnclosedArrayIsRefused() {
        XCTAssertThrowsError(try parse("{1,2"))
    }

    // MARK: - In context

    func testAsAFunctionArgument() throws {
        let ast = try parse("SUM({1,2,3})")
        guard case .function("SUM", let args) = ast, args.count == 1 else {
            return XCTFail("parsed as \(ast)")
        }
        XCTAssertEqual(args[0], .arrayConstant([[.number(1), .number(2), .number(3)]]))
    }

    func testTwoArraysAsArguments() throws {
        let ast = try parse("SUMPRODUCT({1,2},{3,4})")
        guard case .function("SUMPRODUCT", let args) = ast, args.count == 2 else {
            return XCTFail("parsed as \(ast)")
        }
        XCTAssertEqual(args[0], .arrayConstant([[.number(1), .number(2)]]))
        XCTAssertEqual(args[1], .arrayConstant([[.number(3), .number(4)]]))
    }

    // MARK: - Round trip

    /// The serializer writes what the parser reads, which is what the corpus round trip needs.
    func testRoundTrip() throws {
        for formula in ["{1,2,3}", "{1,2,3;4,5,6}", "{1;2;3}", "{7}",
                        "{-1,2,-3.5}", "{TRUE,FALSE}", "SUM({1,2,3})",
                        "{1,\"a\";TRUE,#N/A}"] {
            let once = FormulaSerializer.serialize(try parse(formula))
            XCTAssertEqual(once, formula, "serializing \(formula)")
            // And again, so a formula that changed shape on the first pass is caught.
            XCTAssertEqual(FormulaSerializer.serialize(try parse(once)), once)
        }
    }
}
