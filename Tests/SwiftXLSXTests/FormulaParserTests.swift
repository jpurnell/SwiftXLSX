import XCTest
@testable import SwiftXLSX

final class FormulaParserTests: XCTestCase {

    // MARK: - Helpers

    /// Convenience for building a token array and parsing it.
    private func parse(_ tokens: FormulaToken...) throws -> FormulaAST {
        try FormulaParser.parseTokens(tokens + [.eof])
    }

    // MARK: - 1. Atom Parsing

    func testParseNumber() throws {
        let ast = try parse(.number(42))
        XCTAssertEqual(ast, .number(42))
    }

    func testParseDecimalNumber() throws {
        let ast = try parse(.number(3.14))
        XCTAssertEqual(ast, .number(3.14))
    }

    func testParseString() throws {
        let ast = try parse(.string("hello"))
        XCTAssertEqual(ast, .text("hello"))
    }

    func testParseEmptyString() throws {
        let ast = try parse(.string(""))
        XCTAssertEqual(ast, .text(""))
    }

    func testParseBoolTrue() throws {
        let ast = try parse(.bool(true))
        XCTAssertEqual(ast, .bool(true))
    }

    func testParseBoolFalse() throws {
        let ast = try parse(.bool(false))
        XCTAssertEqual(ast, .bool(false))
    }

    func testParseErrorValue() throws {
        let ast = try parse(.error(.value))
        XCTAssertEqual(ast, .error(.value))
    }

    func testParseErrorDiv0() throws {
        let ast = try parse(.error(.div0))
        XCTAssertEqual(ast, .error(.div0))
    }

    func testParseCellRef() throws {
        let ast = try parse(.cellRef(CellRef("A1")))
        XCTAssertEqual(ast, .cellRef(CellRef("A1")))
    }

    func testParseNamedRange() throws {
        let ast = try parse(.identifier("MyRange"))
        XCTAssertEqual(ast, .namedRange("MyRange"))
    }

    func testParseEmptyInputThrows() {
        XCTAssertThrowsError(try parse()) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            XCTAssertEqual(parseError.kind, .emptyFormula)
        }
    }

    // MARK: - 2. Binary Operators

    func testAddition() throws {
        // A1 + B1
        let ast = try parse(.cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testSubtraction() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .minus, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testMultiplication() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .asterisk, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testDivision() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .slash, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .divide(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testPower() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .caret, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .power(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testConcatenation() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .ampersand, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .equals, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .equal(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testNotEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .notEqual, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .notEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testLessThan() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .lessThan, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .lessThan(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testGreaterThan() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .greaterThan, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .greaterThan(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testLessOrEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .lessOrEqual, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .lessOrEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    func testGreaterOrEqual() throws {
        let ast = try parse(.cellRef(CellRef("A1")), .greaterOrEqual, .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, .greaterOrEqual(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
    }

    // MARK: - 3. Precedence

    func testMultiplicationBindsTighterThanAddition() throws {
        // A1 + B1 * C1 = A1 + (B1 * C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .plus,
            .cellRef(CellRef("B1")), .asterisk,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .add(.cellRef(CellRef("A1")),
                 .multiply(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testMultiplicationBeforeAddition() throws {
        // A1 * B1 + C1 = (A1 * B1) + C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .add(.multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                 .cellRef(CellRef("C1")))
        )
    }

    func testPowerBindsTighterThanMultiplication() throws {
        // A1 * B1 ^ C1 = A1 * (B1 ^ C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .caret,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .multiply(.cellRef(CellRef("A1")),
                       .power(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testAdditionBindsTighterThanConcatenation() throws {
        // A1 & B1 + C1 = A1 & (B1 + C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .concatenate(.cellRef(CellRef("A1")),
                          .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testConcatenationBindsTighterThanComparison() throws {
        // A1 = B1 & C1 means A1 = (B1 & C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .equals,
            .cellRef(CellRef("B1")), .ampersand,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .equal(.cellRef(CellRef("A1")),
                   .concatenate(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testComparisonBindsLoosest() throws {
        // A1 = B1 + C1 means A1 = (B1 + C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .equals,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .equal(.cellRef(CellRef("A1")),
                   .add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testMixedPrecedenceChain() throws {
        // 1 + 2 * 3 ^ 4 = 1 + (2 * (3 ^ 4))
        let ast = try parse(
            .number(1), .plus,
            .number(2), .asterisk,
            .number(3), .caret,
            .number(4)
        )
        XCTAssertEqual(
            ast,
            .add(.number(1),
                 .multiply(.number(2),
                            .power(.number(3), .number(4))))
        )
    }

    func testDivisionBindsTighterThanSubtraction() throws {
        // A1 - B1 / C1 = A1 - (B1 / C1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .minus,
            .cellRef(CellRef("B1")), .slash,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .subtract(.cellRef(CellRef("A1")),
                       .divide(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))))
        )
    }

    func testConcatenationInComparison() throws {
        // A1 & B1 = C1 & D1 means (A1 & B1) = (C1 & D1)
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .equals,
            .cellRef(CellRef("C1")), .ampersand,
            .cellRef(CellRef("D1"))
        )
        XCTAssertEqual(
            ast,
            .equal(
                .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .concatenate(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
            )
        )
    }

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
        XCTAssertEqual(
            ast,
            .equal(
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
            )
        )
    }

    // MARK: - 4. Left Associativity

    func testSubtractionIsLeftAssociative() throws {
        // A1 - B1 - C1 = (A1 - B1) - C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .minus,
            .cellRef(CellRef("B1")), .minus,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .subtract(
                .subtract(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testDivisionIsLeftAssociative() throws {
        // A1 / B1 / C1 = (A1 / B1) / C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .slash,
            .cellRef(CellRef("B1")), .slash,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .divide(
                .divide(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testPowerIsLeftAssociativeInExcel() throws {
        // A1 ^ B1 ^ C1 = (A1 ^ B1) ^ C1 (Excel is left-assoc, not math)
        let ast = try parse(
            .cellRef(CellRef("A1")), .caret,
            .cellRef(CellRef("B1")), .caret,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .power(
                .power(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testAdditionIsLeftAssociative() throws {
        // A1 + B1 + C1 = (A1 + B1) + C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .plus,
            .cellRef(CellRef("B1")), .plus,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .add(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testMultiplicationIsLeftAssociative() throws {
        // A1 * B1 * C1 = (A1 * B1) * C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .cellRef(CellRef("B1")), .asterisk,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .multiply(
                .multiply(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testConcatenationIsLeftAssociative() throws {
        // A1 & B1 & C1 = (A1 & B1) & C1
        let ast = try parse(
            .cellRef(CellRef("A1")), .ampersand,
            .cellRef(CellRef("B1")), .ampersand,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .concatenate(
                .concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    // MARK: - 5. Unary Operators

    func testUnaryNegateCell() throws {
        // -A1
        let ast = try parse(.minus, .cellRef(CellRef("A1")))
        XCTAssertEqual(ast, .negate(.cellRef(CellRef("A1"))))
    }

    func testUnaryNegateGroupedExpression() throws {
        // -(A1+B1)
        let ast = try parse(
            .minus, .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen
        )
        XCTAssertEqual(
            ast,
            .negate(.add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))))
        )
    }

    func testUnaryNegateNumber() throws {
        // -5
        let ast = try parse(.minus, .number(5))
        XCTAssertEqual(ast, .negate(.number(5)))
    }

    func testUnaryNegateInMultiplication() throws {
        // A1 * -B1
        let ast = try parse(
            .cellRef(CellRef("A1")), .asterisk,
            .minus, .cellRef(CellRef("B1"))
        )
        XCTAssertEqual(
            ast,
            .multiply(.cellRef(CellRef("A1")), .negate(.cellRef(CellRef("B1"))))
        )
    }

    func testUnaryPlusIsIdentity() throws {
        // +A1 = A1
        let ast = try parse(.plus, .cellRef(CellRef("A1")))
        XCTAssertEqual(ast, .cellRef(CellRef("A1")))
    }

    func testDoubleNegation() throws {
        // --A1
        let ast = try parse(.minus, .minus, .cellRef(CellRef("A1")))
        XCTAssertEqual(ast, .negate(.negate(.cellRef(CellRef("A1")))))
    }

    // MARK: - 6. Function Calls

    func testFunctionCallNoArgs() throws {
        // NOW()
        let ast = try parse(.identifier("NOW"), .leftParen, .rightParen)
        XCTAssertEqual(ast, .function("NOW", []))
    }

    func testFunctionCallSingleArg() throws {
        // ABS(A1)
        let ast = try parse(
            .identifier("ABS"), .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen
        )
        XCTAssertEqual(ast, .function("ABS", [.cellRef(CellRef("A1"))]))
    }

    func testFunctionCallWithRange() throws {
        // SUM(A1:B5)
        let ast = try parse(
            .identifier("SUM"), .leftParen,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5")),
            .rightParen
        )
        XCTAssertEqual(
            ast,
            .function("SUM", [.cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5")))])
        )
    }

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
        XCTAssertEqual(
            ast,
            .function("IF", [
                .greaterThan(.cellRef(CellRef("A1")), .number(0)),
                .text("yes"),
                .text("no"),
            ])
        )
    }

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
        XCTAssertEqual(
            ast,
            .function("SUM", [
                .cellRef(CellRef("A1")),
                .function("MAX", [
                    .cellRef(CellRef("B1")),
                    .cellRef(CellRef("C1")),
                ]),
            ])
        )
    }

    func testFunctionNameIsUppercased() throws {
        // sum(a1) -> SUM
        let ast = try parse(
            .identifier("sum"), .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen
        )
        XCTAssertEqual(ast, .function("SUM", [.cellRef(CellRef("A1"))]))
    }

    func testFunctionWithExpressionArg() throws {
        // ROUND(A1+B1, 2)
        let ast = try parse(
            .identifier("ROUND"), .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .comma,
            .number(2),
            .rightParen
        )
        XCTAssertEqual(
            ast,
            .function("ROUND", [
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .number(2),
            ])
        )
    }

    func testFunctionWithNegativeArg() throws {
        // ABS(-5)
        let ast = try parse(
            .identifier("ABS"), .leftParen,
            .minus, .number(5),
            .rightParen
        )
        XCTAssertEqual(ast, .function("ABS", [.negate(.number(5))]))
    }

    // MARK: - 7. Cell Ranges

    func testCellRange() throws {
        // A1:B5
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5")))
        XCTAssertEqual(ast, .cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5"))))
    }

    func testCellRangeAbsolute() throws {
        // $A$1:$B$5
        let ast = try parse(
            .cellRef(CellRef("$A$1")), .colon, .cellRef(CellRef("$B$5"))
        )
        XCTAssertEqual(
            ast,
            .cellRange(CellRange(from: CellRef("$A$1"), to: CellRef("$B$5")))
        )
    }

    func testSingleColumnRange() throws {
        // A1:A10
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("A10")))
        XCTAssertEqual(ast, .cellRange(CellRange(from: CellRef("A1"), to: CellRef("A10"))))
    }

    func testSingleRowRange() throws {
        // A1:Z1
        let ast = try parse(.cellRef(CellRef("A1")), .colon, .cellRef(CellRef("Z1")))
        XCTAssertEqual(ast, .cellRange(CellRange(from: CellRef("A1"), to: CellRef("Z1"))))
    }

    // MARK: - 8. Sheet References

    func testSheetRefWithIdentifier() throws {
        // Sheet1!A1
        let ast = try parse(
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1"))
        )
        XCTAssertEqual(ast, .sheetRef(SheetReference(sheet: "Sheet1", cell: CellRef("A1"))))
    }

    func testSheetRefWithQuotedName() throws {
        // 'My Sheet'!A1
        let ast = try parse(
            .quotedName("My Sheet"), .exclamation,
            .cellRef(CellRef("A1"))
        )
        XCTAssertEqual(ast, .sheetRef(SheetReference(sheet: "My Sheet", cell: CellRef("A1"))))
    }

    func testSheetRefWithRange() throws {
        // Sheet1!A1:B5
        let ast = try parse(
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5"))
        )
        XCTAssertEqual(
            ast,
            .sheetRef(SheetReference(
                sheet: "Sheet1",
                range: CellRange(from: CellRef("A1"), to: CellRef("B5"))
            ))
        )
    }

    func testQuotedSheetRefWithRange() throws {
        // 'Data Sheet'!A1:B5
        let ast = try parse(
            .quotedName("Data Sheet"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("B5"))
        )
        XCTAssertEqual(
            ast,
            .sheetRef(SheetReference(
                sheet: "Data Sheet",
                range: CellRange(from: CellRef("A1"), to: CellRef("B5"))
            ))
        )
    }

    func testSheetRefInExpression() throws {
        // Sheet1!A1 + Sheet2!B1
        let ast = try parse(
            .identifier("Sheet1"), .exclamation, .cellRef(CellRef("A1")),
            .plus,
            .identifier("Sheet2"), .exclamation, .cellRef(CellRef("B1"))
        )
        XCTAssertEqual(
            ast,
            .add(
                .sheetRef(SheetReference(sheet: "Sheet1", cell: CellRef("A1"))),
                .sheetRef(SheetReference(sheet: "Sheet2", cell: CellRef("B1")))
            )
        )
    }

    func testSheetRefInFunction() throws {
        // SUM(Sheet1!A1:A10)
        let ast = try parse(
            .identifier("SUM"), .leftParen,
            .identifier("Sheet1"), .exclamation,
            .cellRef(CellRef("A1")), .colon, .cellRef(CellRef("A10")),
            .rightParen
        )
        XCTAssertEqual(
            ast,
            .function("SUM", [
                .sheetRef(SheetReference(
                    sheet: "Sheet1",
                    range: CellRange(from: CellRef("A1"), to: CellRef("A10"))
                )),
            ])
        )
    }

    // MARK: - 9. Parenthesized Expressions

    func testParenthesizedAdditionBeforeMultiplication() throws {
        // (A1 + B1) * C1
        let ast = try parse(
            .leftParen,
            .cellRef(CellRef("A1")), .plus, .cellRef(CellRef("B1")),
            .rightParen,
            .asterisk,
            .cellRef(CellRef("C1"))
        )
        XCTAssertEqual(
            ast,
            .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .cellRef(CellRef("C1"))
            )
        )
    }

    func testNestedParentheses() throws {
        // ((A1))
        let ast = try parse(
            .leftParen, .leftParen,
            .cellRef(CellRef("A1")),
            .rightParen, .rightParen
        )
        XCTAssertEqual(ast, .cellRef(CellRef("A1")))
    }

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
        XCTAssertEqual(
            ast,
            .multiply(
                .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                .subtract(.cellRef(CellRef("C1")), .cellRef(CellRef("D1")))
            )
        )
    }

    // MARK: - 10. Error Cases

    func testEmptyFormulaError() {
        XCTAssertThrowsError(try FormulaParser.parseTokens([.eof])) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            XCTAssertEqual(parseError.kind, .emptyFormula)
        }
    }

    func testMissingClosingParenError() {
        XCTAssertThrowsError(try parse(.leftParen, .number(1))) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedEnd = parseError.kind {
                // Expected
            } else {
                XCTFail("Expected unexpectedEnd, got \(parseError.kind)")
            }
        }
    }

    func testUnexpectedTokenError() {
        XCTAssertThrowsError(try parse(.asterisk)) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken = parseError.kind {
                // Expected
            } else {
                XCTFail("Expected unexpectedToken, got \(parseError.kind)")
            }
        }
    }

    func testTrailingTokensError() {
        XCTAssertThrowsError(try parse(.number(1), .number(2))) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken = parseError.kind {
                // Expected
            } else {
                XCTFail("Expected unexpectedToken, got \(parseError.kind)")
            }
        }
    }

    func testMissingFunctionArgAfterComma() {
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
            return XCTFail("expected SUM(...), got \(String(describing: ast))")
        }
        XCTAssertEqual(args.count, 2, "the omitted argument still occupies its position")
        XCTAssertEqual(args[1], .missing)
    }
    func testMissingOperandAfterOperator() {
        // 1 +
        XCTAssertThrowsError(try parse(.number(1), .plus)) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedEnd = parseError.kind {
                // Expected
            } else {
                XCTFail("Expected unexpectedEnd, got \(parseError.kind)")
            }
        }
    }

    func testMissingCellRefAfterColon() {
        // A1:
        XCTAssertThrowsError(try parse(.cellRef(CellRef("A1")), .colon)) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken = parseError.kind {
                // Expected - eof found where cell reference expected
            } else if case .unexpectedEnd = parseError.kind {
                // Also acceptable
            } else {
                XCTFail("Expected unexpectedToken or unexpectedEnd, got \(parseError.kind)")
            }
        }
    }

    func testQuotedNameWithoutExclamation() {
        // 'Sheet1' without !
        XCTAssertThrowsError(try parse(.quotedName("Sheet1"))) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken = parseError.kind {
                // Expected
            } else if case .unexpectedEnd = parseError.kind {
                // Also acceptable
            } else {
                XCTFail("Expected parse error for quoted name without !, got \(parseError.kind)")
            }
        }
    }

    // MARK: - 11. Complex Expressions

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
        XCTAssertEqual(
            ast,
            .function("PMT", [
                .divide(.cellRef(CellRef("B2")), .number(12)),
                .cellRef(CellRef("B3")),
                .negate(.cellRef(CellRef("B1"))),
            ])
        )
    }

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
        XCTAssertEqual(
            ast,
            .divide(
                .multiply(
                    .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))),
                    .cellRef(CellRef("C1"))
                ),
                .cellRef(CellRef("D1"))
            )
        )
    }

    func testGreaterOrEqualComparison() throws {
        // A1 >= 100
        let ast = try parse(
            .cellRef(CellRef("A1")), .greaterOrEqual, .number(100)
        )
        XCTAssertEqual(
            ast,
            .greaterOrEqual(.cellRef(CellRef("A1")), .number(100))
        )
    }

    func testNotEqualWithEmptyString() throws {
        // A1 <> ""
        let ast = try parse(
            .cellRef(CellRef("A1")), .notEqual, .string("")
        )
        XCTAssertEqual(
            ast,
            .notEqual(.cellRef(CellRef("A1")), .text(""))
        )
    }

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
        XCTAssertEqual(
            ast,
            .function("IF", [
                .greaterThan(.cellRef(CellRef("A1")), .number(0)),
                .multiply(.cellRef(CellRef("A1")), .number(2)),
                .negate(.cellRef(CellRef("A1"))),
            ])
        )
    }

    // MARK: - Public parse() with Lexer

    func testPublicParseWithLexer() throws {
        let ast = try FormulaParser.parse("SUM(A1:B5)")
        let expected: FormulaAST = .function("SUM", [
            .cellRange(CellRange(from: CellRef("A1"), to: CellRef("B5")))
        ])
        XCTAssertEqual(ast, expected)
    }

    func testPublicParseLeadingEquals() throws {
        let ast = try FormulaParser.parse("=A1+B1")
        let expected: FormulaAST = .add(.cellRef(CellRef("A1")), .cellRef(CellRef("B1")))
        XCTAssertEqual(ast, expected)
    }

    func testPublicParseComplexFormula() throws {
        let ast = try FormulaParser.parse("PMT(B2/12,B3,-B1)")
        let expected: FormulaAST = .function("PMT", [
            .divide(.cellRef(CellRef("B2")), .number(12)),
            .cellRef(CellRef("B3")),
            .negate(.cellRef(CellRef("B1")))
        ])
        XCTAssertEqual(ast, expected)
    }
}
