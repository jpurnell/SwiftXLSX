import XCTest
@testable import SwiftXLSX

final class FormulaSerializerTests: XCTestCase {

    // MARK: - Leaf Nodes

    func testCellRef() {
        let ast = FormulaAST.cellRef(CellRef("A1"))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1")
    }

    func testCellRefAbsolute() {
        let ref = CellRef("$B$5")
        let ast = FormulaAST.cellRef(ref)
        XCTAssertEqual(FormulaSerializer.serialize(ast), ref.reference)
    }

    func testCellRange() {
        let ast = FormulaAST.cellRange(CellRange("A1:B10"))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1:B10")
    }

    func testSheetRef() {
        let sheetRef = SheetReference(sheet: "Sheet 1", cell: CellRef("A1"))
        let ast = FormulaAST.sheetRef(sheetRef)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "'Sheet 1'!A1")
    }

    func testSheetRefSimpleName() {
        let sheetRef = SheetReference(sheet: "Data", cell: CellRef("C3"))
        let ast = FormulaAST.sheetRef(sheetRef)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "'Data'!C3")
    }

    func testNamedRange() {
        let ast = FormulaAST.namedRange("DiscountRate")
        XCTAssertEqual(FormulaSerializer.serialize(ast), "DiscountRate")
    }

    func testNumberInteger() {
        let ast = FormulaAST.number(42)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "42")
    }

    func testNumberDouble() {
        let ast = FormulaAST.number(3.14)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "3.14")
    }

    func testNumberSmallDecimal() {
        let ast = FormulaAST.number(0.065)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "0.065")
    }

    func testNumberNegativeInteger() {
        let ast = FormulaAST.number(-5)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "-5")
    }

    func testNumberZero() {
        let ast = FormulaAST.number(0)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "0")
    }

    func testNumberLargeValue() {
        let ast = FormulaAST.number(1_000_000)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "1000000")
    }

    func testText() {
        let ast = FormulaAST.text("hello")
        XCTAssertEqual(FormulaSerializer.serialize(ast), "\"hello\"")
    }

    func testTextEmpty() {
        let ast = FormulaAST.text("")
        XCTAssertEqual(FormulaSerializer.serialize(ast), "\"\"")
    }

    func testBoolTrue() {
        let ast = FormulaAST.bool(true)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "TRUE")
    }

    func testBoolFalse() {
        let ast = FormulaAST.bool(false)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "FALSE")
    }

    func testErrorDiv0() {
        let ast = FormulaAST.error(.div0)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "#DIV/0!")
    }

    func testErrorValue() {
        let ast = FormulaAST.error(.value)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "#VALUE!")
    }

    func testErrorRef() {
        let ast = FormulaAST.error(.ref)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "#REF!")
    }

    func testErrorNA() {
        let ast = FormulaAST.error(.na)
        XCTAssertEqual(FormulaSerializer.serialize(ast), "#N/A")
    }

    // MARK: - Simple Arithmetic Operations

    func testAdd() {
        let ast = FormulaAST.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1")))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1+B1")
    }

    func testSubtract() {
        let ast = FormulaAST.subtract(.number(10), .number(3))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "10-3")
    }

    func testMultiply() {
        let ast = FormulaAST.multiply(.cellRef(CellRef("A1")), .number(2))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1*2")
    }

    func testDivide() {
        let ast = FormulaAST.divide(.cellRef(CellRef("A1")), .number(12))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1/12")
    }

    func testPower() {
        let ast = FormulaAST.power(.cellRef(CellRef("A1")), .number(2))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1^2")
    }

    func testConcatenate() {
        let ast = FormulaAST.concatenate(.cellRef(CellRef("A1")), .text(" USD"))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1&\" USD\"")
    }

    // MARK: - Unary

    func testNegateCellRef() {
        let ast = FormulaAST.negate(.cellRef(CellRef("A1")))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "-A1")
    }

    func testNegateNumber() {
        let ast = FormulaAST.negate(.number(5))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "-5")
    }

    func testNegateAddNeedsParens() {
        let ast = FormulaAST.negate(.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "-(A1+B1)")
    }

    func testNegateMultiplyNeedsParens() {
        let ast = FormulaAST.negate(.multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "-(A1*B1)")
    }

    // MARK: - Comparison

    func testEqual() {
        let ast = FormulaAST.equal(.cellRef(CellRef("A1")), .number(100))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1=100")
    }

    func testNotEqual() {
        let ast = FormulaAST.notEqual(.cellRef(CellRef("A1")), .text(""))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1<>\"\"")
    }

    func testGreaterThan() {
        let ast = FormulaAST.greaterThan(.cellRef(CellRef("A1")), .number(100))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1>100")
    }

    func testLessThan() {
        let ast = FormulaAST.lessThan(.cellRef(CellRef("A1")), .number(0))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1<0")
    }

    func testGreaterOrEqual() {
        let ast = FormulaAST.greaterOrEqual(.cellRef(CellRef("A1")), .number(50))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1>=50")
    }

    func testLessOrEqual() {
        let ast = FormulaAST.lessOrEqual(.cellRef(CellRef("A1")), .number(100))
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1<=100")
    }

    // MARK: - Operator Precedence

    func testMultiplyWithAddChildNeedsParens() {
        let ast = FormulaAST.multiply(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1+B1)*C1")
    }

    func testAddWithMultiplyChildNoParens() {
        let ast = FormulaAST.add(
            .cellRef(CellRef("A1")),
            .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1+B1*C1")
    }

    func testAddWithMultiplyLeftChildNoParens() {
        let ast = FormulaAST.add(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1*B1+C1")
    }

    func testDivideWithSubtractChildNeedsParens() {
        let ast = FormulaAST.divide(
            .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1-B1)/C1")
    }

    func testPowerWithMultiplyChildNeedsParens() {
        let ast = FormulaAST.power(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .number(2)
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1*B1)^2")
    }

    func testComparisonWithAddChildNoParens() {
        let ast = FormulaAST.greaterThan(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1+B1>C1")
    }

    func testConcatenateWithAddChildNoParens() {
        let ast = FormulaAST.concatenate(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .text("text")
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1+B1&\"text\"")
    }

    func testAddWithConcatenateChildNeedsParens() {
        let ast = FormulaAST.add(
            .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1&B1)+C1")
    }

    func testNestedPrecedenceMultipleLevels() {
        let ast = FormulaAST.multiply(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .subtract(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1+B1)*(C1-D1)")
    }

    func testSamePrecedenceNoParens() {
        let ast = FormulaAST.subtract(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1+B1-C1")
    }

    func testSamePrecedenceMultiplyDivideNoParens() {
        let ast = FormulaAST.divide(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1*B1/C1")
    }

    // MARK: - Functions

    func testFunctionSUM() {
        let ast = FormulaAST.function("SUM", [.cellRange(CellRange("A1:A10"))])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "SUM(A1:A10)")
    }

    func testFunctionMultipleArgs() {
        let ast = FormulaAST.function("IF", [
            .greaterThan(.cellRef(CellRef("A1")), .number(100)),
            .text("high"),
            .text("low"),
        ])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "IF(A1>100,\"high\",\"low\")")
    }

    func testFunctionPMT() {
        let ast = FormulaAST.function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1"))),
        ])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "PMT(B2/12,B3,-B1)")
    }

    func testFunctionNoArgs() {
        let ast = FormulaAST.function("NOW", [])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "NOW()")
    }

    func testFunctionNested() {
        let ast = FormulaAST.function("SUM", [
            .cellRef(CellRef("A1")),
            .function("MAX", [.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))]),
        ])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "SUM(A1,MAX(B1,C1))")
    }

    // MARK: - Complex Expressions

    func testComplexPMTFormula() {
        let ast = FormulaAST.function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1"))),
        ])
        XCTAssertEqual(FormulaSerializer.serialize(ast), "PMT(B2/12,B3,-B1)")
    }

    func testComplexNestedArithmetic() {
        let ast = FormulaAST.divide(
            .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ),
            .cellRef(CellRef("D1"))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "(A1+B1)*C1/D1")
    }

    func testComplexComparisonWithArithmetic() {
        let ast = FormulaAST.greaterThan(
            .add(
                .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ),
            .divide(.cellRef(CellRef("D1")), .cellRef(CellRef("E1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1*B1+C1>D1/E1")
    }

    func testRightAssociativitySubtract() {
        let ast = FormulaAST.subtract(
            .cellRef(CellRef("A1")),
            .subtract(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1-(B1-C1)")
    }

    func testRightAssociativityDivide() {
        let ast = FormulaAST.divide(
            .cellRef(CellRef("A1")),
            .divide(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1/(B1/C1)")
    }

    func testRightAssociativityDivideRightMultiply() {
        let ast = FormulaAST.divide(
            .cellRef(CellRef("A1")),
            .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1/(B1*C1)")
    }

    func testRightAssociativitySubtractRightAdd() {
        let ast = FormulaAST.subtract(
            .cellRef(CellRef("A1")),
            .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        XCTAssertEqual(FormulaSerializer.serialize(ast), "A1-(B1+C1)")
    }
}
