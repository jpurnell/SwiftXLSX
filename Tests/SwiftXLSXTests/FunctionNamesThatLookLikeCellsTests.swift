import XCTest
@testable import SwiftXLSX
import SwiftExcelCore

/// Function names that are **also valid cell references**.
///
/// ## The collision
///
/// `LOG10` is a function Excel has had since 1985. It is also a syntactically perfect cell
/// reference: column `LOG` (the 8,509th) and row `10`. The lexer, reading left to right with no
/// list of function names, saw letters then digits and emitted a cell.
///
/// The parser then did something reasonable with a cell followed by `(`: it built a *call on
/// that cell's contents*, the immediately-invoked form that `LAMBDA(x,x+1)(5)` needs. So
/// `LOG10(Data!B5)` parsed, serialized back out unchanged, and evaluated to `#VALUE!` — a
/// formula that survived every round trip and computed nothing.
///
/// Found on a real workbook: 300 cells of `LOG10(Data!B5)` transforming a data table for a
/// regression, every one reading zero against the values Excel had written beside them.
///
/// ## The rule
///
/// A cell reference immediately followed by `(` is a function name. Excel has no syntax for
/// calling a cell's contents — a stored `LAMBDA` is called through a defined name, and the
/// immediately-invoked form applies to a call's *result*, never to a bare reference. So there
/// is nothing to trade off: the reading that makes `LOG10(…)` work cannot break anything else.
///
/// **`$LOG$10(` stays a cell**, because a function name cannot carry `$` and a pinned
/// reference is unambiguous about being one.
final class FunctionNamesThatLookLikeCellsTests: XCTestCase {

    /// **The one that was found in the wild.**
    func testLog10IsAFunctionAndNotColumnLOGRow10() throws {
        let ast = try FormulaParser.parse("LOG10(A1)")
        guard case .function(let name, let arguments) = ast else {
            return XCTFail("parsed as \(ast) — a call on a cell, which Excel has no syntax for")
        }
        XCTAssertEqual(name, "LOG10")
        XCTAssertEqual(arguments.count, 1)
    }

    /// The cross-sheet form, which is how the corpus writes it.
    func testLog10AcrossASheet() throws {
        let ast = try FormulaParser.parse("LOG10(Data!B5)")
        guard case .function(let name, let arguments) = ast,
              case .sheetRef(let reference) = arguments.first else {
            return XCTFail("parsed as \(ast)")
        }
        XCTAssertEqual(name, "LOG10")
        XCTAssertEqual(reference.sheetName, "Data")
    }

    /// `ATAN2` collides the same way: column `ATAN`, row 2.
    func testAtan2IsAFunction() throws {
        let ast = try FormulaParser.parse("ATAN2(1,1)")
        guard case .function(let name, let arguments) = ast else {
            return XCTFail("parsed as \(ast)")
        }
        XCTAssertEqual(name, "ATAN2")
        XCTAssertEqual(arguments.count, 2)
    }

    /// It survives a round trip, which is what the app needs: a collected cell is serialized,
    /// `+PsiOutput()` appended, and the result parsed again.
    func testItSurvivesSerializingAndReparsing() throws {
        let first = try FormulaParser.parse("LOG10(Data!B5)")
        let text = FormulaSerializer.serialize(first)
        let again = try FormulaParser.parse(text + "+1")

        guard case .add(let left, _) = again, case .function(let name, _) = left else {
            return XCTFail("round trip produced \(again)")
        }
        XCTAssertEqual(name, "LOG10")
    }

    // MARK: - What must not change

    /// A pinned reference is a cell, whatever follows it. A function name cannot carry `$`.
    func testAPinnedReferenceIsStillACell() throws {
        let ast = try FormulaParser.parse("$LOG$10")
        guard case .cellRef(let ref) = ast else { return XCTFail("parsed as \(ast)") }
        XCTAssertTrue(ref.absoluteColumn)
        XCTAssertTrue(ref.absoluteRow)
    }

    /// A reference with nothing after it is a reference.
    func testABareReferenceIsStillACell() throws {
        guard case .cellRef = try FormulaParser.parse("LOG10") else {
            return XCTFail("a bare LOG10 is a cell — there is no call to make it a function")
        }
        guard case .multiply(.cellRef, .number(2)) = try FormulaParser.parse("LOG10*2") else {
            return XCTFail("and arithmetic on it reads it as a cell")
        }
    }

    /// The immediately-invoked lambda still works: it applies to a **call's result**, which is
    /// a different shape from a bare reference and is left alone.
    func testAnImmediatelyInvokedLambdaStillParses() throws {
        let ast = try FormulaParser.parse("LAMBDA(x,x+1)(5)")
        guard case .call(let callee, let arguments) = ast else {
            return XCTFail("parsed as \(ast)")
        }
        guard case .function("LAMBDA", _) = callee else {
            return XCTFail("callee is \(callee)")
        }
        XCTAssertEqual(arguments.count, 1)
    }

    /// An ordinary range is untouched.
    func testARangeIsUnaffected() throws {
        guard case .cellRange = try FormulaParser.parse("A1:B9") else {
            return XCTFail("a range is a range")
        }
    }
}
