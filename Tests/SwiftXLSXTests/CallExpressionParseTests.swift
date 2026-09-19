import Testing
import Foundation
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
@Suite
struct CallExpressionParseTests {

    private func parse(_ formula: String) throws -> FormulaAST {
        try FormulaParser.parse(formula)
    }

    // MARK: - The form

    @Test("An immediately invoked lambda parses")
    func testAnImmediatelyInvokedLambdaParses() throws {
        let ast = try parse("LAMBDA(x,x+1)(5)")
        guard case .call(let callee, let arguments) = ast else {
            Issue.record("expected a call, got \(ast)")
            return
        }
        guard case .function(let name, _) = callee else {
            Issue.record("expected the callee to be the LAMBDA")
            return
        }
        #expect(name.uppercased() == "LAMBDA")
        #expect(arguments == [.number(5)])
    }

    /// The shape the corpus writes, prefixes and all.
    @Test("The corpus shape parses")
    func testTheCorpusShapeParses() throws {
        let ast = try parse(
            "_xlfn.LAMBDA(_xlpm.f,_xlpm.n,IF(_xlpm.n<=0,0,1+_xlpm.f(_xlpm.f,_xlpm.n-1)))"
            + "(_xlfn.LAMBDA(_xlpm.f,_xlpm.n,0),4094)")
        guard case .call(_, let arguments) = ast else {
            Issue.record("expected a call, got \(ast)")
            return
        }
        #expect(arguments.count == 2)
        #expect(arguments.last == .number(4094))
    }

    @Test("A call on A parenthesised expression parses")
    func testACallOnAParenthesisedExpressionParses() throws {
        let ast = try parse("(LAMBDA(x,x*2))(21)")
        guard case .call(let callee, let arguments) = ast else {
            Issue.record("expected a call, got \(ast)")
            return
        }
        // The parentheses group and then disappear: what is called is the LAMBDA itself.
        guard case .function(let name, let parameters) = callee else {
            Issue.record("expected the callee to be the LAMBDA, got \(callee)")
            return
        }
        #expect(name.uppercased() == "LAMBDA")
        #expect(parameters == [.namedRange("x"), .multiply(.namedRange("x"), .number(2))])
        #expect(arguments == [.number(21)])
    }

    /// Currying: the second call has no name in front of it either.
    @Test("Calls chain")
    func testCallsChain() throws {
        let ast = try parse("LAMBDA(x,LAMBDA(y,x+y))(3)(4)")
        guard case .call(let inner, let outer) = ast, case .call = inner else {
            Issue.record("expected a call on a call, got \(ast)")
            return
        }
        #expect(outer == [.number(4)])
    }

    @Test("A call with no arguments")
    func testACallWithNoArguments() throws {
        let ast = try parse("LAMBDA(1)()")
        guard case .call(_, let arguments) = ast else { Issue.record("expected a call"); return }
        #expect(arguments.isEmpty)
    }

    // MARK: - What must not change

    /// An ordinary call is still `.function`, not a call on a name.
    ///
    /// The whole grammar downstream keys off that: the registry looks a name up, the
    /// serializer writes one. Turning `SUM(1,2)` into a call on `.namedRange("SUM")` would be
    /// a tidier grammar and a broken package.
    @Test("An ordinary call is unchanged")
    func testAnOrdinaryCallIsUnchanged() throws {
        guard case .function(let name, let arguments) = try parse("SUM(1,2)") else {
            Issue.record("expected a function")
            return
        }
        #expect(name == "SUM")
        #expect(arguments == [.number(1), .number(2)])
    }

    /// A parenthesised expression followed by an operator is not a call.
    @Test("Parentheses still group")
    func testParenthesesStillGroup() throws {
        #expect(try parse("(1+2)*3") == .multiply(.add(.number(1), .number(2)), .number(3)))
    }

    /// And a bare parenthesised expression is still itself.
    @Test("A bare group is unchanged")
    func testABareGroupIsUnchanged() throws {
        #expect(try parse("(1+2)") == .add(.number(1), .number(2)))
    }

    // MARK: - Round trip

    /// What is parsed is written back, or the round trip cannot be diffed.
    @Test("A call serializes back")
    func testACallSerializesBack() throws {
        for formula in ["LAMBDA(x,x+1)(5)",
                        "LAMBDA(x,LAMBDA(y,x+y))(3)(4)",
                        "LAMBDA(1)()"] {
            #expect(FormulaSerializer.serialize(try parse(formula)) == formula, "\(formula)")
        }
    }
}
