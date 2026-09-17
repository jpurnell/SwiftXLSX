import XCTest
import SwiftExcelCore
@testable import SwiftXLSX

/// `LAMBDA(…)(args)` — a call on something that is not a name.
///
/// The last of the three `LAMBDA` shapes the corpus contains, and the only one the parser
/// could not read. It reported
///
/// ```
/// unexpectedToken(expected: "end of expression", found: "(")
/// ```
///
/// which is the grammar saying a call must begin with an identifier.
///
/// The form matters more than its rarity suggests. A `LAMBDA` cannot call itself by name
/// without a defined name, and adding one is a manual step — two conformance rounds were lost
/// to a `depthProbe` nobody had added, each reporting *first refused: 1* for a limit that
/// cannot refuse at depth 1. Self-application is how a recursive lambda is written with
/// nothing added to the file, and it is what finally measured Excel's 4,096.
final class CallExpressionParseTests: XCTestCase {

    private func parse(_ formula: String) throws -> FormulaAST {
        try FormulaParser.parse(formula)
    }

    // MARK: - The form

    func testAnImmediatelyInvokedLambdaParses() throws {
        let ast = try parse("LAMBDA(x,x+1)(5)")
        guard case .call(let callee, let arguments) = ast else {
            return XCTFail("expected a call, got \(ast)")
        }
        guard case .function(let name, _) = callee else {
            return XCTFail("expected the callee to be the LAMBDA")
        }
        XCTAssertEqual(name.uppercased(), "LAMBDA")
        XCTAssertEqual(arguments, [.number(5)])
    }

    /// The shape the corpus writes, prefixes and all.
    func testTheCorpusShapeParses() throws {
        let ast = try parse(
            "_xlfn.LAMBDA(_xlpm.f,_xlpm.n,IF(_xlpm.n<=0,0,1+_xlpm.f(_xlpm.f,_xlpm.n-1)))"
            + "(_xlfn.LAMBDA(_xlpm.f,_xlpm.n,0),4094)")
        guard case .call(_, let arguments) = ast else {
            return XCTFail("expected a call, got \(ast)")
        }
        XCTAssertEqual(arguments.count, 2)
        XCTAssertEqual(arguments.last, .number(4094))
    }

    func testACallOnAParenthesisedExpressionParses() throws {
        let ast = try parse("(LAMBDA(x,x*2))(21)")
        guard case .call = ast else { return XCTFail("expected a call, got \(ast)") }
    }

    /// Currying: the second call has no name in front of it either.
    func testCallsChain() throws {
        let ast = try parse("LAMBDA(x,LAMBDA(y,x+y))(3)(4)")
        guard case .call(let inner, let outer) = ast, case .call = inner else {
            return XCTFail("expected a call on a call, got \(ast)")
        }
        XCTAssertEqual(outer, [.number(4)])
    }

    func testACallWithNoArguments() throws {
        let ast = try parse("LAMBDA(1)()")
        guard case .call(_, let arguments) = ast else { return XCTFail("expected a call") }
        XCTAssertTrue(arguments.isEmpty)
    }

    // MARK: - What must not change

    /// An ordinary call is still `.function`, not a call on a name.
    ///
    /// The whole grammar downstream keys off that: the registry looks a name up, the
    /// serializer writes one. Turning `SUM(1,2)` into a call on `.namedRange("SUM")` would be
    /// a tidier grammar and a broken package.
    func testAnOrdinaryCallIsUnchanged() throws {
        guard case .function(let name, let arguments) = try parse("SUM(1,2)") else {
            return XCTFail("expected a function")
        }
        XCTAssertEqual(name, "SUM")
        XCTAssertEqual(arguments, [.number(1), .number(2)])
    }

    /// A parenthesised expression followed by an operator is not a call.
    func testParenthesesStillGroup() throws {
        XCTAssertEqual(try parse("(1+2)*3"),
                       .multiply(.add(.number(1), .number(2)), .number(3)))
    }

    /// And a bare parenthesised expression is still itself.
    func testABareGroupIsUnchanged() throws {
        XCTAssertEqual(try parse("(1+2)"), .add(.number(1), .number(2)))
    }

    // MARK: - Round trip

    /// What is parsed is written back, or the round trip cannot be diffed.
    func testACallSerializesBack() throws {
        for formula in ["LAMBDA(x,x+1)(5)",
                        "LAMBDA(x,LAMBDA(y,x+y))(3)(4)",
                        "LAMBDA(1)()"] {
            XCTAssertEqual(FormulaSerializer.serialize(try parse(formula)), formula, formula)
        }
    }
}
