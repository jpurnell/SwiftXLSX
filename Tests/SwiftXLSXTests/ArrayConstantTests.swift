import Testing
import Foundation
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
@Suite
struct ArrayConstantTests {

    private func parse(_ formula: String) throws -> FormulaAST {
        try FormulaParser.parse(formula)
    }

    private func rows(_ formula: String) throws -> [[FormulaAST]] {
        let ast = try parse(formula)
        guard case .arrayConstant(let rows) = ast else {
            Issue.record("\(formula) parsed as \(ast), expected an array constant")
            return []
        }
        return rows
    }

    // MARK: - Shape

    @Test("A single row")
    func testASingleRow() throws {
        #expect(try rows("{1,2,3}") == [[.number(1), .number(2), .number(3)]])
    }

    @Test("Two rows")
    func testTwoRows() throws {
        #expect(try rows("{1,2,3;4,5,6}") == [[.number(1), .number(2), .number(3)],
                        [.number(4), .number(5), .number(6)]])
    }

    @Test("A single column")
    func testASingleColumn() throws {
        #expect(try rows("{1;2;3}") == [[.number(1)], [.number(2)], [.number(3)]])
    }

    @Test("One element")
    func testOneElement() throws {
        #expect(try rows("{7}") == [[.number(7)]])
    }

    // MARK: - What may go inside

    @Test("Text booleans and errors")
    func testTextBooleansAndErrors() throws {
        #expect(try rows("{\"a\",\"b\"}") == [[.text("a"), .text("b")]])
        #expect(try rows("{TRUE,FALSE}") == [[.bool(true), .bool(false)]])
        #expect(try rows("{#N/A,#DIV/0!}") == [[.error(.na), .error(.div0)]])
    }

    /// A negative number arrives as a minus and a number, and is folded.
    ///
    /// Kept as `.number(-1)` rather than `.negate(.number(1))` so that an element of an array
    /// constant is always a literal — which is what makes "only constants go inside" a
    /// statement about the tree and not only about the grammar.
    @Test("Negative numbers are folded")
    func testNegativeNumbersAreFolded() throws {
        #expect(try rows("{-1,2,-3.5}") == [[.number(-1), .number(2), .number(-3.5)]])
    }

    @Test("A mixed array")
    func testAMixedArray() throws {
        #expect(try rows("{1,\"a\";TRUE,#N/A}") == [[.number(1), .text("a")], [.bool(true), .error(.na)]])
    }

    // MARK: - What may not

    /// Excel refuses a ragged constant outright — it is a syntax error, not a hole.
    @Test("Ragged rows are refused")
    func testRaggedRowsAreRefused() {
        #expect(throws: (any Error).self) { try parse("{1,2;3}") }
        #expect(throws: (any Error).self) { try parse("{1;2,3}") }
    }

    @Test("References are refused")
    func testReferencesAreRefused() {
        #expect(throws: (any Error).self) { try parse("{A1,2}") }
        #expect(throws: (any Error).self) { try parse("{A1:B2}") }
    }

    @Test("Function calls and names are refused")
    func testFunctionCallsAndNamesAreRefused() {
        #expect(throws: (any Error).self) { try parse("{SUM(1),2}") }
        #expect(throws: (any Error).self) { try parse("{MyName,2}") }
    }

    @Test("Nested arrays are refused")
    func testNestedArraysAreRefused() {
        #expect(throws: (any Error).self) { try parse("{{1,2},3}") }
    }

    @Test("An empty array is refused")
    func testAnEmptyArrayIsRefused() {
        #expect(throws: (any Error).self) { try parse("{}") }
    }

    @Test("An unclosed array is refused")
    func testAnUnclosedArrayIsRefused() {
        #expect(throws: (any Error).self) { try parse("{1,2") }
    }

    // MARK: - In context

    @Test("As A function argument")
    func testAsAFunctionArgument() throws {
        let ast = try parse("SUM({1,2,3})")
        guard case .function("SUM", let args) = ast, args.count == 1 else {
            Issue.record("parsed as \(ast)")
            return
        }
        #expect(args[0] == .arrayConstant([[.number(1), .number(2), .number(3)]]))
    }

    @Test("Two arrays as arguments")
    func testTwoArraysAsArguments() throws {
        let ast = try parse("SUMPRODUCT({1,2},{3,4})")
        guard case .function("SUMPRODUCT", let args) = ast, args.count == 2 else {
            Issue.record("parsed as \(ast)")
            return
        }
        #expect(args[0] == .arrayConstant([[.number(1), .number(2)]]))
        #expect(args[1] == .arrayConstant([[.number(3), .number(4)]]))
    }

    // MARK: - Round trip

    /// The serializer writes what the parser reads, which is what the corpus round trip needs.
    @Test("Round trip")
    func testRoundTrip() throws {
        for formula in ["{1,2,3}", "{1,2,3;4,5,6}", "{1;2;3}", "{7}",
                        "{-1,2,-3.5}", "{TRUE,FALSE}", "SUM({1,2,3})",
                        "{1,\"a\";TRUE,#N/A}"] {
            let once = FormulaSerializer.serialize(try parse(formula))
            #expect(once == formula, "serializing \(formula)")
            // And again, so a formula that changed shape on the first pass is caught.
            #expect(FormulaSerializer.serialize(try parse(once)) == once)
        }
    }
}
