import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FormulaSerializerTests {

    // MARK: - Leaf Nodes

    @Test("Cell ref")
    func testCellRef() {
        let ast = FormulaAST.cellRef(CellRef("A1"))
        #expect(FormulaSerializer.serialize(ast) == "A1")
    }

    @Test("Cell ref absolute")
    func testCellRefAbsolute() {
        let ref = CellRef("$B$5")
        let ast = FormulaAST.cellRef(ref)
        #expect(FormulaSerializer.serialize(ast) == ref.reference)
    }

    @Test("Cell range")
    func testCellRange() {
        let ast = FormulaAST.cellRange(CellRange("A1:B10"))
        #expect(FormulaSerializer.serialize(ast) == "A1:B10")
    }

    @Test("Sheet ref")
    func testSheetRef() {
        let sheetRef = SheetReference(sheet: "Sheet 1", cell: CellRef("A1"))
        let ast = FormulaAST.sheetRef(sheetRef)
        #expect(FormulaSerializer.serialize(ast) == "'Sheet 1'!A1")
    }

    @Test("Sheet ref simple name")
    func testSheetRefSimpleName() {
        let sheetRef = SheetReference(sheet: "Data", cell: CellRef("C3"))
        let ast = FormulaAST.sheetRef(sheetRef)
        #expect(FormulaSerializer.serialize(ast) == "'Data'!C3")
    }

    @Test("Named range")
    func testNamedRange() {
        let ast = FormulaAST.namedRange("DiscountRate")
        #expect(FormulaSerializer.serialize(ast) == "DiscountRate")
    }

    @Test("Number integer")
    func testNumberInteger() {
        let ast = FormulaAST.number(42)
        #expect(FormulaSerializer.serialize(ast) == "42")
    }

    @Test("Number double")
    func testNumberDouble() {
        let ast = FormulaAST.number(3.14)
        #expect(FormulaSerializer.serialize(ast) == "3.14")
    }

    @Test("Number small decimal")
    func testNumberSmallDecimal() {
        let ast = FormulaAST.number(0.065)
        #expect(FormulaSerializer.serialize(ast) == "0.065")
    }

    @Test("Number negative integer")
    func testNumberNegativeInteger() {
        let ast = FormulaAST.number(-5)
        #expect(FormulaSerializer.serialize(ast) == "-5")
    }

    @Test("Number zero")
    func testNumberZero() {
        let ast = FormulaAST.number(0)
        #expect(FormulaSerializer.serialize(ast) == "0")
    }

    @Test("Number large value")
    func testNumberLargeValue() {
        let ast = FormulaAST.number(1_000_000)
        #expect(FormulaSerializer.serialize(ast) == "1000000")
    }

    @Test("Text")
    func testText() {
        let ast = FormulaAST.text("hello")
        #expect(FormulaSerializer.serialize(ast) == "\"hello\"")
    }

    @Test("Text empty")
    func testTextEmpty() {
        let ast = FormulaAST.text("")
        #expect(FormulaSerializer.serialize(ast) == "\"\"")
    }

    @Test("Bool true")
    func testBoolTrue() {
        let ast = FormulaAST.bool(true)
        #expect(FormulaSerializer.serialize(ast) == "TRUE")
    }

    @Test("Bool false")
    func testBoolFalse() {
        let ast = FormulaAST.bool(false)
        #expect(FormulaSerializer.serialize(ast) == "FALSE")
    }

    @Test("Error div0")
    func testErrorDiv0() {
        let ast = FormulaAST.error(.div0)
        #expect(FormulaSerializer.serialize(ast) == "#DIV/0!")
    }

    @Test("Error value")
    func testErrorValue() {
        let ast = FormulaAST.error(.value)
        #expect(FormulaSerializer.serialize(ast) == "#VALUE!")
    }

    @Test("Error ref")
    func testErrorRef() {
        let ast = FormulaAST.error(.ref)
        #expect(FormulaSerializer.serialize(ast) == "#REF!")
    }

    @Test("Error NA")
    func testErrorNA() {
        let ast = FormulaAST.error(.na)
        #expect(FormulaSerializer.serialize(ast) == "#N/A")
    }

    // MARK: - Simple Arithmetic Operations

    @Test("Add")
    func testAdd() {
        let ast = FormulaAST.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1")))
        #expect(FormulaSerializer.serialize(ast) == "A1+B1")
    }

    @Test("Subtract")
    func testSubtract() {
        let ast = FormulaAST.subtract(.number(10), .number(3))
        #expect(FormulaSerializer.serialize(ast) == "10-3")
    }

    @Test("Multiply")
    func testMultiply() {
        let ast = FormulaAST.multiply(.cellRef(CellRef("A1")), .number(2))
        #expect(FormulaSerializer.serialize(ast) == "A1*2")
    }

    @Test("Divide")
    func testDivide() {
        let ast = FormulaAST.divide(.cellRef(CellRef("A1")), .number(12))
        #expect(FormulaSerializer.serialize(ast) == "A1/12")
    }

    @Test("Power")
    func testPower() {
        let ast = FormulaAST.power(.cellRef(CellRef("A1")), .number(2))
        #expect(FormulaSerializer.serialize(ast) == "A1^2")
    }

    @Test("Concatenate")
    func testConcatenate() {
        let ast = FormulaAST.concatenate(.cellRef(CellRef("A1")), .text(" USD"))
        #expect(FormulaSerializer.serialize(ast) == "A1&\" USD\"")
    }

    // MARK: - Unary

    @Test("Negate cell ref")
    func testNegateCellRef() {
        let ast = FormulaAST.negate(.cellRef(CellRef("A1")))
        #expect(FormulaSerializer.serialize(ast) == "-A1")
    }

    @Test("Negate number")
    func testNegateNumber() {
        let ast = FormulaAST.negate(.number(5))
        #expect(FormulaSerializer.serialize(ast) == "-5")
    }

    @Test("Negate add needs parens")
    func testNegateAddNeedsParens() {
        let ast = FormulaAST.negate(.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
        #expect(FormulaSerializer.serialize(ast) == "-(A1+B1)")
    }

    @Test("Negate multiply needs parens")
    func testNegateMultiplyNeedsParens() {
        let ast = FormulaAST.negate(.multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
        #expect(FormulaSerializer.serialize(ast) == "-(A1*B1)")
    }

    // MARK: - Comparison

    @Test("Equal")
    func testEqual() {
        let ast = FormulaAST.equal(.cellRef(CellRef("A1")), .number(100))
        #expect(FormulaSerializer.serialize(ast) == "A1=100")
    }

    @Test("Not equal")
    func testNotEqual() {
        let ast = FormulaAST.notEqual(.cellRef(CellRef("A1")), .text(""))
        #expect(FormulaSerializer.serialize(ast) == "A1<>\"\"")
    }

    @Test("Greater than")
    func testGreaterThan() {
        let ast = FormulaAST.greaterThan(.cellRef(CellRef("A1")), .number(100))
        #expect(FormulaSerializer.serialize(ast) == "A1>100")
    }

    @Test("Less than")
    func testLessThan() {
        let ast = FormulaAST.lessThan(.cellRef(CellRef("A1")), .number(0))
        #expect(FormulaSerializer.serialize(ast) == "A1<0")
    }

    @Test("Greater or equal")
    func testGreaterOrEqual() {
        let ast = FormulaAST.greaterOrEqual(.cellRef(CellRef("A1")), .number(50))
        #expect(FormulaSerializer.serialize(ast) == "A1>=50")
    }

    @Test("Less or equal")
    func testLessOrEqual() {
        let ast = FormulaAST.lessOrEqual(.cellRef(CellRef("A1")), .number(100))
        #expect(FormulaSerializer.serialize(ast) == "A1<=100")
    }

    // MARK: - Operator Precedence

    @Test("Multiply with add child needs parens")
    func testMultiplyWithAddChildNeedsParens() {
        let ast = FormulaAST.multiply(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1+B1)*C1")
    }

    @Test("Add with multiply child no parens")
    func testAddWithMultiplyChildNoParens() {
        let ast = FormulaAST.add(
            .cellRef(CellRef("A1")),
            .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1+B1*C1")
    }

    @Test("Add with multiply left child no parens")
    func testAddWithMultiplyLeftChildNoParens() {
        let ast = FormulaAST.add(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1*B1+C1")
    }

    @Test("Divide with subtract child needs parens")
    func testDivideWithSubtractChildNeedsParens() {
        let ast = FormulaAST.divide(
            .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1-B1)/C1")
    }

    @Test("Power with multiply child needs parens")
    func testPowerWithMultiplyChildNeedsParens() {
        let ast = FormulaAST.power(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .number(2)
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1*B1)^2")
    }

    @Test("Comparison with add child no parens")
    func testComparisonWithAddChildNoParens() {
        let ast = FormulaAST.greaterThan(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1+B1>C1")
    }

    @Test("Concatenate with add child no parens")
    func testConcatenateWithAddChildNoParens() {
        let ast = FormulaAST.concatenate(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .text("text")
        )
        #expect(FormulaSerializer.serialize(ast) == "A1+B1&\"text\"")
    }

    @Test("Add with concatenate child needs parens")
    func testAddWithConcatenateChildNeedsParens() {
        let ast = FormulaAST.add(
            .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1&B1)+C1")
    }

    @Test("Nested precedence multiple levels")
    func testNestedPrecedenceMultipleLevels() {
        let ast = FormulaAST.multiply(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .subtract(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1+B1)*(C1-D1)")
    }

    @Test("Same precedence no parens")
    func testSamePrecedenceNoParens() {
        let ast = FormulaAST.subtract(
            .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1+B1-C1")
    }

    @Test("Same precedence multiply divide no parens")
    func testSamePrecedenceMultiplyDivideNoParens() {
        let ast = FormulaAST.divide(
            .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
            .cellRef(CellRef("C1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1*B1/C1")
    }

    // MARK: - Functions

    @Test("Function SUM")
    func testFunctionSUM() {
        let ast = FormulaAST.function("SUM", [.cellRange(CellRange("A1:A10"))])
        #expect(FormulaSerializer.serialize(ast) == "SUM(A1:A10)")
    }

    @Test("Function multiple args")
    func testFunctionMultipleArgs() {
        let ast = FormulaAST.function("IF", [
            .greaterThan(.cellRef(CellRef("A1")), .number(100)),
            .text("high"),
            .text("low"),
        ])
        #expect(FormulaSerializer.serialize(ast) == "IF(A1>100,\"high\",\"low\")")
    }

    @Test("Function PMT")
    func testFunctionPMT() {
        let ast = FormulaAST.function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1"))),
        ])
        #expect(FormulaSerializer.serialize(ast) == "PMT(B2/12,B3,-B1)")
    }

    @Test("Function no args")
    func testFunctionNoArgs() {
        let ast = FormulaAST.function("NOW", [])
        #expect(FormulaSerializer.serialize(ast) == "NOW()")
    }

    @Test("Function nested")
    func testFunctionNested() {
        let ast = FormulaAST.function("SUM", [
            .cellRef(CellRef("A1")),
            .function("MAX", [.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))]),
        ])
        #expect(FormulaSerializer.serialize(ast) == "SUM(A1,MAX(B1,C1))")
    }

    // MARK: - Complex Expressions

    @Test("Complex PMT formula")
    func testComplexPMTFormula() {
        let ast = FormulaAST.function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1"))),
        ])
        #expect(FormulaSerializer.serialize(ast) == "PMT(B2/12,B3,-B1)")
    }

    @Test("Complex nested arithmetic")
    func testComplexNestedArithmetic() {
        let ast = FormulaAST.divide(
            .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ),
            .cellRef(CellRef("D1"))
        )
        #expect(FormulaSerializer.serialize(ast) == "(A1+B1)*C1/D1")
    }

    @Test("Complex comparison with arithmetic")
    func testComplexComparisonWithArithmetic() {
        let ast = FormulaAST.greaterThan(
            .add(
                .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ),
            .divide(.cellRef(CellRef("D1")), .cellRef(CellRef("E1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1*B1+C1>D1/E1")
    }

    @Test("Right associativity subtract")
    func testRightAssociativitySubtract() {
        let ast = FormulaAST.subtract(
            .cellRef(CellRef("A1")),
            .subtract(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1-(B1-C1)")
    }

    @Test("Right associativity divide")
    func testRightAssociativityDivide() {
        let ast = FormulaAST.divide(
            .cellRef(CellRef("A1")),
            .divide(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1/(B1/C1)")
    }

    @Test("Right associativity divide right multiply")
    func testRightAssociativityDivideRightMultiply() {
        let ast = FormulaAST.divide(
            .cellRef(CellRef("A1")),
            .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1/(B1*C1)")
    }

    @Test("Right associativity subtract right add")
    func testRightAssociativitySubtractRightAdd() {
        let ast = FormulaAST.subtract(
            .cellRef(CellRef("A1")),
            .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))
        )
        #expect(FormulaSerializer.serialize(ast) == "A1-(B1+C1)")
    }
}
