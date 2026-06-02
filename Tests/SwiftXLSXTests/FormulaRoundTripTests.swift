import XCTest
@testable import SwiftXLSX

final class FormulaRoundTripTests: XCTestCase {

    // MARK: - Helpers

    private func assertRoundTrip(
        _ formula: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let ast = try FormulaParser.parse(formula)
        let serialized = FormulaSerializer.serialize(ast)
        XCTAssertEqual(serialized, formula, file: file, line: line)
    }

    private func assertRoundTripNormalized(
        _ input: String,
        expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let ast = try FormulaParser.parse(input)
        let serialized = FormulaSerializer.serialize(ast)
        XCTAssertEqual(serialized, expected, file: file, line: line)
    }

    // MARK: - Atoms

    func testRoundTripInteger() throws {
        try assertRoundTrip("42")
    }

    func testRoundTripDecimal() throws {
        try assertRoundTrip("3.14")
    }

    func testRoundTripZero() throws {
        try assertRoundTrip("0")
    }

    func testRoundTripString() throws {
        try assertRoundTrip("\"hello\"")
    }

    func testRoundTripEmptyString() throws {
        try assertRoundTrip("\"\"")
    }

    func testRoundTripBoolTrue() throws {
        try assertRoundTrip("TRUE")
    }

    func testRoundTripBoolFalse() throws {
        try assertRoundTrip("FALSE")
    }

    func testRoundTripCellRef() throws {
        try assertRoundTrip("A1")
    }

    func testRoundTripAbsoluteCellRef() throws {
        try assertRoundTrip("$A$1")
    }

    func testRoundTripMixedCellRef() throws {
        try assertRoundTrip("$A1")
        try assertRoundTrip("A$1")
    }

    func testRoundTripCellRange() throws {
        try assertRoundTrip("A1:B10")
    }

    func testRoundTripAbsoluteCellRange() throws {
        try assertRoundTrip("$A$1:$B$10")
    }

    // MARK: - Error Literals

    func testRoundTripErrorValue() throws {
        try assertRoundTrip("#VALUE!")
    }

    func testRoundTripErrorDiv0() throws {
        try assertRoundTrip("#DIV/0!")
    }

    func testRoundTripErrorRef() throws {
        try assertRoundTrip("#REF!")
    }

    func testRoundTripErrorName() throws {
        try assertRoundTrip("#NAME?")
    }

    func testRoundTripErrorNA() throws {
        try assertRoundTrip("#N/A")
    }

    func testRoundTripErrorNull() throws {
        try assertRoundTrip("#NULL!")
    }

    func testRoundTripErrorNum() throws {
        try assertRoundTrip("#NUM!")
    }

    // MARK: - Binary Operators

    func testRoundTripAdd() throws {
        try assertRoundTrip("A1+B1")
    }

    func testRoundTripSubtract() throws {
        try assertRoundTrip("A1-B1")
    }

    func testRoundTripMultiply() throws {
        try assertRoundTrip("A1*B1")
    }

    func testRoundTripDivide() throws {
        try assertRoundTrip("A1/B1")
    }

    func testRoundTripPower() throws {
        try assertRoundTrip("A1^B1")
    }

    func testRoundTripConcatenate() throws {
        try assertRoundTrip("A1&B1")
    }

    func testRoundTripEqual() throws {
        try assertRoundTrip("A1=B1")
    }

    func testRoundTripNotEqual() throws {
        try assertRoundTrip("A1<>B1")
    }

    func testRoundTripLessThan() throws {
        try assertRoundTrip("A1<B1")
    }

    func testRoundTripGreaterThan() throws {
        try assertRoundTrip("A1>B1")
    }

    func testRoundTripLessOrEqual() throws {
        try assertRoundTrip("A1<=B1")
    }

    func testRoundTripGreaterOrEqual() throws {
        try assertRoundTrip("A1>=B1")
    }

    // MARK: - Precedence Preservation

    func testRoundTripAddMul() throws {
        try assertRoundTrip("A1+B1*C1")
    }

    func testRoundTripParensOverridePrecedence() throws {
        try assertRoundTrip("(A1+B1)*C1")
    }

    func testRoundTripNestedParens() throws {
        try assertRoundTrip("(A1+B1)*(C1-D1)")
    }

    func testRoundTripSubtractRightAssociative() throws {
        try assertRoundTrip("A1-B1-C1")
    }

    func testRoundTripDivideRightAssociative() throws {
        try assertRoundTrip("A1/B1/C1")
    }

    func testRoundTripMixedPrecedence() throws {
        try assertRoundTrip("A1+B1*C1^D1")
    }

    func testRoundTripComparisonLowPrecedence() throws {
        try assertRoundTrip("A1+B1>C1*D1")
    }

    func testRoundTripConcatenationPrecedence() throws {
        try assertRoundTrip("A1&B1=C1&D1")
    }

    // MARK: - Unary Negation

    func testRoundTripNegateRef() throws {
        try assertRoundTrip("-A1")
    }

    func testRoundTripNegateInExpression() throws {
        try assertRoundTrip("A1+-B1")
    }

    func testRoundTripNegateGrouped() throws {
        try assertRoundTrip("-(A1+B1)")
    }

    // MARK: - Function Calls

    func testRoundTripSumRange() throws {
        try assertRoundTrip("SUM(A1:B5)")
    }

    func testRoundTripNoArgFunction() throws {
        try assertRoundTrip("NOW()")
    }

    func testRoundTripMultiArgFunction() throws {
        try assertRoundTrip("IF(A1>0,B1,C1)")
    }

    func testRoundTripNestedFunctions() throws {
        try assertRoundTrip("SUM(A1:A10)/COUNT(A1:A10)")
    }

    func testRoundTripPMTFormula() throws {
        try assertRoundTrip("PMT(B2/12,B3,-B1)")
    }

    func testRoundTripVLOOKUP() throws {
        try assertRoundTrip("VLOOKUP(A1,B1:D10,3,FALSE)")
    }

    func testRoundTripFunctionWithExpression() throws {
        try assertRoundTrip("ROUND(A1*1.08,2)")
    }

    // MARK: - Sheet References

    func testRoundTripSheetRefCell() throws {
        try assertRoundTrip("'Sheet1'!A1")
    }

    func testRoundTripSheetRefRange() throws {
        try assertRoundTrip("'Sheet1'!A1:B10")
    }

    func testRoundTripSheetRefWithSpaces() throws {
        try assertRoundTrip("'My Sheet'!A1")
    }

    func testRoundTripSheetRefWithEscapedQuote() throws {
        try assertRoundTrip("'Sheet''s Data'!A1")
    }

    // MARK: - Normalization (input differs from canonical output)

    func testNormalizationLeadingEquals() throws {
        try assertRoundTripNormalized("=A1+B1", expected: "A1+B1")
    }

    func testNormalizationWhitespace() throws {
        try assertRoundTripNormalized("A1 + B1", expected: "A1+B1")
    }

    func testNormalizationFunctionCaseInsensitive() throws {
        try assertRoundTripNormalized("sum(A1:B5)", expected: "SUM(A1:B5)")
    }

    func testNormalizationUnquotedSheetName() throws {
        try assertRoundTripNormalized("Data!C3", expected: "'Data'!C3")
    }

    func testNormalizationLeadingEqualsAndWhitespace() throws {
        try assertRoundTripNormalized("= SUM( A1 : B5 )", expected: "SUM(A1:B5)")
    }

    // MARK: - Complex Formulas

    func testRoundTripComplexFinancial() throws {
        try assertRoundTrip("PMT(A1/12,B1*12,-C1)")
    }

    func testRoundTripIfWithComparison() throws {
        try assertRoundTrip("IF(A1>=100,A1*0.9,A1)")
    }

    func testRoundTripNestedIf() throws {
        try assertRoundTrip("IF(A1>0,IF(A1>100,\"high\",\"low\"),\"zero\")")
    }

    func testRoundTripMixedOperatorsAndFunctions() throws {
        try assertRoundTrip("(SUM(A1:A10)-MIN(A1:A10))/(MAX(A1:A10)-MIN(A1:A10))")
    }

    func testRoundTripConcatenateWithFunction() throws {
        try assertRoundTrip("\"Total: \"&SUM(A1:A10)")
    }

    func testRoundTripChainedConcatenation() throws {
        try assertRoundTrip("A1&\" \"&B1")
    }

    func testRoundTripPowerInFunction() throws {
        try assertRoundTrip("SQRT(A1^2+B1^2)")
    }

    // MARK: - AST-level Round Trip

    func testASTRoundTripFromBuilder() throws {
        let ast: FormulaAST = .add(.cellRef(CellRef("A1")), .number(1))
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        XCTAssertEqual(reparsed, ast)
    }

    func testASTRoundTripSumBuilder() throws {
        let ast: FormulaAST = .sum(.cellRange(CellRange(from: "A1", to: "A10")))
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        XCTAssertEqual(reparsed, ast)
    }

    func testASTRoundTripPMTBuilder() throws {
        let ast: FormulaAST = .pmt(
            rate: .divide(.cellRef(CellRef("B2")), .number(12)),
            nper: .cellRef(CellRef("B3")),
            pv: .negate(.cellRef(CellRef("B1")))
        )
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        XCTAssertEqual(reparsed, ast)
    }

    func testASTRoundTripIfBuilder() throws {
        let ast: FormulaAST = .if(
            .greaterThan(.cellRef(CellRef("A1")), .number(0)),
            then: .cellRef(CellRef("B1")),
            else: .cellRef(CellRef("C1"))
        )
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        XCTAssertEqual(reparsed, ast)
    }

    // MARK: - Known Asymmetries (documented, not bugs)

    func testNegativeNumberParsesAsNegate() throws {
        let ast = try FormulaParser.parse("-5")
        XCTAssertEqual(ast, .negate(.number(5)))
        let serialized = FormulaSerializer.serialize(ast)
        XCTAssertEqual(serialized, "-5")
        let reparsed = try FormulaParser.parse(serialized)
        XCTAssertEqual(reparsed, ast)
    }
}
