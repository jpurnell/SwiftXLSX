import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FormulaLexerTests {

    // MARK: - Helper


    // MARK: - Single Token: Numbers

    @Test("Integer number")
    func testIntegerNumber() throws {
        #expect(try FormulaLexer.tokenize("42") == [.number(42), .eof])
    }

    @Test("Decimal number")
    func testDecimalNumber() throws {
        #expect(try FormulaLexer.tokenize("3.14") == [.number(3.14), .eof])
    }

    @Test("Leading decimal number")
    func testLeadingDecimalNumber() throws {
        #expect(try FormulaLexer.tokenize(".5") == [.number(0.5), .eof])
    }

    @Test("Zero")
    func testZero() throws {
        #expect(try FormulaLexer.tokenize("0") == [.number(0), .eof])
    }

    @Test("Large number")
    func testLargeNumber() throws {
        #expect(try FormulaLexer.tokenize("1000000") == [.number(1_000_000), .eof])
    }

    // MARK: - Single Token: Strings

    @Test("Simple string")
    func testSimpleString() throws {
        #expect(try FormulaLexer.tokenize("\"hello\"") == [.string("hello"), .eof])
    }

    @Test("Empty string")
    func testEmptyString() throws {
        #expect(try FormulaLexer.tokenize("\"\"") == [.string(""), .eof])
    }

    @Test("String with escaped quotes")
    func testStringWithEscapedQuotes() throws {
        #expect(try FormulaLexer.tokenize("\"say \"\"hi\"\"\"") == [.string("say \"hi\""), .eof])
    }

    @Test("String with spaces")
    func testStringWithSpaces() throws {
        #expect(try FormulaLexer.tokenize("\"hello world\"") == [.string("hello world"), .eof])
    }

    // MARK: - Single Token: Booleans

    @Test("True uppercase")
    func testTrueUppercase() throws {
        #expect(try FormulaLexer.tokenize("TRUE") == [.bool(true), .eof])
    }

    @Test("False uppercase")
    func testFalseUppercase() throws {
        #expect(try FormulaLexer.tokenize("FALSE") == [.bool(false), .eof])
    }

    @Test("True lowercase")
    func testTrueLowercase() throws {
        #expect(try FormulaLexer.tokenize("true") == [.bool(true), .eof])
    }

    @Test("True mixed case")
    func testTrueMixedCase() throws {
        #expect(try FormulaLexer.tokenize("True") == [.bool(true), .eof])
    }

    @Test("False lowercase")
    func testFalseLowercase() throws {
        #expect(try FormulaLexer.tokenize("false") == [.bool(false), .eof])
    }

    // MARK: - Single Token: Errors

    @Test("Error value")
    func testErrorValue() throws {
        #expect(try FormulaLexer.tokenize("#VALUE!") == [.error(.value), .eof])
    }

    @Test("Error ref")
    func testErrorRef() throws {
        #expect(try FormulaLexer.tokenize("#REF!") == [.error(.ref), .eof])
    }

    @Test("Error div0")
    func testErrorDiv0() throws {
        #expect(try FormulaLexer.tokenize("#DIV/0!") == [.error(.div0), .eof])
    }

    @Test("Error name")
    func testErrorName() throws {
        #expect(try FormulaLexer.tokenize("#NAME?") == [.error(.name), .eof])
    }

    @Test("Error null")
    func testErrorNull() throws {
        #expect(try FormulaLexer.tokenize("#NULL!") == [.error(.null), .eof])
    }

    @Test("Error num")
    func testErrorNum() throws {
        #expect(try FormulaLexer.tokenize("#NUM!") == [.error(.num), .eof])
    }

    @Test("Error NA")
    func testErrorNA() throws {
        #expect(try FormulaLexer.tokenize("#N/A") == [.error(.na), .eof])
    }

    // MARK: - Single Token: Cell References

    @Test("Simple cell ref")
    func testSimpleCellRef() throws {
        let tokens = try FormulaLexer.tokenize("A1")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
            #expect(!(ref.absoluteColumn))
            #expect(!(ref.absoluteRow))
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Absolute cell ref")
    func testAbsoluteCellRef() throws {
        let tokens = try FormulaLexer.tokenize("$A$1")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
            #expect(ref.absoluteColumn)
            #expect(ref.absoluteRow)
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Absolute column only")
    func testAbsoluteColumnOnly() throws {
        let tokens = try FormulaLexer.tokenize("$A1")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.absoluteColumn)
            #expect(!(ref.absoluteRow))
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Absolute row only")
    func testAbsoluteRowOnly() throws {
        let tokens = try FormulaLexer.tokenize("A$1")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(!(ref.absoluteColumn))
            #expect(ref.absoluteRow)
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Multi letter column")
    func testMultiLetterColumn() throws {
        let tokens = try FormulaLexer.tokenize("AA100")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 27) // AA = 27
            #expect(ref.row == 100)
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Max cell ref")
    func testMaxCellRef() throws {
        let tokens = try FormulaLexer.tokenize("XFD1048576")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 16384) // XFD = 16384
            #expect(ref.row == 1_048_576)
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    @Test("Max absolute cell ref")
    func testMaxAbsoluteCellRef() throws {
        let tokens = try FormulaLexer.tokenize("$XFD$1048576")
        #expect(tokens.count == 2)
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 16384)
            #expect(ref.row == 1_048_576)
            #expect(ref.absoluteColumn)
            #expect(ref.absoluteRow)
        } else {
            Issue.record("Expected cellRef, got \(tokens[0])")
        }
    }

    // MARK: - Single Token: Operators

    @Test("Plus operator")
    func testPlusOperator() throws {
        #expect(try FormulaLexer.tokenize("+") == [.plus, .eof])
    }

    @Test("Minus operator")
    func testMinusOperator() throws {
        #expect(try FormulaLexer.tokenize("-") == [.minus, .eof])
    }

    @Test("Asterisk operator")
    func testAsteriskOperator() throws {
        #expect(try FormulaLexer.tokenize("*") == [.asterisk, .eof])
    }

    @Test("Slash operator")
    func testSlashOperator() throws {
        #expect(try FormulaLexer.tokenize("/") == [.slash, .eof])
    }

    @Test("Caret operator")
    func testCaretOperator() throws {
        #expect(try FormulaLexer.tokenize("^") == [.caret, .eof])
    }

    @Test("Ampersand operator")
    func testAmpersandOperator() throws {
        #expect(try FormulaLexer.tokenize("&") == [.ampersand, .eof])
    }

    @Test("Equals operator")
    func testEqualsOperator() throws {
        // Equals not at position 0 (would be consumed as leading =)
        let tokens = try FormulaLexer.tokenize("A1=B1")
        #expect(tokens[1] == .equals)
    }

    @Test("Not equal operator")
    func testNotEqualOperator() throws {
        #expect(try FormulaLexer.tokenize("<>") == [.notEqual, .eof])
    }

    @Test("Less than operator")
    func testLessThanOperator() throws {
        #expect(try FormulaLexer.tokenize("<") == [.lessThan, .eof])
    }

    @Test("Greater than operator")
    func testGreaterThanOperator() throws {
        #expect(try FormulaLexer.tokenize(">") == [.greaterThan, .eof])
    }

    @Test("Less or equal operator")
    func testLessOrEqualOperator() throws {
        #expect(try FormulaLexer.tokenize("<=") == [.lessOrEqual, .eof])
    }

    @Test("Greater or equal operator")
    func testGreaterOrEqualOperator() throws {
        #expect(try FormulaLexer.tokenize(">=") == [.greaterOrEqual, .eof])
    }

    // MARK: - Single Token: Punctuation

    @Test("Left paren")
    func testLeftParen() throws {
        #expect(try FormulaLexer.tokenize("(") == [.leftParen, .eof])
    }

    @Test("Right paren")
    func testRightParen() throws {
        #expect(try FormulaLexer.tokenize(")") == [.rightParen, .eof])
    }

    @Test("Comma")
    func testComma() throws {
        #expect(try FormulaLexer.tokenize(",") == [.comma, .eof])
    }

    @Test("Colon")
    func testColon() throws {
        #expect(try FormulaLexer.tokenize(":") == [.colon, .eof])
    }

    @Test("Exclamation")
    func testExclamation() throws {
        #expect(try FormulaLexer.tokenize("!") == [.exclamation, .eof])
    }

    // MARK: - Single Token: Identifiers

    @Test("Identifier SUM")
    func testIdentifierSUM() throws {
        #expect(try FormulaLexer.tokenize("SUM") == [.identifier("SUM"), .eof])
    }

    @Test("Identifier lowercase")
    func testIdentifierLowercase() throws {
        #expect(try FormulaLexer.tokenize("myRange") == [.identifier("myRange"), .eof])
    }

    // MARK: - Multi-Token Sequences

    @Test("SUM formula")
    func testSUMFormula() throws {
        let tokens = try FormulaLexer.tokenize("SUM(A1:B5)")
        #expect(tokens[0] == .identifier("SUM"))
        #expect(tokens[1] == .leftParen)
        if case .cellRef(let ref) = tokens[2] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for A1")
        }
        #expect(tokens[3] == .colon)
        if case .cellRef(let ref) = tokens[4] {
            #expect(ref.column == 2)
            #expect(ref.row == 5)
        } else {
            Issue.record("Expected cellRef for B5")
        }
        #expect(tokens[5] == .rightParen)
        #expect(tokens[6] == .eof)
    }

    @Test("Arithmetic expression")
    func testArithmeticExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1+B2*C3")
        #expect(tokens.count == 6) // 3 cellrefs + 2 ops + eof
        #expect(tokens[1] == .plus)
        #expect(tokens[3] == .asterisk)
        #expect(tokens[5] == .eof)
    }

    @Test("Sheet reference")
    func testSheetReference() throws {
        let tokens = try FormulaLexer.tokenize("'Sheet 1'!A1")
        #expect(tokens[0] == .quotedName("Sheet 1"))
        #expect(tokens[1] == .exclamation)
        if case .cellRef(let ref) = tokens[2] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for A1")
        }
        #expect(tokens[3] == .eof)
    }

    @Test("IF formula")
    func testIFFormula() throws {
        let tokens = try FormulaLexer.tokenize("IF(A1>0,\"yes\",\"no\")")
        #expect(tokens[0] == .identifier("IF"))
        #expect(tokens[1] == .leftParen)
        // A1
        if case .cellRef(let ref) = tokens[2] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for A1")
        }
        #expect(tokens[3] == .greaterThan)
        #expect(tokens[4] == .number(0))
        #expect(tokens[5] == .comma)
        #expect(tokens[6] == .string("yes"))
        #expect(tokens[7] == .comma)
        #expect(tokens[8] == .string("no"))
        #expect(tokens[9] == .rightParen)
        #expect(tokens[10] == .eof)
    }

    @Test("Leading equals consumed")
    func testLeadingEqualsConsumed() throws {
        let tokens = try FormulaLexer.tokenize("=A1+B1")
        // Leading = should be consumed; first token is cellRef A1
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for A1, got \(tokens[0])")
        }
        #expect(tokens[1] == .plus)
        #expect(tokens[3] == .eof)
    }

    @Test("Concatenation")
    func testConcatenation() throws {
        let tokens = try FormulaLexer.tokenize("A1&\" \"&B1")
        #expect(tokens[1] == .ampersand)
        #expect(tokens[2] == .string(" "))
        #expect(tokens[3] == .ampersand)
    }

    @Test("Comparison chain")
    func testComparisonChain() throws {
        let tokens = try FormulaLexer.tokenize("A1<>B1")
        #expect(tokens[1] == .notEqual)
    }

    @Test("Less or equal expression")
    func testLessOrEqualExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1<=B1")
        #expect(tokens[1] == .lessOrEqual)
    }

    @Test("Nested functions")
    func testNestedFunctions() throws {
        let tokens = try FormulaLexer.tokenize("SUM(IF(A1>0,A1,0))")
        #expect(tokens[0] == .identifier("SUM"))
        #expect(tokens[1] == .leftParen)
        #expect(tokens[2] == .identifier("IF"))
        #expect(tokens[3] == .leftParen)
    }

    @Test("Leading equals with SUM")
    func testLeadingEqualsWithSUM() throws {
        let tokens = try FormulaLexer.tokenize("=SUM(A1)")
        #expect(tokens[0] == .identifier("SUM"))
        #expect(tokens[1] == .leftParen)
    }

    // MARK: - Edge Cases

    @Test("Whitespace handling")
    func testWhitespaceHandling() throws {
        let tokens = try FormulaLexer.tokenize("A1 + B1")
        if case .cellRef(let ref) = tokens[0] {
            #expect(ref.column == 1)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for A1")
        }
        #expect(tokens[1] == .plus)
        if case .cellRef(let ref) = tokens[2] {
            #expect(ref.column == 2)
            #expect(ref.row == 1)
        } else {
            Issue.record("Expected cellRef for B1")
        }
        #expect(tokens[3] == .eof)
    }

    @Test("Identifier vs cell ref XFE 1")
    func testIdentifierVsCellRefXFE1() throws {
        // XFE = column 16385, exceeds max (16384) -> identifier
        #expect(try FormulaLexer.tokenize("XFE1") == [.identifier("XFE1"), .eof])
    }

    @Test("Identifier vs cell ref SUM")
    func testIdentifierVsCellRefSUM() throws {
        // SUM has no trailing digits -> identifier
        #expect(try FormulaLexer.tokenize("SUM") == [.identifier("SUM"), .eof])
    }

    @Test("Cell ref A 1")
    func testCellRefA1() throws {
        // A1 -> valid cell ref: column 1, row 1, neither half absolute.
        #expect(try FormulaLexer.tokenize("A1") == [.cellRef(CellRef(column: 1, row: 1)), .eof])
    }

    @Test("Quoted name with escaped quote")
    func testQuotedNameWithEscapedQuote() throws {
        let tokens = try FormulaLexer.tokenize("'It''s a sheet'")
        #expect(tokens[0] == .quotedName("It's a sheet"))
        #expect(tokens[1] == .eof)
    }

    @Test("Error with slash DIV 0")
    func testErrorWithSlashDIV0() throws {
        // #DIV/0! should not confuse the / with division
        let tokens = try FormulaLexer.tokenize("#DIV/0!")
        #expect(tokens[0] == .error(.div0))
        #expect(tokens[1] == .eof)
    }

    @Test("Empty string literal")
    func testEmptyStringLiteral() throws {
        #expect(try FormulaLexer.tokenize("\"\"") == [.string(""), .eof])
    }

    @Test("Row zero is identifier")
    func testRowZeroIsIdentifier() throws {
        // A0 -> row 0 is invalid -> identifier
        #expect(try FormulaLexer.tokenize("A0") == [.identifier("A0"), .eof])
    }

    @Test("Eof always appended")
    func testEofAlwaysAppended() throws {
        let tokens = try FormulaLexer.tokenize("")
        #expect(tokens == [.eof])
    }

    @Test("Power expression")
    func testPowerExpression() throws {
        let tokens = try FormulaLexer.tokenize("A1^2")
        #expect(tokens[1] == .caret)
        #expect(tokens[2] == .number(2))
    }

    // MARK: - Error Cases

    @Test("Unterminated string")
    func testUnterminatedString() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaLexer.tokenize("\"hello")
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedEnd(let expected) = parseError.kind {
            #expect(expected == "closing quote")
        } else {
            Issue.record("Expected unexpectedEnd, got \(parseError.kind)")
        }
    }

    @Test("Invalid character")
    func testInvalidCharacter() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaLexer.tokenize("@")
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken(let expected, let found) = parseError.kind {
            #expect(expected == "valid token")
            #expect(found == "@")
        } else {
            Issue.record("Expected unexpectedToken, got \(parseError.kind)")
        }
    }

    @Test("Unterminated quoted name")
    func testUnterminatedQuotedName() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaLexer.tokenize("'Sheet")
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedEnd(let expected) = parseError.kind {
            #expect(expected == "closing single quote")
        } else {
            Issue.record("Expected unexpectedEnd, got \(parseError.kind)")
        }
    }

    @Test("Unknown error literal")
    func testUnknownErrorLiteral() throws {
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaLexer.tokenize("#WHAT!")
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken(let expected, _) = parseError.kind {
            #expect(expected == "Excel error")
        } else {
            Issue.record("Expected unexpectedToken, got \(parseError.kind)")
        }
    }

    @Test("Invalid absolute cell ref")
    func testInvalidAbsoluteCellRef() throws {
        // $XFE$1 -> has $ so must be cell ref, but XFE=16385 exceeds max
        let error = try #require(#expect(throws: (any Error).self) {
            try FormulaLexer.tokenize("$XFE$1")
        })
        guard let parseError = error as? FormulaParseError else {
            Issue.record("Expected FormulaParseError")
            return
        }
        if case .unexpectedToken(let expected, _) = parseError.kind {
            #expect(expected == "valid cell reference")
        } else {
            Issue.record("Expected unexpectedToken, got \(parseError.kind)")
        }
    }

    // MARK: - Identifiers that look like cell references

    /// **A long identifier used to crash the lexer.** `parseCellReference` accumulated the
    /// column in base 26 and checked the bound only afterwards, so a word of fourteen or
    /// more letters followed by digits overflowed `Int` before anything rejected it —
    /// `Swift runtime failure: arithmetic overflow`, taking the whole process with it.
    ///
    /// This is not an exotic input. It is what a spreadsheet's own defined names look like,
    /// and it was found by a real workbook: a rent calculator in the corpus.
    @Test("Long identifier is not A cell reference")
    func testLongIdentifierIsNotACellReference() throws {
        let tokens = try FormulaLexer.tokenize("AnnualIncreasePct2022")
        #expect(!(tokens.contains { if case .cellRef = $0 { return true } else { return false } }), "a twenty-letter identifier is not a cell reference")
    }

    /// The boundary itself: thirteen letters is within `Int`, fourteen was not.
    @Test("Very long letter runs do not overflow")
    func testVeryLongLetterRunsDoNotOverflow() throws {
        for count in [13, 14, 20, 60] {
            let word = String(repeating: "A", count: count) + "1"
            #expect(throws: Never.self) { try FormulaLexer.tokenize(word) }
        }
    }

    /// **A non-ASCII letter is not a column.** `Character.isLetter` is true for `é`, whose
    /// uppercase scalar is 201, so the same arithmetic read it as column 137 rather than
    /// rejecting it — a wrong answer rather than a crash, and the harder kind to notice.
    @Test("Accented letter is not A column")
    func testAccentedLetterIsNotAColumn() throws {
        let tokens = try FormulaLexer.tokenize("é1")
        #expect(!(tokens.contains { if case .cellRef = $0 { return true } else { return false } }), "é1 is not a cell reference")
    }

    /// The real references still lex, including the far corner of the grid.
    @Test("Genuine references still parse")
    func testGenuineReferencesStillParse() throws {
        for reference in ["A1", "Z99", "AA1", "XFD1048576", "$B$7"] {
            let tokens = try FormulaLexer.tokenize(reference)
            #expect(tokens.contains { if case .cellRef = $0 { return true } else { return false } }, "\(reference) should lex as a reference")
        }
    }

    /// One past the last column is rejected rather than clamped.
    @Test("Beyond the last column is not A reference")
    func testBeyondTheLastColumnIsNotAReference() throws {
        let tokens = try FormulaLexer.tokenize("XFE1")
        #expect(!(tokens.contains { if case .cellRef = $0 { return true } else { return false } }))
    }
}
