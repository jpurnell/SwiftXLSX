import XCTest
@testable import SwiftXLSX

final class FormulaASTTests: XCTestCase {

    // MARK: - Leaf Node Construction

    func testCellRefNode() {
        let node = FormulaAST.cellRef(CellRef("A1"))
        if case .cellRef(let ref) = node {
            XCTAssertEqual(ref.reference, "A1")
        } else {
            XCTFail("Expected .cellRef")
        }
    }

    func testCellRangeNode() {
        let node = FormulaAST.cellRange(CellRange(from: CellRef("A1"), to: CellRef("A10")))
        if case .cellRange(let range) = node {
            XCTAssertEqual(range.start.reference, "A1")
            XCTAssertEqual(range.end.reference, "A10")
        } else {
            XCTFail("Expected .cellRange")
        }
    }

    func testSheetRefNode() {
        let node = FormulaAST.sheetRef(SheetReference(sheet: "Summary", cell: CellRef("B2")))
        if case .sheetRef(let sheetRef) = node {
            XCTAssertEqual(sheetRef.sheetName, "Summary")
            XCTAssertEqual(sheetRef.range.start.reference, "B2")
        } else {
            XCTFail("Expected .sheetRef")
        }
    }

    func testNamedRangeNode() {
        let node = FormulaAST.namedRange("TotalRevenue")
        if case .namedRange(let name) = node {
            XCTAssertEqual(name, "TotalRevenue")
        } else {
            XCTFail("Expected .namedRange")
        }
    }

    func testNumberNode() {
        let node = FormulaAST.number(42.5)
        if case .number(let val) = node {
            XCTAssertEqual(val, 42.5)
        } else {
            XCTFail("Expected .number")
        }
    }

    func testTextNode() {
        let node = FormulaAST.text("Hello")
        if case .text(let val) = node {
            XCTAssertEqual(val, "Hello")
        } else {
            XCTFail("Expected .text")
        }
    }

    func testBoolNode() {
        let trueNode = FormulaAST.bool(true)
        let falseNode = FormulaAST.bool(false)
        if case .bool(let val) = trueNode {
            XCTAssertTrue(val)
        } else {
            XCTFail("Expected .bool")
        }
        if case .bool(let val) = falseNode {
            XCTAssertFalse(val)
        } else {
            XCTFail("Expected .bool")
        }
    }

    func testErrorNode() {
        let node = FormulaAST.error(.div0)
        if case .error(let e) = node {
            XCTAssertEqual(e, .div0)
        } else {
            XCTFail("Expected .error")
        }
    }

    // MARK: - Arithmetic Cases

    func testAddCase() {
        let node = FormulaAST.add(.number(1), .number(2))
        if case .add(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(1))
            XCTAssertEqual(rhs, .number(2))
        } else {
            XCTFail("Expected .add")
        }
    }

    func testSubtractCase() {
        let node = FormulaAST.subtract(.number(5), .number(3))
        if case .subtract(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(5))
            XCTAssertEqual(rhs, .number(3))
        } else {
            XCTFail("Expected .subtract")
        }
    }

    func testMultiplyCase() {
        let node = FormulaAST.multiply(.number(4), .number(6))
        if case .multiply(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(4))
            XCTAssertEqual(rhs, .number(6))
        } else {
            XCTFail("Expected .multiply")
        }
    }

    func testDivideCase() {
        let node = FormulaAST.divide(.number(10), .number(2))
        if case .divide(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(10))
            XCTAssertEqual(rhs, .number(2))
        } else {
            XCTFail("Expected .divide")
        }
    }

    func testPowerCase() {
        let node = FormulaAST.power(.number(2), .number(8))
        if case .power(let base, let exp) = node {
            XCTAssertEqual(base, .number(2))
            XCTAssertEqual(exp, .number(8))
        } else {
            XCTFail("Expected .power")
        }
    }

    func testNegateCase() {
        let node = FormulaAST.negate(.number(7))
        if case .negate(let inner) = node {
            XCTAssertEqual(inner, .number(7))
        } else {
            XCTFail("Expected .negate")
        }
    }

    func testConcatenateCase() {
        let node = FormulaAST.concatenate(.text("A"), .text("B"))
        if case .concatenate(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .text("A"))
            XCTAssertEqual(rhs, .text("B"))
        } else {
            XCTFail("Expected .concatenate")
        }
    }

    // MARK: - Comparison Cases

    func testEqualCase() {
        let node = FormulaAST.equal(.number(1), .number(1))
        if case .equal(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(1))
            XCTAssertEqual(rhs, .number(1))
        } else {
            XCTFail("Expected .equal")
        }
    }

    func testNotEqualCase() {
        let node = FormulaAST.notEqual(.number(1), .number(2))
        if case .notEqual(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(1))
            XCTAssertEqual(rhs, .number(2))
        } else {
            XCTFail("Expected .notEqual")
        }
    }

    func testGreaterThanCase() {
        let node = FormulaAST.greaterThan(.number(5), .number(3))
        if case .greaterThan(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(5))
            XCTAssertEqual(rhs, .number(3))
        } else {
            XCTFail("Expected .greaterThan")
        }
    }

    func testLessThanCase() {
        let node = FormulaAST.lessThan(.number(2), .number(7))
        if case .lessThan(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(2))
            XCTAssertEqual(rhs, .number(7))
        } else {
            XCTFail("Expected .lessThan")
        }
    }

    func testGreaterOrEqualCase() {
        let node = FormulaAST.greaterOrEqual(.number(5), .number(5))
        if case .greaterOrEqual(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(5))
            XCTAssertEqual(rhs, .number(5))
        } else {
            XCTFail("Expected .greaterOrEqual")
        }
    }

    func testLessOrEqualCase() {
        let node = FormulaAST.lessOrEqual(.number(3), .number(4))
        if case .lessOrEqual(let lhs, let rhs) = node {
            XCTAssertEqual(lhs, .number(3))
            XCTAssertEqual(rhs, .number(4))
        } else {
            XCTFail("Expected .lessOrEqual")
        }
    }

    // MARK: - Generic Function

    func testGenericFunction() {
        let node = FormulaAST.function("CUSTOM", [.number(1)])
        if case .function(let name, let args) = node {
            XCTAssertEqual(name, "CUSTOM")
            XCTAssertEqual(args.count, 1)
            XCTAssertEqual(args[0], .number(1))
        } else {
            XCTFail("Expected .function")
        }
    }

    // MARK: - Equatable

    func testEquatable_SameTreesAreEqual() {
        let tree1 = FormulaAST.add(.number(1), .multiply(.number(2), .number(3)))
        let tree2 = FormulaAST.add(.number(1), .multiply(.number(2), .number(3)))
        XCTAssertEqual(tree1, tree2)
    }

    func testEquatable_DifferentTreesAreNotEqual() {
        let tree1 = FormulaAST.add(.number(1), .number(2))
        let tree2 = FormulaAST.add(.number(1), .number(3))
        XCTAssertNotEqual(tree1, tree2)
    }

    func testEquatable_DifferentCases() {
        let tree1 = FormulaAST.add(.number(1), .number(2))
        let tree2 = FormulaAST.subtract(.number(1), .number(2))
        XCTAssertNotEqual(tree1, tree2)
    }

    // MARK: - Hashable

    func testHashable_CanBeUsedInSet() {
        let node1 = FormulaAST.number(1)
        let node2 = FormulaAST.number(2)
        let node3 = FormulaAST.number(1)
        let set: Set<FormulaAST> = [node1, node2, node3]
        XCTAssertEqual(set.count, 2)
    }

    func testHashable_ComplexNodesInSet() {
        let expr1 = FormulaAST.add(.number(1), .number(2))
        let expr2 = FormulaAST.add(.number(1), .number(2))
        let expr3 = FormulaAST.subtract(.number(1), .number(2))
        let set: Set<FormulaAST> = [expr1, expr2, expr3]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Recursive Construction

    func testRecursiveConstruction() {
        let node = FormulaAST.add(
            .multiply(.number(2), .cellRef(CellRef("A1"))),
            .number(5)
        )
        if case .add(let lhs, let rhs) = node {
            XCTAssertEqual(rhs, .number(5))
            if case .multiply(let a, let b) = lhs {
                XCTAssertEqual(a, .number(2))
                if case .cellRef(let ref) = b {
                    XCTAssertEqual(ref.reference, "A1")
                } else {
                    XCTFail("Expected .cellRef")
                }
            } else {
                XCTFail("Expected .multiply")
            }
        } else {
            XCTFail("Expected .add")
        }
    }

    // MARK: - Convenience Builders: Aggregation

    func testSumBuilder() {
        let range = FormulaAST.cellRange(CellRange("A1:A10"))
        let result = FormulaAST.sum(range)
        XCTAssertEqual(result, .function("SUM", [range]))
    }

    func testAverageBuilder() {
        let range = FormulaAST.cellRange(CellRange("B1:B20"))
        let result = FormulaAST.average(range)
        XCTAssertEqual(result, .function("AVERAGE", [range]))
    }

    func testCountBuilder() {
        let range = FormulaAST.cellRange(CellRange("C1:C50"))
        let result = FormulaAST.count(range)
        XCTAssertEqual(result, .function("COUNT", [range]))
    }

    func testMinBuilder() {
        let range = FormulaAST.cellRange(CellRange("D1:D10"))
        let result = FormulaAST.min(range)
        XCTAssertEqual(result, .function("MIN", [range]))
    }

    func testMaxBuilder() {
        let range = FormulaAST.cellRange(CellRange("E1:E10"))
        let result = FormulaAST.max(range)
        XCTAssertEqual(result, .function("MAX", [range]))
    }

    func testStdevBuilder() {
        let range = FormulaAST.cellRange(CellRange("F1:F100"))
        let result = FormulaAST.stdev(range)
        XCTAssertEqual(result, .function("STDEV", [range]))
    }

    func testMedianBuilder() {
        let range = FormulaAST.cellRange(CellRange("G1:G50"))
        let result = FormulaAST.median(range)
        XCTAssertEqual(result, .function("MEDIAN", [range]))
    }

    // MARK: - Convenience Builders: Financial

    func testPmtBuilder() {
        let result = FormulaAST.pmt(
            rate: .number(0.05),
            nper: .number(360),
            pv: .number(200_000)
        )
        XCTAssertEqual(result, .function("PMT", [.number(0.05), .number(360), .number(200_000)]))
    }

    func testIpmtBuilder() {
        let result = FormulaAST.ipmt(
            rate: .number(0.05),
            per: .number(1),
            nper: .number(360),
            pv: .number(200_000)
        )
        XCTAssertEqual(
            result,
            .function("IPMT", [.number(0.05), .number(1), .number(360), .number(200_000)])
        )
    }

    func testPpmtBuilder() {
        let result = FormulaAST.ppmt(
            rate: .number(0.05),
            per: .number(1),
            nper: .number(360),
            pv: .number(200_000)
        )
        XCTAssertEqual(
            result,
            .function("PPMT", [.number(0.05), .number(1), .number(360), .number(200_000)])
        )
    }

    func testNpvBuilder() {
        let values = FormulaAST.cellRange(CellRange("B1:B10"))
        let result = FormulaAST.npv(rate: .number(0.1), values: values)
        XCTAssertEqual(result, .function("NPV", [.number(0.1), values]))
    }

    func testIrrBuilderDefaultGuess() {
        let values = FormulaAST.cellRange(CellRange("C1:C10"))
        let result = FormulaAST.irr(values: values)
        XCTAssertEqual(result, .function("IRR", [values, .number(0.1)]))
    }

    func testIrrBuilderCustomGuess() {
        let values = FormulaAST.cellRange(CellRange("C1:C10"))
        let result = FormulaAST.irr(values: values, guess: .number(0.2))
        XCTAssertEqual(result, .function("IRR", [values, .number(0.2)]))
    }

    func testFvBuilder() {
        let result = FormulaAST.fv(
            rate: .number(0.08),
            nper: .number(10),
            pmt: .number(-1000)
        )
        XCTAssertEqual(result, .function("FV", [.number(0.08), .number(10), .number(-1000)]))
    }

    func testPvBuilder() {
        let result = FormulaAST.pv(
            rate: .number(0.06),
            nper: .number(20),
            pmt: .number(-500)
        )
        XCTAssertEqual(result, .function("PV", [.number(0.06), .number(20), .number(-500)]))
    }

    // MARK: - Convenience Builders: Statistical

    func testPercentileBuilder() {
        let range = FormulaAST.cellRange(CellRange("A1:A100"))
        let result = FormulaAST.percentile(range, k: .number(0.95))
        XCTAssertEqual(result, .function("PERCENTILE", [range, .number(0.95)]))
    }

    // MARK: - Convenience Builders: Logical

    func testIfBuilder() {
        let test = FormulaAST.greaterThan(.cellRef(CellRef("A1")), .number(100))
        let result = FormulaAST.if(test, then: .text("High"), else: .text("Low"))
        XCTAssertEqual(result, .function("IF", [test, .text("High"), .text("Low")]))
    }

    // MARK: - Convenience Builders: Lookup

    func testVlookupExactMatch() {
        let value = FormulaAST.cellRef(CellRef("A1"))
        let table = FormulaAST.cellRange(CellRange("D1:F100"))
        let result = FormulaAST.vlookup(
            value: value,
            table: table,
            col: .number(2),
            exactMatch: true
        )
        XCTAssertEqual(
            result,
            .function("VLOOKUP", [value, table, .number(2), .bool(false)])
        )
    }

    func testVlookupApproximateMatch() {
        let value = FormulaAST.cellRef(CellRef("A1"))
        let table = FormulaAST.cellRange(CellRange("D1:F100"))
        let result = FormulaAST.vlookup(
            value: value,
            table: table,
            col: .number(3),
            exactMatch: false
        )
        XCTAssertEqual(
            result,
            .function("VLOOKUP", [value, table, .number(3), .bool(true)])
        )
    }

    func testVlookupDefaultIsApproximateMatch() {
        let value = FormulaAST.cellRef(CellRef("A1"))
        let table = FormulaAST.cellRange(CellRange("D1:F100"))
        let result = FormulaAST.vlookup(
            value: value,
            table: table,
            col: .number(2)
        )
        XCTAssertEqual(
            result,
            .function("VLOOKUP", [value, table, .number(2), .bool(true)])
        )
    }
}
