import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FormulaRoundTripTests {

    // MARK: - Helpers

    /// Parses and re-serialises, so each test can assert the result it expects.
    private func roundTrip(_ formula: String) throws -> String {
        FormulaSerializer.serialize(try FormulaParser.parse(formula))
    }

    // MARK: - Atoms

    @Test("Round trip integer")
    func testRoundTripInteger() throws {
        #expect(try roundTrip("42") == "42")
    }

    @Test("Round trip decimal")
    func testRoundTripDecimal() throws {
        #expect(try roundTrip("3.14") == "3.14")
    }

    @Test("Round trip zero")
    func testRoundTripZero() throws {
        #expect(try roundTrip("0") == "0")
    }

    @Test("Round trip string")
    func testRoundTripString() throws {
        #expect(try roundTrip("\"hello\"") == "\"hello\"")
    }

    @Test("Round trip empty string")
    func testRoundTripEmptyString() throws {
        #expect(try roundTrip("\"\"") == "\"\"")
    }

    @Test("Round trip bool true")
    func testRoundTripBoolTrue() throws {
        #expect(try roundTrip("TRUE") == "TRUE")
    }

    @Test("Round trip bool false")
    func testRoundTripBoolFalse() throws {
        #expect(try roundTrip("FALSE") == "FALSE")
    }

    @Test("Round trip cell ref")
    func testRoundTripCellRef() throws {
        #expect(try roundTrip("A1") == "A1")
    }

    @Test("Round trip absolute cell ref")
    func testRoundTripAbsoluteCellRef() throws {
        #expect(try roundTrip("$A$1") == "$A$1")
    }

    @Test("Round trip mixed cell ref")
    func testRoundTripMixedCellRef() throws {
        #expect(try roundTrip("$A1") == "$A1")
        #expect(try roundTrip("A$1") == "A$1")
    }

    @Test("Round trip cell range")
    func testRoundTripCellRange() throws {
        #expect(try roundTrip("A1:B10") == "A1:B10")
    }

    @Test("Round trip absolute cell range")
    func testRoundTripAbsoluteCellRange() throws {
        #expect(try roundTrip("$A$1:$B$10") == "$A$1:$B$10")
    }

    // MARK: - Error Literals

    @Test("Round trip error value")
    func testRoundTripErrorValue() throws {
        #expect(try roundTrip("#VALUE!") == "#VALUE!")
    }

    @Test("Round trip error div0")
    func testRoundTripErrorDiv0() throws {
        #expect(try roundTrip("#DIV/0!") == "#DIV/0!")
    }

    @Test("Round trip error ref")
    func testRoundTripErrorRef() throws {
        #expect(try roundTrip("#REF!") == "#REF!")
    }

    @Test("Round trip error name")
    func testRoundTripErrorName() throws {
        #expect(try roundTrip("#NAME?") == "#NAME?")
    }

    @Test("Round trip error NA")
    func testRoundTripErrorNA() throws {
        #expect(try roundTrip("#N/A") == "#N/A")
    }

    @Test("Round trip error null")
    func testRoundTripErrorNull() throws {
        #expect(try roundTrip("#NULL!") == "#NULL!")
    }

    @Test("Round trip error num")
    func testRoundTripErrorNum() throws {
        #expect(try roundTrip("#NUM!") == "#NUM!")
    }

    // MARK: - Binary Operators

    @Test("Round trip add")
    func testRoundTripAdd() throws {
        #expect(try roundTrip("A1+B1") == "A1+B1")
    }

    @Test("Round trip subtract")
    func testRoundTripSubtract() throws {
        #expect(try roundTrip("A1-B1") == "A1-B1")
    }

    @Test("Round trip multiply")
    func testRoundTripMultiply() throws {
        #expect(try roundTrip("A1*B1") == "A1*B1")
    }

    @Test("Round trip divide")
    func testRoundTripDivide() throws {
        #expect(try roundTrip("A1/B1") == "A1/B1")
    }

    @Test("Round trip power")
    func testRoundTripPower() throws {
        #expect(try roundTrip("A1^B1") == "A1^B1")
    }

    @Test("Round trip concatenate")
    func testRoundTripConcatenate() throws {
        #expect(try roundTrip("A1&B1") == "A1&B1")
    }

    @Test("Round trip equal")
    func testRoundTripEqual() throws {
        #expect(try roundTrip("A1=B1") == "A1=B1")
    }

    @Test("Round trip not equal")
    func testRoundTripNotEqual() throws {
        #expect(try roundTrip("A1<>B1") == "A1<>B1")
    }

    @Test("Round trip less than")
    func testRoundTripLessThan() throws {
        #expect(try roundTrip("A1<B1") == "A1<B1")
    }

    @Test("Round trip greater than")
    func testRoundTripGreaterThan() throws {
        #expect(try roundTrip("A1>B1") == "A1>B1")
    }

    @Test("Round trip less or equal")
    func testRoundTripLessOrEqual() throws {
        #expect(try roundTrip("A1<=B1") == "A1<=B1")
    }

    @Test("Round trip greater or equal")
    func testRoundTripGreaterOrEqual() throws {
        #expect(try roundTrip("A1>=B1") == "A1>=B1")
    }

    // MARK: - Precedence Preservation

    @Test("Round trip add mul")
    func testRoundTripAddMul() throws {
        #expect(try roundTrip("A1+B1*C1") == "A1+B1*C1")
    }

    @Test("Round trip parens override precedence")
    func testRoundTripParensOverridePrecedence() throws {
        #expect(try roundTrip("(A1+B1)*C1") == "(A1+B1)*C1")
    }

    @Test("Round trip nested parens")
    func testRoundTripNestedParens() throws {
        #expect(try roundTrip("(A1+B1)*(C1-D1)") == "(A1+B1)*(C1-D1)")
    }

    @Test("Round trip subtract right associative")
    func testRoundTripSubtractRightAssociative() throws {
        #expect(try roundTrip("A1-B1-C1") == "A1-B1-C1")
    }

    @Test("Round trip divide right associative")
    func testRoundTripDivideRightAssociative() throws {
        #expect(try roundTrip("A1/B1/C1") == "A1/B1/C1")
    }

    @Test("Round trip mixed precedence")
    func testRoundTripMixedPrecedence() throws {
        #expect(try roundTrip("A1+B1*C1^D1") == "A1+B1*C1^D1")
    }

    @Test("Round trip comparison low precedence")
    func testRoundTripComparisonLowPrecedence() throws {
        #expect(try roundTrip("A1+B1>C1*D1") == "A1+B1>C1*D1")
    }

    @Test("Round trip concatenation precedence")
    func testRoundTripConcatenationPrecedence() throws {
        #expect(try roundTrip("A1&B1=C1&D1") == "A1&B1=C1&D1")
    }

    // MARK: - Unary Negation

    @Test("Round trip negate ref")
    func testRoundTripNegateRef() throws {
        #expect(try roundTrip("-A1") == "-A1")
    }

    @Test("Round trip negate in expression")
    func testRoundTripNegateInExpression() throws {
        #expect(try roundTrip("A1+-B1") == "A1+-B1")
    }

    @Test("Round trip negate grouped")
    func testRoundTripNegateGrouped() throws {
        #expect(try roundTrip("-(A1+B1)") == "-(A1+B1)")
    }

    // MARK: - Function Calls

    @Test("Round trip sum range")
    func testRoundTripSumRange() throws {
        #expect(try roundTrip("SUM(A1:B5)") == "SUM(A1:B5)")
    }

    @Test("Round trip no arg function")
    func testRoundTripNoArgFunction() throws {
        #expect(try roundTrip("NOW()") == "NOW()")
    }

    @Test("Round trip multi arg function")
    func testRoundTripMultiArgFunction() throws {
        #expect(try roundTrip("IF(A1>0,B1,C1)") == "IF(A1>0,B1,C1)")
    }

    @Test("Round trip nested functions")
    func testRoundTripNestedFunctions() throws {
        #expect(try roundTrip("SUM(A1:A10)/COUNT(A1:A10)") == "SUM(A1:A10)/COUNT(A1:A10)")
    }

    @Test("Round trip PMT formula")
    func testRoundTripPMTFormula() throws {
        #expect(try roundTrip("PMT(B2/12,B3,-B1)") == "PMT(B2/12,B3,-B1)")
    }

    @Test("Round trip VLOOKUP")
    func testRoundTripVLOOKUP() throws {
        #expect(try roundTrip("VLOOKUP(A1,B1:D10,3,FALSE)") == "VLOOKUP(A1,B1:D10,3,FALSE)")
    }

    @Test("Round trip function with expression")
    func testRoundTripFunctionWithExpression() throws {
        #expect(try roundTrip("ROUND(A1*1.08,2)") == "ROUND(A1*1.08,2)")
    }

    // MARK: - Sheet References

    @Test("Round trip sheet ref cell")
    func testRoundTripSheetRefCell() throws {
        #expect(try roundTrip("'Sheet1'!A1") == "'Sheet1'!A1")
    }

    @Test("Round trip sheet ref range")
    func testRoundTripSheetRefRange() throws {
        #expect(try roundTrip("'Sheet1'!A1:B10") == "'Sheet1'!A1:B10")
    }

    @Test("Round trip sheet ref with spaces")
    func testRoundTripSheetRefWithSpaces() throws {
        #expect(try roundTrip("'My Sheet'!A1") == "'My Sheet'!A1")
    }

    @Test("Round trip sheet ref with escaped quote")
    func testRoundTripSheetRefWithEscapedQuote() throws {
        #expect(try roundTrip("'Sheet''s Data'!A1") == "'Sheet''s Data'!A1")
    }

    // MARK: - Normalization (input differs from canonical output)

    @Test("Normalization leading equals")
    func testNormalizationLeadingEquals() throws {
        #expect(try roundTrip("=A1+B1") == "A1+B1")
    }

    @Test("Normalization whitespace")
    func testNormalizationWhitespace() throws {
        #expect(try roundTrip("A1 + B1") == "A1+B1")
    }

    @Test("Normalization function case insensitive")
    func testNormalizationFunctionCaseInsensitive() throws {
        #expect(try roundTrip("sum(A1:B5)") == "SUM(A1:B5)")
    }

    @Test("Normalization unquoted sheet name")
    func testNormalizationUnquotedSheetName() throws {
        #expect(try roundTrip("Data!C3") == "'Data'!C3")
    }

    @Test("Normalization leading equals and whitespace")
    func testNormalizationLeadingEqualsAndWhitespace() throws {
        #expect(try roundTrip("= SUM( A1 : B5 )") == "SUM(A1:B5)")
    }

    // MARK: - Complex Formulas

    @Test("Round trip complex financial")
    func testRoundTripComplexFinancial() throws {
        #expect(try roundTrip("PMT(A1/12,B1*12,-C1)") == "PMT(A1/12,B1*12,-C1)")
    }

    @Test("Round trip if with comparison")
    func testRoundTripIfWithComparison() throws {
        #expect(try roundTrip("IF(A1>=100,A1*0.9,A1)") == "IF(A1>=100,A1*0.9,A1)")
    }

    @Test("Round trip nested if")
    func testRoundTripNestedIf() throws {
        #expect(try roundTrip("IF(A1>0,IF(A1>100,\"high\",\"low\"),\"zero\")") == "IF(A1>0,IF(A1>100,\"high\",\"low\"),\"zero\")")
    }

    @Test("Round trip mixed operators and functions")
    func testRoundTripMixedOperatorsAndFunctions() throws {
        #expect(try roundTrip("(SUM(A1:A10)-MIN(A1:A10))/(MAX(A1:A10)-MIN(A1:A10))") == "(SUM(A1:A10)-MIN(A1:A10))/(MAX(A1:A10)-MIN(A1:A10))")
    }

    @Test("Round trip concatenate with function")
    func testRoundTripConcatenateWithFunction() throws {
        #expect(try roundTrip("\"Total: \"&SUM(A1:A10)") == "\"Total: \"&SUM(A1:A10)")
    }

    @Test("Round trip chained concatenation")
    func testRoundTripChainedConcatenation() throws {
        #expect(try roundTrip("A1&\" \"&B1") == "A1&\" \"&B1")
    }

    @Test("Round trip power in function")
    func testRoundTripPowerInFunction() throws {
        #expect(try roundTrip("SQRT(A1^2+B1^2)") == "SQRT(A1^2+B1^2)")
    }

    // MARK: - AST-level Round Trip

    @Test("AST round trip from builder")
    func testASTRoundTripFromBuilder() throws {
        let ast: FormulaAST = .add(.cellRef(CellRef("A1")), .number(1))
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        #expect(reparsed == ast)
    }

    @Test("AST round trip sum builder")
    func testASTRoundTripSumBuilder() throws {
        let ast: FormulaAST = .sum(.cellRange(CellRange(from: "A1", to: "A10")))
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        #expect(reparsed == ast)
    }

    @Test("AST round trip PMT builder")
    func testASTRoundTripPMTBuilder() throws {
        let ast: FormulaAST = .pmt(
            rate: .divide(.cellRef(CellRef("B2")), .number(12)),
            nper: .cellRef(CellRef("B3")),
            pv: .negate(.cellRef(CellRef("B1")))
        )
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        #expect(reparsed == ast)
    }

    @Test("AST round trip if builder")
    func testASTRoundTripIfBuilder() throws {
        let ast: FormulaAST = .if(
            .greaterThan(.cellRef(CellRef("A1")), .number(0)),
            then: .cellRef(CellRef("B1")),
            else: .cellRef(CellRef("C1"))
        )
        let serialized = FormulaSerializer.serialize(ast)
        let reparsed = try FormulaParser.parse(serialized)
        #expect(reparsed == ast)
    }

    // MARK: - Known Asymmetries (documented, not bugs)

    @Test("Negative number parses as negate")
    func testNegativeNumberParsesAsNegate() throws {
        let ast = try FormulaParser.parse("-5")
        #expect(ast == .negate(.number(5)))
        let serialized = FormulaSerializer.serialize(ast)
        #expect(serialized == "-5")
        let reparsed = try FormulaParser.parse(serialized)
        #expect(reparsed == ast)
    }
}
