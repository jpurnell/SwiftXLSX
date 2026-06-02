import XCTest
@testable import SwiftXLSX

final class FormulaLexerTests: XCTestCase {

    // MARK: - Helper

    private func assertTokens(
        _ formula: String,
        _ expected: [FormulaToken],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let tokens = try FormulaLexer.tokenize(formula)
        XCTAssertEqual(tokens, expected, file: file, line: line)
    }

    // MARK: - Single Token: Numbers

    func testIntegerNumber() throws {
        try assertTokens("42", [.number(42), .eof])
    }

    func testDecimalNumber() throws {
        try assertTokens("3.14", [.number(3.14), .eof])
    }

    func testLeadingDecimalNumber() throws {
        try assertTokens(".5", [.number(0.5), .eof])
    }

    func testZero() throws {
        try assertTokens("0", [.number(0), .eof])
    }

    func testLargeNumber() throws {
        try assertTokens("1000000", [.number(1_000_000), .eof])
    }

    // MARK: - Single Token: Strings

    func testSimpleString() throws {
        try assertTokens("\"hello\"", [.string("hello"), .eof])
    }

    func testEmptyString() throws {
        try assertTokens("\"\"", [.string(""), .eof])
    }

    func testStringWithEscapedQuotes() throws {
        try assertTokens(
            "\"say \"\"hi\"\"\"",
            [.string("say \"hi\""), .eof]
        )
    }

    func testStringWithSpaces() throws {
        try assertTokens("\"hello world\"", [.string("hello world"), .eof])
    }

    // MARK: - Single Token: Booleans

    func testTrueUppercase() throws {
        try assertTokens("TRUE", [.bool(true), .eof])
    }

    func testFalseUppercase() throws {
        try assertTokens("FALSE", [.bool(false), .eof])
    }

    func testTrueLowercase() throws {
        try assertTokens("true", [.bool(true), .eof])
    }

    func testTrueMixedCase() throws {
        try assertTokens("True", [.bool(true), .eof])
    }

    func testFalseLowercase() throws {
        try assertTokens("false", [.bool(false), .eof])
    }

    // MARK: - Single Token: Errors

    func testErrorValue() throws {
        try assertTokens("#VALUE!", [.error(.value), .eof])
    }

    func testErrorRef() throws {
        try assertTokens("#REF!", [.error(.ref), .eof])
    }

    func testErrorDiv0() throws {
        try assertTokens("#DIV/0!", [.error(.div0), .eof])
    }

    func testErrorName() throws {
        try assertTokens("#NAME?", [.error(.name), .eof])
    }

    func testErrorNull() throws {
        try assertTokens("#NULL!", [.error(.null), .eof])
    }

    func testErrorNum() throws {
        try assertTokens("#NUM!", [.error(.num), .eof])
    }

    func testErrorNA() throws {
        try assertTokens("#N/A", [.error(.na), .eof])
    }

    // MARK: - Single Token: Cell References

    func testSimpleCellRef() throws {
        let tokens = try FormulaLexer.tokenize("A1")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
            XCTAssertFalse(ref.absoluteColumn)
            XCTAssertFalse(ref.absoluteRow)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testAbsoluteCellRef() throws {
        let tokens = try FormulaLexer.tokenize("$A$1")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
            XCTAssertTrue(ref.absoluteColumn)
            XCTAssertTrue(ref.absoluteRow)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testAbsoluteColumnOnly() throws {
        let tokens = try FormulaLexer.tokenize("$A1")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertTrue(ref.absoluteColumn)
            XCTAssertFalse(ref.absoluteRow)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testAbsoluteRowOnly() throws {
        let tokens = try FormulaLexer.tokenize("A$1")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertFalse(ref.absoluteColumn)
            XCTAssertTrue(ref.absoluteRow)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testMultiLetterColumn() throws {
        let tokens = try FormulaLexer.tokenize("AA100")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 27) // AA = 27
            XCTAssertEqual(ref.row, 100)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testMaxCellRef() throws {
        let tokens = try FormulaLexer.tokenize("XFD1048576")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 16384) // XFD = 16384
            XCTAssertEqual(ref.row, 1_048_576)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    func testMaxAbsoluteCellRef() throws {
        let tokens = try FormulaLexer.tokenize("$XFD$1048576")
        XCTAssertEqual(tokens.count, 2)
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 16384)
            XCTAssertEqual(ref.row, 1_048_576)
            XCTAssertTrue(ref.absoluteColumn)
            XCTAssertTrue(ref.absoluteRow)
        } else {
            XCTFail("Expected cellRef, got \(tokens[0])")
        }
    }

    // MARK: - Single Token: Operators

    func testPlusOperator() throws {
        try assertTokens("+", [.plus, .eof])
    }

    func testMinusOperator() throws {
        try assertTokens("-", [.minus, .eof])
    }

    func testAsteriskOperator() throws {
        try assertTokens("*", [.asterisk, .eof])
    }

    func testSlashOperator() throws {
        try assertTokens("/", [.slash, .eof])
    }

    func testCaretOperator() throws {
        try assertTokens("^", [.caret, .eof])
    }

    func testAmpersandOperator() throws {
        try assertTokens("&", [.ampersand, .eof])
    }

    func testEqualsOperator() throws {
        // Equals not at position 0 (would be consumed as leading =)
        let tokens = try FormulaLexer.tokenize("A1=B1")
        XCTAssertEqual(tokens[1], .equals)
    }

    func testNotEqualOperator() throws {
        try assertTokens("<>", [.notEqual, .eof])
    }

    func testLessThanOperator() throws {
        try assertTokens("<", [.lessThan, .eof])
    }

    func testGreaterThanOperator() throws {
        try assertTokens(">", [.greaterThan, .eof])
    }

    func testLessOrEqualOperator() throws {
        try assertTokens("<=", [.lessOrEqual, .eof])
    }

    func testGreaterOrEqualOperator() throws {
        try assertTokens(">=", [.greaterOrEqual, .eof])
    }

    // MARK: - Single Token: Punctuation

    func testLeftParen() throws {
        try assertTokens("(", [.leftParen, .eof])
    }

    func testRightParen() throws {
        try assertTokens(")", [.rightParen, .eof])
    }

    func testComma() throws {
        try assertTokens(",", [.comma, .eof])
    }

    func testColon() throws {
        try assertTokens(":", [.colon, .eof])
    }

    func testExclamation() throws {
        try assertTokens("!", [.exclamation, .eof])
    }

    // MARK: - Single Token: Identifiers

    func testIdentifierSUM() throws {
        try assertTokens("SUM", [.identifier("SUM"), .eof])
    }

    func testIdentifierLowercase() throws {
        try assertTokens("myRange", [.identifier("myRange"), .eof])
    }

    // MARK: - Multi-Token Sequences

    func testSUMFormula() throws {
        let tokens = try FormulaLexer.tokenize("SUM(A1:B5)")
        XCTAssertEqual(tokens[0], .identifier("SUM"))
        XCTAssertEqual(tokens[1], .leftParen)
        if case .cellRef(let ref) = tokens[2] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for A1")
        }
        XCTAssertEqual(tokens[3], .colon)
        if case .cellRef(let ref) = tokens[4] {
            XCTAssertEqual(ref.column, 2)
            XCTAssertEqual(ref.row, 5)
        } else {
            XCTFail("Expected cellRef for B5")
        }
        XCTAssertEqual(tokens[5], .rightParen)
        XCTAssertEqual(tokens[6], .eof)
    }

    func testArithmeticExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1+B2*C3")
        XCTAssertEqual(tokens.count, 6) // 3 cellrefs + 2 ops + eof
        XCTAssertEqual(tokens[1], .plus)
        XCTAssertEqual(tokens[3], .asterisk)
        XCTAssertEqual(tokens[5], .eof)
    }

    func testSheetReference() throws {
        let tokens = try FormulaLexer.tokenize("'Sheet 1'!A1")
        XCTAssertEqual(tokens[0], .quotedName("Sheet 1"))
        XCTAssertEqual(tokens[1], .exclamation)
        if case .cellRef(let ref) = tokens[2] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for A1")
        }
        XCTAssertEqual(tokens[3], .eof)
    }

    func testIFFormula() throws {
        let tokens = try FormulaLexer.tokenize("IF(A1>0,\"yes\",\"no\")")
        XCTAssertEqual(tokens[0], .identifier("IF"))
        XCTAssertEqual(tokens[1], .leftParen)
        // A1
        if case .cellRef(let ref) = tokens[2] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for A1")
        }
        XCTAssertEqual(tokens[3], .greaterThan)
        XCTAssertEqual(tokens[4], .number(0))
        XCTAssertEqual(tokens[5], .comma)
        XCTAssertEqual(tokens[6], .string("yes"))
        XCTAssertEqual(tokens[7], .comma)
        XCTAssertEqual(tokens[8], .string("no"))
        XCTAssertEqual(tokens[9], .rightParen)
        XCTAssertEqual(tokens[10], .eof)
    }

    func testLeadingEqualsConsumed() throws {
        let tokens = try FormulaLexer.tokenize("=A1+B1")
        // Leading = should be consumed; first token is cellRef A1
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for A1, got \(tokens[0])")
        }
        XCTAssertEqual(tokens[1], .plus)
        XCTAssertEqual(tokens[3], .eof)
    }

    func testConcatenation() throws {
        let tokens = try FormulaLexer.tokenize("A1&\" \"&B1")
        XCTAssertEqual(tokens[1], .ampersand)
        XCTAssertEqual(tokens[2], .string(" "))
        XCTAssertEqual(tokens[3], .ampersand)
    }

    func testComparisonChain() throws {
        let tokens = try FormulaLexer.tokenize("A1<>B1")
        XCTAssertEqual(tokens[1], .notEqual)
    }

    func testLessOrEqualExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1<=B1")
        XCTAssertEqual(tokens[1], .lessOrEqual)
    }

    func testNestedFunctions() throws {
        let tokens = try FormulaLexer.tokenize("SUM(IF(A1>0,A1,0))")
        XCTAssertEqual(tokens[0], .identifier("SUM"))
        XCTAssertEqual(tokens[1], .leftParen)
        XCTAssertEqual(tokens[2], .identifier("IF"))
        XCTAssertEqual(tokens[3], .leftParen)
    }

    func testLeadingEqualsWithSUM() throws {
        let tokens = try FormulaLexer.tokenize("=SUM(A1)")
        XCTAssertEqual(tokens[0], .identifier("SUM"))
        XCTAssertEqual(tokens[1], .leftParen)
    }

    // MARK: - Edge Cases

    func testWhitespaceHandling() throws {
        let tokens = try FormulaLexer.tokenize("A1 + B1")
        if case .cellRef(let ref) = tokens[0] {
            XCTAssertEqual(ref.column, 1)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for A1")
        }
        XCTAssertEqual(tokens[1], .plus)
        if case .cellRef(let ref) = tokens[2] {
            XCTAssertEqual(ref.column, 2)
            XCTAssertEqual(ref.row, 1)
        } else {
            XCTFail("Expected cellRef for B1")
        }
        XCTAssertEqual(tokens[3], .eof)
    }

    func testIdentifierVsCellRefXFE1() throws {
        // XFE = column 16385, exceeds max (16384) -> identifier
        try assertTokens("XFE1", [.identifier("XFE1"), .eof])
    }

    func testIdentifierVsCellRefSUM() throws {
        // SUM has no trailing digits -> identifier
        try assertTokens("SUM", [.identifier("SUM"), .eof])
    }

    func testCellRefA1() throws {
        // A1 -> valid cell ref
        let tokens = try FormulaLexer.tokenize("A1")
        if case .cellRef = tokens[0] {
            // pass
        } else {
            XCTFail("A1 should be a cell ref")
        }
    }

    func testQuotedNameWithEscapedQuote() throws {
        let tokens = try FormulaLexer.tokenize("'It''s a sheet'")
        XCTAssertEqual(tokens[0], .quotedName("It's a sheet"))
        XCTAssertEqual(tokens[1], .eof)
    }

    func testErrorWithSlashDIV0() throws {
        // #DIV/0! should not confuse the / with division
        let tokens = try FormulaLexer.tokenize("#DIV/0!")
        XCTAssertEqual(tokens[0], .error(.div0))
        XCTAssertEqual(tokens[1], .eof)
    }

    func testEmptyStringLiteral() throws {
        try assertTokens("\"\"", [.string(""), .eof])
    }

    func testRowZeroIsIdentifier() throws {
        // A0 -> row 0 is invalid -> identifier
        try assertTokens("A0", [.identifier("A0"), .eof])
    }

    func testEofAlwaysAppended() throws {
        let tokens = try FormulaLexer.tokenize("")
        XCTAssertEqual(tokens, [.eof])
    }

    func testPowerExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1^2")
        XCTAssertEqual(tokens[1], .caret)
        XCTAssertEqual(tokens[2], .number(2))
    }

    // MARK: - Error Cases

    func testUnterminatedString() {
        XCTAssertThrowsError(try FormulaLexer.tokenize("\"hello")) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedEnd(let expected) = parseError.kind {
                XCTAssertEqual(expected, "closing quote")
            } else {
                XCTFail("Expected unexpectedEnd, got \(parseError.kind)")
            }
        }
    }

    func testInvalidCharacter() {
        XCTAssertThrowsError(try FormulaLexer.tokenize("@")) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken(let expected, let found) = parseError.kind {
                XCTAssertEqual(expected, "valid token")
                XCTAssertEqual(found, "@")
            } else {
                XCTFail("Expected unexpectedToken, got \(parseError.kind)")
            }
        }
    }

    func testUnterminatedQuotedName() {
        XCTAssertThrowsError(try FormulaLexer.tokenize("'Sheet")) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedEnd(let expected) = parseError.kind {
                XCTAssertEqual(expected, "closing single quote")
            } else {
                XCTFail("Expected unexpectedEnd, got \(parseError.kind)")
            }
        }
    }

    func testUnknownErrorLiteral() {
        XCTAssertThrowsError(try FormulaLexer.tokenize("#WHAT!")) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken(let expected, _) = parseError.kind {
                XCTAssertEqual(expected, "Excel error")
            } else {
                XCTFail("Expected unexpectedToken, got \(parseError.kind)")
            }
        }
    }

    func testInvalidAbsoluteCellRef() {
        // $XFE$1 -> has $ so must be cell ref, but XFE=16385 exceeds max
        XCTAssertThrowsError(try FormulaLexer.tokenize("$XFE$1")) { error in
            guard let parseError = error as? FormulaParseError else {
                XCTFail("Expected FormulaParseError")
                return
            }
            if case .unexpectedToken(let expected, _) = parseError.kind {
                XCTAssertEqual(expected, "valid cell reference")
            } else {
                XCTFail("Expected unexpectedToken, got \(parseError.kind)")
            }
        }
    }
}
