import XCTest
@testable import SwiftXLSX
import SwiftExcelCore

/// A whole-column reference depends on the column's contents, not on a million
/// empty cells.
///
/// `$B:$G` names 6,291,456 cells. The corpus writes a whole-column range about
/// 135,000 times — 87,773 of them inside `VLOOKUP` alone — so enumerating them
/// would produce hundreds of billions of addresses and the graph would never
/// finish. Above ``DependencyGraph/exactEnumerationLimit`` the range is
/// intersected with the cells that exist instead.
final class DependencyGraphWholeColumnTests: XCTestCase {

    private func sheet(_ build: (Worksheet) -> Void) -> Worksheet {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        build(sheet)
        return sheet
    }

    /// The point of the whole exercise: this must terminate, and quickly.
    func testAWholeColumnSumDependsOnlyOnWhatIsInTheColumn() {
        let sheet = sheet { sheet in
            sheet.write(1.0, to: "A1")
            sheet.write(2.0, to: "A2")
            sheet.write(3.0, to: "A9000")
            sheet.write(FormulaAST.function("SUM", [.cellRange(
                CellRange(from: CellRef(column: 1, row: 1), to: CellRef(column: 1, row: 1_048_576))
            )]), to: "C1")
        }

        let graph = DependencyGraph(sheet: sheet)
        let precedents = graph.precedents(of: CellAddress(sheet: "Sheet1", ref: "C1"))

        XCTAssertEqual(precedents.count, 3, "A1, A2 and A9000 — not a million empties")
        XCTAssertEqual(Set(precedents.map(\.cell.reference)), ["A1", "A2", "A9000"])
    }

    /// Below the limit nothing changes, empty cells included. `A1:A5` names five
    /// cells whether or not anything is in them, and an evaluator still has to
    /// visit an empty one to learn it is zero.
    func testASmallRangeStillEnumeratesEmptyCells() {
        let sheet = sheet { sheet in
            sheet.write(1.0, to: "A1")
            sheet.write(FormulaAST.function("SUM", [.cellRange(
                CellRange(from: CellRef(column: 1, row: 1), to: CellRef(column: 1, row: 5))
            )]), to: "C1")
        }

        let graph = DependencyGraph(sheet: sheet)
        XCTAssertEqual(graph.precedents(of: CellAddress(sheet: "Sheet1", ref: "C1")).count, 5)
    }

    /// The bound applies to a range nested inside a call, which is where every
    /// real one appears — `SUMIFS(Sheet2!$E:$E, ...)` rather than a bare range.
    func testTheBoundAppliesInsideAFunctionCall() throws {
        let formula = try FormulaParser.parse("SUM($A:$A)")
        let sheet = sheet { sheet in
            sheet.write(5.0, to: "A3")
            sheet.write(formula, to: "C1")
        }

        let graph = DependencyGraph(sheet: sheet)
        let precedents = graph.precedents(of: CellAddress(sheet: "Sheet1", ref: "C1"))
        XCTAssertEqual(precedents.map(\.cell.reference), ["A3"])
    }

    func testAWholeColumnRangeParsesToTheFullColumn() throws {
        guard case .cellRange(let range) = try FormulaParser.parse("$E:$E") else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.start, CellRef(column: 5, row: 1))
        XCTAssertEqual(range.end, CellRef(column: 5, row: 1_048_576))
    }

    func testAWholeRowRangeSpansEveryColumn() throws {
        guard case .cellRange(let range) = try FormulaParser.parse("$2:$3") else {
            return XCTFail("expected a range")
        }
        XCTAssertEqual(range.start, CellRef(column: 1, row: 2))
        XCTAssertEqual(range.end, CellRef(column: 16_384, row: 3))
    }
}
