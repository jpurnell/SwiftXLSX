import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FormulaParserTests {

    // MARK: - Helpers

    /// Convenience for building a token array and parsing it.
    private func parse(_ tokens: FormulaToken...) throws -> FormulaAST {
        try FormulaParser.parseTokens(tokens + [.eof])
    }

    // MARK: - 1. Atom Parsing

    @Test("Parse number")
    func testParseNumber() throws {
        let ast = try parse(.number(42))
        #expect(ast == .number(42))
    }

    @Test("Parse decimal number")
    func testParseDecimalNumber() throws {
        let ast = try parse(.number(3.14))
        #expect(ast == .number(3.14))
    }

    @Test("Parse string")
    func testParseString() throws {
        let ast = try parse(.string("hello"))
        #expect(ast == .text("hello"))
    }

    @Test("Parse empty string")
    func testParseEmptyString() throws {
        let ast = try parse(.string(""))
        #expect(ast == .text(""))
    }

    @Test("Parse bool true")
    func testParseBoolTrue() throws {
        let ast = try parse(.bool(true))
        #expect(ast == .bool(true))
    }

    @Test("Parse bool false")
    func testParseBoolFalse() throws {
        let ast = try parse(.bool(false))
        #expect(ast == .bool(false))
    }

    @Test("Parse error value")
    func testParseErrorValue() throws {
        let ast = try parse(.error(.value))
        #expect(ast == .error(.value))
    }

    @Test("Parse error div0")
    func testParseErrorDiv0() throws {
        let ast = try parse(.error(.div0))
        #expect(ast == .error(.div0))
    }

    @Test("Parse cell ref")
    func testParseCellRef() throws {
        let ast = try parse(.cellRef(CellRef("A1")))
        #expect(ast == .cellRef(CellRef("A1")))
    }

    @Test("Parse named range")
    func testParseNamedRange() throws {
        let ast = try parse(.identifier("MyRange"))
        #expect(ast == .namedRange("MyRange"))
    }

    @Test("Parse empty input throws")
    func testParseEmptyInputThrows() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try parse()
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        #expect(parseError.kind == .emptyFormula)
    }

    // MARK: - 2. Binary Operators

    @Test("Addition")
    func testAddition() throws {
        // A1 + B1
        let ast = try parse(.cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")))
        #expect(ast == .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Subtraction")
    func testSubtraction() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .minus, .cellRef(CellRef("B1")))
        #expect(ast == .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Multiplication")
    func testMultiplication() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .asterisk, .cellRef(CellRef("B1")))
        #expect(ast == .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Division")
    func testDivision() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .slash, .cellRef(CellRef("B1")))
        #expect(ast == .divide(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Power")
    func testPower() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .caret, .cellRef(CellRef("B1")))
        #expect(ast == .power(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Concatenation")
    func testConcatenation() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .ampersand, .cellRef(CellRef("B1")))
        #expect(ast == .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Equal")
    func testEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .equals, .cellRef(CellRef("B1")))
        #expect(ast == .equal(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Not equal")
    func testNotEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .notEqual, .cellRef(CellRef("B1")))
        #expect(ast == .notEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Less than")
    func testLessThan() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .lessThan, .cellRef(CellRef("B1")))
        #expect(ast == .lessThan(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Greater than")
    func testGreaterThan() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .greaterThan, .cellRef(CellRef("B1")))
        #expect(ast == .greaterThan(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Less or equal")
    func testLessOrEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .lessOrEqual, .cellRef(CellRef("B1")))
        #expect(ast == .lessOrEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    @Test("Greater or equal")
    func testGreaterOrEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .greaterOrEqual, .cellRef(CellRef("B1")))
        #expect(ast == .greaterOrEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    // MARK: - 3. Precedence

    @Test("Multiplication binds tighter than addition")
    func testMultiplicationBindsTighterThanAddition() throws {
        // A1 + B1 * C1 = A1 + (B1 * C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .plus,
            .cellRef(CellRef("B1")), .asterisk,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .add(.cellRef(CellRef("A1")),
                 .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Multiplication before addition")
    func testMultiplicationBeforeAddition() throws {
        // A1 * B1 + C1 = (A1 * B1) + C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .add(.multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                 .cellRef(CellRef("C1"))))
    }

    @Test("Power binds tighter than multiplication")
    func testPowerBindsTighterThanMultiplication() throws {
        // A1 * B1 ^ C1 = A1 * (B1 ^ C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .caret,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .multiply(.cellRef(CellRef("A1")),
                       .power(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Addition binds tighter than concatenation")
    func testAdditionBindsTighterThanConcatenation() throws {
        // A1 & B1 + C1 = A1 & (B1 + C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .concatenate(.cellRef(CellRef("A1")),
                          .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Concatenation binds tighter than comparison")
    func testConcatenationBindsTighterThanComparison() throws {
        // A1 = B1 & C1 means A1 = (B1 & C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .equals,
            .cellRef(CellRef("B1")), .ampersand,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .equal(.cellRef(CellRef("A1")),
                   .concatenate(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Comparison binds loosest")
    func testComparisonBindsLoosest() throws {
        // A1 = B1 + C1 means A1 = (B1 + C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .equals,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .equal(.cellRef(CellRef("A1")),
                   .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Mixed precedence chain")
    func testMixedPrecedenceChain() throws {
        // 1 + 2 * 3 ^ 4 = 1 + (2 * (3 ^ 4))
        let ast = try parse(
            .number(1), .plus,
            .number(2), .asterisk,
            .number(3), .caret,
            .number(4)
        )
        #expect(ast == .add(.number(1),
                 .multiply(.number(2),
                            .power(.number(3), .number(4)))))
    }

    @Test("Division binds tighter than subtraction")
    func testDivisionBindsTighterThanSubtraction() throws {
        // A1 - B1 / C1 = A1 - (B1 / C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .minus,
            .cellRef(CellRef("B1")), .slash,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .subtract(.cellRef(CellRef("A1")),
                       .divide(.cellRef(CellRef("B1")), .cellRef(CellRef("C1")))))
    }

    @Test("Concatenation in comparison")
    func testConcatenationInComparison() throws {
        // A1 & B1 = C1 & D1 means (A1 & B1) = (C1 & D1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .equals,
            .cellRef(CellRef("C1")), .ampersand,
            .cellRef(CellRef("D1"))
        )
        #expect(ast == .equal(
                .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .concatenate(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
            ))
    }

    @Test("Full precedence chain")
    func testFullPrecedenceChain() throws {
        // A1 = B1 & C1 + D1 * E1 ^ F1
        // should be: A1 = (B1 & ((C1 + (D1 * (E1 ^ F1)))))
        let ast = try parse(
            .cellRef(CellRef("A1")), .equals,
            .cellRef(CellRef("B1")), .ampersand,
            .cellRef(CellRef("C1")), .plus,
            .cellRef(CellRef("D1")), .asterisk,
            .cellRef(CellRef("E1")), .caret,
            .cellRef(CellRef("F1"))
        )
        #expect(ast == .equal(
                .cellRef(CellRef("A1")),
                .concatenate(
                    .cellRef(CellRef("B1")),
                    .add(
                        .cellRef(CellRef("C1")),
                        .multiply(
                            .cellRef(CellRef("D1")),
                            .power(.cellRef(CellRef("E1")), .cellRef(CellRef("F1")))
                        )
                    )
                )
            ))
    }

    // MARK: - 4. Left Associativity

    @Test("Subtraction is left associative")
    func testSubtractionIsLeftAssociative() throws {
        // A1 - B1 - C1 = (A1 - B1) - C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .minus,
            .cellRef(CellRef("B1")), .minus,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .subtract(
                .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Division is left associative")
    func testDivisionIsLeftAssociative() throws {
        // A1 / B1 / C1 = (A1 / B1) / C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .slash,
            .cellRef(CellRef("B1")), .slash,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .divide(
                .divide(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Power is left associative in excel")
    func testPowerIsLeftAssociativeInExcel() throws {
        // A1 ^ B1 ^ C1 = (A1 ^ B1) ^ C1 (Excel is left-assoc, not math)
        let ast = try parse(
            .cellRef(CellRef("A1")), .caret,
            .cellRef(CellRef("B1")), .caret,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .power(
                .power(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Addition is left associative")
    func testAdditionIsLeftAssociative() throws {
        // A1 + B1 + C1 = (A1 + B1) + C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .plus,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .add(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Multiplication is left associative")
    func testMultiplicationIsLeftAssociative() throws {
        // A1 * B1 * C1 = (A1 * B1) * C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .asterisk,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .multiply(
                .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Concatenation is left associative")
    func testConcatenationIsLeftAssociative() throws {
        // A1 & B1 & C1 = (A1 & B1) & C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .ampersand,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .concatenate(
                .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    // MARK: - 5. Unary Operators

    @Test("Unary negate cell")
    func testUnaryNegateCell() throws {
        // -A1
        let ast = try parse(.minus, .cellRef(CellRef("A1")))
        #expect(ast == .negate(.cellRef(CellRef("A1"))))
    }

    @Test("Unary negate grouped expression")
    func testUnaryNegateGroupedExpression() throws {
        // -(A1+B1)
        let ast = try parse(
            .minus, .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen
        )
        #expect(ast == .negate(.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1")))))
    }

    @Test("Unary negate number")
    func testUnaryNegateNumber() throws {
        // -5
        let ast = try parse(.minus, .number(5))
        #expect(ast == .negate(.number(5)))
    }

    @Test("Unary negate in multiplication")
    func testUnaryNegateInMultiplication() throws {
        // A1 * -B1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .minus, .cellRef(CellRef("B1"))
        )
        #expect(ast == .multiply(.cellRef(CellRef("A1")), .negate(.cellRef(CellRef("B1")))))
    }

    @Test("Unary plus is identity")
    func testUnaryPlusIsIdentity() throws {
        // +A1 = A1
        let ast = try parse(.plus, .cellRef(CellRef("A1")))
        #expect(ast == .cellRef(CellRef("A1")))
    }

    @Test("Double negation")
    func testDoubleNegation() throws {
        // --A1
        let ast = try parse(.minus, .minus, .cellRef(CellRef("A1")))
        #expect(ast == .negate(.negate(.cellRef(CellRef("A1")))))
    }

    // MARK: - 6. Function Calls

    @Test("Function call no args")
    func testFunctionCallNoArgs() throws {
        // NOW()
        let ast = try parse(.identifier("NOW"), .leftParen, .rightParen)
        #expect(ast == .function("NOW", []))
    }

    @Test("Function call single arg")
    func testFunctionCallSingleArg() throws {
        // ABS(A1)
        let ast = try parse(
            .identifier("ABS"), .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen
        )
        #expect(ast == .function("ABS", [.cellRef(CellRef("A1"))]))
    }

    @Test("Function call with range")
    func testFunctionCallWithRange() throws {
        // SUM(A1:B5)
        let ast = try parse(
            .identifier("SUM"), .leftParen,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5")),
            .rightParen
        )
        #expect(ast == .function("SUM", [.cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5")))]))
    }

    @Test("Function call multiple args")
    func testFunctionCallMultipleArgs() throws {
        // IF(A1>0, "yes", "no")
        let ast = try parse(
            .identifier("IF"), .leftParen,
            .cellRef(CellRef("A1")), .greaterThan, .number(0),
            .comma,
            .string("yes"),
            .comma,
            .string("no"),
            .rightParen
        )
        #expect(ast == .function("IF", [
                .greaterThan(.cellRef(CellRef("A1")), .number(0)),
                .text("yes"),
                .text("no"),
            ]))
    }

    @Test("Nested function calls")
    func testNestedFunctionCalls() throws {
        // SUM(A1, MAX(B1, C1))
        let ast = try parse(
            .identifier("SUM"), .leftParen,
            .cellRef(CellRef("A1")),
            .comma,
            .identifier("MAX"), .leftParen,
            .cellRef(CellRef("B1")),
            .comma,
            .cellRef(CellRef("C1")),
            .rightParen,
            .rightParen
        )
        #expect(ast == .function("SUM", [
                .cellRef(CellRef("A1")),
                .function("MAX", [
                    .cellRef(CellRef("B1")),
                    .cellRef(CellRef("C1")),
                ]),
            ]))
    }

    @Test("Function name is uppercased")
    func testFunctionNameIsUppercased() throws {
        // sum(a1) -> SUM
        let ast = try parse(
            .identifier("sum"), .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen
        )
        #expect(ast == .function("SUM", [.cellRef(CellRef("A1"))]))
    }

    @Test("Function with expression arg")
    func testFunctionWithExpressionArg() throws {
        // ROUND(A1+B1, 2)
        let ast = try parse(
            .identifier("ROUND"), .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .comma,
            .number(2),
            .rightParen
        )
        #expect(ast == .function("ROUND", [
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .number(2),
            ]))
    }

    @Test("Function with negative arg")
    func testFunctionWithNegativeArg() throws {
        // ABS(-5)
        let ast = try parse(
            .identifier("ABS"), .leftParen,
            .minus, .number(5),
            .rightParen
        )
        #expect(ast == .function("ABS", [.negate(.number(5))]))
    }

    // MARK: - 7. Cell Ranges

    @Test("Cell range")
    func testCellRange() throws {
        // A1:B5
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5")))
        #expect(ast == .cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5"))))
    }

    @Test("Cell range absolute")
    func testCellRangeAbsolute() throws {
        // $A$1:$B$5
        let ast = try parse(
            .cellRef(CellRef("$A$1")), .colon, .cellRef(CellRef("$B$5"))
        )
        #expect(ast == .cellRange(CellRange(from: CellRef("$A$1"), to: CellRef("$B$5"))))
    }

    @Test("Single column range")
    func testSingleColumnRange() throws {
        // A1:A10
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("A10")))
        #expect(ast == .cellRange(CellRange(from: CellRef("A1"), to: CellRef("A10"))))
    }

    @Test("Single row range")
    func testSingleRowRange() throws {
        // A1:Z1
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("Z1")))
        #expect(ast == .cellRange(CellRange(from: CellRef("A1"), to: CellRef("Z1"))))
    }

    // MARK: - 8. Sheet References

    @Test("Sheet ref with identifier")
    func testSheetRefWithIdentifier() throws {
        // Sheet1!A1
        let ast = try parse(
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1"))
        )
        #expect(ast == .sheetRef(SheetReference(sheet: "Sheet1", cell: CellRef("A1"))))
    }

    @Test("Sheet ref with quoted name")
    func testSheetRefWithQuotedName() throws {
        // 'My Sheet'!A1
        let ast = try parse(
            .quotedName("My Sheet"), .exclamation,
            .cellRef(CellRef("A1"))
        )
        #expect(ast == .sheetRef(SheetReference(sheet: "My Sheet", cell: CellRef("A1"))))
    }

    @Test("Sheet ref with range")
    func testSheetRefWithRange() throws {
        // Sheet1!A1:B5
        let ast = try parse(
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5"))
        )
        #expect(ast == .sheetRef(SheetReference(
                sheet: "Sheet1",
                range: CellRange(from: CellRef("A1"), to: CellRef("B5"))
            )))
    }

    @Test("Quoted sheet ref with range")
    func testQuotedSheetRefWithRange() throws {
        // 'Data Sheet'!A1:B5
        let ast = try parse(
            .quotedName("Data Sheet"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5"))
        )
        #expect(ast == .sheetRef(SheetReference(
                sheet: "Data Sheet",
                range: CellRange(from: CellRef("A1"), to: CellRef("B5"))
            )))
    }

    @Test("Sheet ref in expression")
    func testSheetRefInExpression() throws {
        // Sheet1!A1 + Sheet2!B1
        let ast = try parse(
            .identifier("Sheet1"), .exclamation, .cellRef(CellRef("A1")),
            .plus,
            .identifier("Sheet2"), .exclamation, .cellRef(CellRef("B1"))
        )
        #expect(ast == .add(
                .sheetRef(SheetReference(sheet: "Sheet1", cell: CellRef("A1"))),
                .sheetRef(SheetReference(sheet: "Sheet2", cell: CellRef("B1")))
            ))
    }

    @Test("Sheet ref in function")
    func testSheetRefInFunction() throws {
        // SUM(Sheet1!A1:A10)
        let ast = try parse(
            .identifier("SUM"), .leftParen,
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("A10")),
            .rightParen
        )
        #expect(ast == .function("SUM", [
                .sheetRef(SheetReference(
                    sheet: "Sheet1",
                    range: CellRange(from: CellRef("A1"), to: CellRef("A10"))
                )),
            ]))
    }

    // MARK: - 9. Parenthesized Expressions

    @Test("Parenthesized addition before multiplication")
    func testParenthesizedAdditionBeforeMultiplication() throws {
        // (A1 + B1) * C1
        let ast = try parse(
            .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen,
            .asterisk,
            .cellRef(CellRef("C1"))
        )
        #expect(ast == .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            ))
    }

    @Test("Nested parentheses")
    func testNestedParentheses() throws {
        // ((A1))
        let ast = try parse(
            .leftParen, .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen, .rightParen
        )
        #expect(ast == .cellRef(CellRef("A1")))
    }

    @Test("Complex parentheses")
    func testComplexParentheses() throws {
        // (A1 + B1) * (C1 - D1)
        let ast = try parse(
            .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen,
            .asterisk,
            .leftParen,
            .cellRef(CellRef("C1")), .minus, .cellRef(CellRef("D1")),
            .rightParen
        )
        #expect(ast == .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .subtract(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
            ))
    }

    // MARK: - 10. Error Cases

    @Test("Empty formula error")
    func testEmptyFormulaError() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaParser.parseTokens([.eof])
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        #expect(parseError.kind == .emptyFormula)
    }

    @Test("Missing closing paren error")
    func testMissingClosingParenError() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.leftParen, .number(1))
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedEnd = parseError.kind {
            // Expected
        } else {
            Issue.record("Expected unexpectedEnd, got \(parseError.kind)")
        }
    }

    @Test("Unexpected token error")
    func testUnexpectedTokenError() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.asterisk)
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken = parseError.kind {
            // Expected
        } else {
            Issue.record("Expected unexpectedToken, got \(parseError.kind)")
        }
    }

    @Test("Trailing tokens error")
    func testTrailingTokensError() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.number(1), .number(2))
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken = parseError.kind {
            // Expected
        } else {
            Issue.record("Expected unexpectedToken, got \(parseError.kind)")
        }
    }

    @Test("Missing function arg after comma")
    func testMissingFunctionArgAfterComma() throws {
        // `SUM(1, )` — the second argument is left out.
        //
        // This asserted a thrown error until 0.14.0. It was wrong about Excel:
        // an omitted argument is ordinary, the comma marks its place because
        // position decides which parameter is which, and about 21,500 formulas
        // in the measured corpus depend on it. `FormulaAST.missing` now says so.
        let ast = try? parse(
            .identifier("SUM"), .leftParen,
            .number(1), .comma,
            .rightParen
        )
        guard case .function("SUM", let args)? = ast else {
            Issue.record("expected SUM(...), got \(String(describing: ast))")
            return
        }
        #expect(args.count == 2, "the omitted argument still occupies its position")
        #expect(args[1] == .missing)
    }
    @Test("Missing operand after operator")
    func testMissingOperandAfterOperator() throws {
        // 1 +
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.number(1), .plus)
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedEnd = parseError.kind {
            // Expected
        } else {
            Issue.record("Expected unexpectedEnd, got \(parseError.kind)")
        }
    }

    @Test("Missing cell ref after colon")
    func testMissingCellRefAfterColon() throws {
        // A1:
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.cellRef(CellRef("A1")), .colon)
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken = parseError.kind {
            // Expected - eof found where cell reference expected
        } else if case .unexpectedEnd = parseError.kind {
            // Also acceptable
        } else {
            Issue.record("Expected unexpectedToken or unexpectedEnd, got \(parseError.kind)")
        }
    }

    @Test("Quoted name without exclamation")
    func testQuotedNameWithoutExclamation() throws {
        // 'Sheet1' without !
        let error = try #require(#expect(throws: (any Error).self) {
            try parse(.quotedName("Sheet1"))
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken = parseError.kind {
            // Expected
        } else if case .unexpectedEnd = parseError.kind {
            // Also acceptable
        } else {
            Issue.record("Expected parse error for quoted name without !, got \(parseError.kind)")
        }
    }

    // MARK: - 11. Complex Expressions

    @Test("PMT formula token sequence")
    func testPMTFormulaTokenSequence() throws {
        // PMT(B2/12, B3, -B1)
        let ast = try parse(
            .identifier("PMT"), .leftParen,
            .cellRef(CellRef("B2")), .slash, .number(12),
            .comma,
            .cellRef(CellRef("B3")),
            .comma,
            .minus, .cellRef(CellRef("B1")),
            .rightParen
        )
        #expect(ast == .function("PMT", [
                .divide(.cellRef(CellRef("B2")), .number(12)),
                .cellRef(CellRef("B3")),
                .negate(.cellRef(CellRef("B1"))),
            ]))
    }

    @Test("Compound arithmetic expression")
    func testCompoundArithmeticExpression() throws {
        // (A1+B1)*C1/D1
        let ast = try parse(
            .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen,
            .asterisk,
            .cellRef(CellRef("C1")),
            .slash,
            .cellRef(CellRef("D1"))
        )
        // Left-assoc: ((A1+B1)*C1)/D1
        #expect(ast == .divide(
                .multiply(
                    .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                    .cellRef(CellRef("C1"))
                ),
                .cellRef(CellRef("D1"))
            ))
    }

    @Test("Greater or equal comparison")
    func testGreaterOrEqualComparison() throws {
        // A1 >= 100
        let ast = try parse(
            .cellRef(CellRef("A1")), .greaterOrEqual, .number(100)
        )
        #expect(ast == .greaterOrEqual(.cellRef(CellRef("A1")), .number(100)))
    }

    @Test("Not equal with empty string")
    func testNotEqualWithEmptyString() throws {
        // A1 <> ""
        let ast = try parse(
            .cellRef(CellRef("A1")), .notEqual, .string("")
        )
        #expect(ast == .notEqual(.cellRef(CellRef("A1")), .text("")))
    }

    @Test("Complex nested IF")
    func testComplexNestedIF() throws {
        // IF(A1>0, A1*2, -A1)
        let ast = try parse(
            .identifier("IF"), .leftParen,
            .cellRef(CellRef("A1")), .greaterThan, .number(0),
            .comma,
            .cellRef(CellRef("A1")), .asterisk, .number(2),
            .comma,
            .minus, .cellRef(CellRef("A1")),
            .rightParen
        )
        #expect(ast == .function("IF", [
                .greaterThan(.cellRef(CellRef("A1")), .number(0)),
                .multiply(.cellRef(CellRef("A1")), .number(2)),
                .negate(.cellRef(CellRef("A1"))),
            ]))
    }

    // MARK: - Public parse() with Lexer

    @Test("Public parse with lexer")
    func testPublicParseWithLexer() throws {
        let ast = try FormulaParser.parse("SUM(A1:B5)")
        let expected: FormulaAST = .function("SUM", [
            .cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5")))
        ])
        #expect(ast == expected)
    }

    @Test("Public parse leading equals")
    func testPublicParseLeadingEquals() throws {
        let ast = try FormulaParser.parse("=A1+B1")
        let expected: FormulaAST = .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1")))
        #expect(ast == expected)
    }

    @Test("Public parse complex formula")
    func testPublicParseComplexFormula() throws {
        let ast = try FormulaParser.parse("PMT(B2/12,B3,-B1)")
        let expected: FormulaAST = .function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1")))
        ])
        #expect(ast == expected)
    }
}
