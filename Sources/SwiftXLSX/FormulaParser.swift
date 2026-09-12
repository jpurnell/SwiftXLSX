import SwiftExcelCore
/// Parses Excel formula token arrays into ``FormulaAST`` trees using Pratt
/// (precedence-climbing) parsing.
///
/// All binary operators are left-associative, matching Excel's evaluation
/// semantics (including `^`, which differs from the mathematical convention).
///
/// ```swift
/// let ast = try FormulaParser.parse("=A1+1")
/// // ast == .add(.cellRef(CellRef("A1")), .number(1))
/// ```
public enum FormulaParser {

    // MARK: - Public API

    /// Parse a formula string into an AST. Leading `=` is optional.
    ///
    /// - Parameter formula: The Excel formula to parse.
    /// - Returns: The parsed ``FormulaAST``.
    /// - Throws: ``FormulaParseError`` if the formula is invalid.
    public static func parse(_ formula: String) throws -> FormulaAST {
        let tokens = try FormulaLexer.tokenize(formula)
        return try parseTokens(tokens, formula: formula)
    }

    /// Parse a token array into an AST. Used internally and for testing.
    ///
    /// - Parameters:
    ///   - tokens: The token array to parse (must end with `.eof`).
    ///   - formula: The original formula string for error diagnostics.
    /// - Returns: The parsed ``FormulaAST``.
    /// - Throws: ``FormulaParseError`` if the token sequence is invalid.
    static func parseTokens(_ tokens: [FormulaToken], formula: String = "") throws -> FormulaAST {
        var parser = TokenParser(tokens: tokens, formula: formula)
        let ast = try parser.parseExpression()

        // Ensure all tokens have been consumed
        guard parser.currentToken == .eof else {
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "end of expression",
                    found: parser.describeToken(parser.currentToken)
                ),
                offset: parser.position,
                formula: formula
            )
        }

        return ast
    }
}

// MARK: - Precedence

/// Operator precedence levels for Pratt parsing.
///
/// Higher values bind more tightly:
/// - 1: Comparison (`=`, `<>`, `<`, `>`, `<=`, `>=`)
/// - 2: Concatenation (`&`)
/// - 3: Addition/subtraction (`+`, `-`)
/// - 4: Multiplication/division (`*`, `/`)
/// - 5: Exponentiation (`^`)
/// - 6: Unary prefix (`-`, `+`)
private enum Precedence {
    static let comparison = 1
    static let concatenation = 2
    static let addSubtract = 3
    static let multiplyDivide = 4
    static let power = 5
    static let unary = 6
}

// MARK: - TokenParser

/// Internal mutable state for the Pratt parser.
private struct TokenParser {
    let tokens: [FormulaToken]
    let formula: String
    var position: Int = 0
    var depth: Int = 0
    private static let maxDepth = 256

    /// The token at the current position.
    var currentToken: FormulaToken {
        if position < tokens.count {
            return tokens[position]
        }
        return .eof
    }

    /// The token after the current one, without consuming anything.
    ///
    /// One token of lookahead is enough to tell `1:1` — a whole row — from a
    /// number that merely happens to start an expression.
    var peek: FormulaToken {
        position + 1 < tokens.count ? tokens[position + 1] : .eof
    }

    /// Advances past the current token and returns it.
    @discardableResult
    mutating func advance() -> FormulaToken {
        let token = currentToken
        if position < tokens.count {
            position += 1
        }
        return token
    }

    /// Expects a specific token at the current position and advances past it.
    ///
    /// - Parameter expected: The expected token.
    /// - Throws: ``FormulaParseError`` if the current token does not match.
    mutating func expect(_ expected: FormulaToken) throws {
        guard currentToken == expected else {
            if currentToken == .eof {
                throw FormulaParseError(
                    kind: .unexpectedEnd(expected: describeToken(expected)),
                    offset: position,
                    formula: formula
                )
            }
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: describeToken(expected),
                    found: describeToken(currentToken)
                ),
                offset: position,
                formula: formula
            )
        }
        advance()
    }

    /// Returns the infix precedence of a token, or `nil` if it is not an infix operator.
    func infixPrecedence(of token: FormulaToken) -> Int? {
        switch token {
        case .equals, .notEqual, .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual:
            return Precedence.comparison
        case .ampersand:
            return Precedence.concatenation
        case .plus, .minus:
            return Precedence.addSubtract
        case .asterisk, .slash:
            return Precedence.multiplyDivide
        case .caret:
            return Precedence.power
        default:
            return nil
        }
    }

    /// Produces a human-readable description of a token for error messages.
    func describeToken(_ token: FormulaToken) -> String {
        switch token {
        case .number(let n): return "number(\(n))"
        case .string(let s): return "string(\"\(s)\")"
        case .bool(let b): return b ? "TRUE" : "FALSE"
        case .error(let e): return e.rawValue
        case .cellRef(let r): return "cell(\(r.reference))"
        case .quotedName(let n): return "'\(n)'"
        case .identifier(let n): return "identifier(\(n))"
        case .columnRef(let c): return "column(\(c))"
        case .rowRef(let r): return "row(\(r))"
        case .plus: return "+"
        case .minus: return "-"
        case .asterisk: return "*"
        case .slash: return "/"
        case .caret: return "^"
        case .ampersand: return "&"
        case .equals: return "="
        case .notEqual: return "<>"
        case .lessThan: return "<"
        case .greaterThan: return ">"
        case .lessOrEqual: return "<="
        case .greaterOrEqual: return ">="
        case .leftParen: return "("
        case .rightParen: return ")"
        case .comma: return ","
        case .colon: return ":"
        case .exclamation: return "!"
        case .eof: return "end of formula"
        }
    }

    // MARK: - Expression Parsing

    /// Parses an expression with the given minimum precedence.
    ///
    /// Implements the Pratt (precedence climbing) algorithm. All binary
    /// operators use left-associativity (precedence + 1 for recursive call).
    ///
    /// - Parameter minPrecedence: The minimum binding power required.
    /// - Returns: The parsed ``FormulaAST``.
    mutating func parseExpression(minPrecedence: Int = 0) throws -> FormulaAST {
        guard depth < Self.maxDepth else {
            throw FormulaParseError(kind: .formulaTooComplex, offset: position, formula: formula)
        }
        depth += 1
        defer { depth -= 1 }

        if currentToken == .eof && minPrecedence == 0 {
            throw FormulaParseError(kind: .emptyFormula, offset: 0, formula: formula)
        }

        var left = try parsePrefix()

        while let prec = infixPrecedence(of: currentToken), prec >= minPrecedence {
            let operatorToken = advance()
            // +1 for left-associativity (all Excel binary ops are left-assoc)
            let right = try parseExpression(minPrecedence: prec + 1)
            left = try makeBinaryNode(operatorToken, left: left, right: right)
        }

        return left
    }

    // MARK: - Prefix Parsing

    /// Parses a prefix expression (atom, unary operator, or parenthesized group).
    mutating func parsePrefix() throws -> FormulaAST {
        guard currentToken != .eof else {
            throw FormulaParseError(
                kind: .unexpectedEnd(expected: "expression"),
                offset: position,
                formula: formula
            )
        }
        let token = currentToken

        switch token {
        case .number(let value):
            advance()
            return .number(value)

        case .string(let value):
            advance()
            return .text(value)

        case .bool(let value):
            advance()
            return .bool(value)

        case .error(let value):
            advance()
            return .error(value)

        case .cellRef(let ref):
            advance()
            return try parseCellRefOrRange(ref)

        case .number(let value) where TokenParser.rowIndex(of: value) != nil && peek == .colon:
            guard let firstRow = TokenParser.rowIndex(of: value) else { break }
            let saved = position
            advance()
            advance()
            if case .number(let lastValue) = currentToken,
               let lastRow = TokenParser.rowIndex(of: lastValue) {
                advance()
                return .cellRange(TokenParser.rowSpan(from: firstRow, to: lastRow))
            }
            position = saved

        case .columnRef, .rowRef:
            let start = currentToken
            advance()
            guard currentToken == .colon else {
                throw FormulaParseError(
                    kind: .unexpectedToken(expected: ":", found: describeToken(currentToken)),
                    offset: position,
                    formula: formula
                )
            }
            return try parsePartialRange(start)

        case .identifier(let name):
            advance()
            return try parseIdentifier(name)

        case .quotedName(let name):
            advance()
            return try parseSheetReference(name)

        case .minus:
            advance()
            let operand = try parseExpression(minPrecedence: Precedence.unary)
            return .negate(operand)

        case .plus:
            // Unary plus is identity
            advance()
            return try parseExpression(minPrecedence: Precedence.unary)

        case .leftParen:
            advance()
            let expr = try parseExpression()
            try expect(.rightParen)
            return expr

        default:
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "expression",
                    found: describeToken(token)
                ),
                offset: position,
                formula: formula
            )
        }
    }

    // MARK: - Cell Reference / Range

    /// After consuming a `.cellRef`, checks for `:` to parse a range.
    /// A range whose ends name only columns, or only rows.
    ///
    /// Called with the opening token already consumed and `.colon` current.
    private mutating func parsePartialRange(_ start: FormulaToken) throws -> FormulaAST {
        advance()
        switch (start, currentToken) {
        case (.columnRef(let first), .columnRef(let last)):
            advance()
            return .cellRange(TokenParser.columnSpan(from: first, to: last))
        case (.rowRef(let first), .rowRef(let last)):
            advance()
            return .cellRange(TokenParser.rowSpan(from: first, to: last))
        default:
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "a matching column or row reference",
                    found: describeToken(currentToken)
                ),
                offset: position,
                formula: formula
            )
        }
    }

    private mutating func parseCellRefOrRange(_ startRef: CellRef) throws -> FormulaAST {
        if currentToken == .colon {
            advance()
            guard case .cellRef(let endRef) = currentToken else {
                throw FormulaParseError(
                    kind: .unexpectedToken(
                        expected: "cell reference",
                        found: describeToken(currentToken)
                    ),
                    offset: position,
                    formula: formula
                )
            }
            advance()
            return .cellRange(CellRange(from: startRef, to: endRef))
        }
        return .cellRef(startRef)
    }


    /// Excel's grid: 16,384 columns by 1,048,576 rows.
    ///
    /// A whole-column reference is a range over every row of that column, and a
    /// whole-row reference is a range over every column of that row. Expressing
    /// them this way needs no new `FormulaAST` case — they are ranges, and saying
    /// so keeps every consumer working unchanged.
    static let lastColumn = 16_384
    static let lastRow = 1_048_576

    /// The range `$E:$G` names.
    static func columnSpan(from first: Int, to last: Int) -> CellRange {
        CellRange(
            from: CellRef(column: min(first, last), row: 1),
            to: CellRef(column: max(first, last), row: lastRow))
    }

    /// The range `$2:$3` names.
    static func rowSpan(from first: Int, to last: Int) -> CellRange {
        CellRange(
            from: CellRef(column: 1, row: min(first, last)),
            to: CellRef(column: lastColumn, row: max(first, last)))
    }

    // MARK: - Identifier Dispatch

    /// The row a number names, if it names one.
    ///
    /// `1:1` is a whole row written without `$`. A bare number lexes as a number,
    /// so the parser recognises the pair rather than the lexer recognising either
    /// half — the same rule as `A:A`, where a lone `A` could be a defined name.
    static func rowIndex(of value: Double) -> Int? {
        guard value == value.rounded(), value >= 1, value <= Double(lastRow) else { return nil }
        return Int(value)
    }

    /// The column a word names, if it names one.
    ///
    /// `A` and `IV` are columns; `days_per_week` is not, and neither is anything
    /// past Excel's 16,384th column.
    static func columnIndex(of word: String) -> Int? {
        guard !word.isEmpty, word.allSatisfy(\.isLetter) else { return nil }
        var column = 0
        for ch in word {
            guard let value = ch.uppercased().unicodeScalars.first?.value else { return nil }
            column = column * 26 + Int(value - 64)
        }
        return (1...lastColumn).contains(column) ? column : nil
    }

    /// After consuming an `.identifier`, dispatches to function call, sheet
    /// reference, or named range based on the next token.
    private mutating func parseIdentifier(_ name: String) throws -> FormulaAST {
        guard currentToken != .eof else { return .namedRange(name) }

        // `A:A` without the `$`. Only a column when both ends are columns —
        // otherwise this is a defined name and the colon is somebody else's
        // problem.
        if currentToken == .colon, let first = TokenParser.columnIndex(of: name) {
            let saved = position
            advance()
            if case .identifier(let endName) = currentToken,
               let last = TokenParser.columnIndex(of: endName) {
                advance()
                return .cellRange(TokenParser.columnSpan(from: first, to: last))
            }
            position = saved
        }
        switch currentToken {
        case .leftParen:
            return try parseFunctionCall(name)
        case .exclamation:
            return try parseSheetReference(name)
        default:
            return .namedRange(name)
        }
    }

    // MARK: - Function Call

    /// Parses a function call: `NAME(arg1, arg2, ...)`.
    /// One argument, which may be absent.
    ///
    /// Absent means the next token closes the list or opens the next argument —
    /// nothing stands between this comma and the one after it.
    private mutating func parseArgument() throws -> FormulaAST {
        if currentToken == .comma || currentToken == .rightParen {
            return .missing
        }
        return try parseExpression()
    }

    private mutating func parseFunctionCall(_ name: String) throws -> FormulaAST {
        guard currentToken == .leftParen else {
            throw FormulaParseError(
                kind: .unexpectedToken(expected: "(", found: describeToken(currentToken)),
                offset: position,
                formula: formula
            )
        }
        try expect(.leftParen)
        var args: [FormulaAST] = []

        // An argument may be left out. `IFERROR(x,)` omits the second and
        // `ADDRESS(r, c, 1, , "S")` the fourth; the comma still marks the place,
        // because position decides which parameter is which.
        if currentToken != .rightParen {
            args.append(try parseArgument())

            while currentToken == .comma {
                advance()
                args.append(try parseArgument())
            }
        }

        try expect(.rightParen)
        return .function(name.uppercased(), args)
    }

    // MARK: - Sheet Reference

    /// Parses a sheet reference: `SheetName!A1` or `SheetName!A1:B5`.
    ///
    /// Called after consuming `.identifier(name)` or `.quotedName(name)`.
    private mutating func parseSheetReference(_ name: String) throws -> FormulaAST {
        try expect(.exclamation)

        // A sheet-qualified whole column or row: `Sheet2!$E:$E`.
        if case .columnRef = currentToken {
            let start = currentToken
            advance()
            guard currentToken == .colon, case .cellRange(let range) = try parsePartialRange(start)
            else {
                throw FormulaParseError(
                    kind: .unexpectedToken(expected: ":", found: describeToken(currentToken)),
                    offset: position, formula: formula
                )
            }
            return .sheetRef(SheetReference(sheet: name, range: range))
        }
        if case .rowRef = currentToken {
            let start = currentToken
            advance()
            guard currentToken == .colon, case .cellRange(let range) = try parsePartialRange(start)
            else {
                throw FormulaParseError(
                    kind: .unexpectedToken(expected: ":", found: describeToken(currentToken)),
                    offset: position, formula: formula
                )
            }
            return .sheetRef(SheetReference(sheet: name, range: range))
        }

        // `Comp!1:1` — a whole row without the `$`, on a named sheet.
        if case .number(let firstValue) = currentToken, let firstRow = TokenParser.rowIndex(of: firstValue) {
            let saved = position
            advance()
            if currentToken == .colon {
                advance()
                if case .number(let lastValue) = currentToken,
                   let lastRow = TokenParser.rowIndex(of: lastValue) {
                    advance()
                    return .sheetRef(SheetReference(
                        sheet: name, range: TokenParser.rowSpan(from: firstRow, to: lastRow)))
                }
            }
            position = saved
        }

        // `'Paid Cost - Input+Calc'!A:A` — a whole column without the `$`, on a
        // named sheet. Same rule as the unqualified form: a column only when both
        // ends are columns.
        if case .identifier(let first) = currentToken, let firstColumn = TokenParser.columnIndex(of: first) {
            let saved = position
            advance()
            if currentToken == .colon {
                advance()
                if case .identifier(let last) = currentToken,
                   let lastColumn = TokenParser.columnIndex(of: last) {
                    advance()
                    return .sheetRef(SheetReference(
                        sheet: name,
                        range: TokenParser.columnSpan(from: firstColumn, to: lastColumn)))
                }
            }
            position = saved
        }

        // `CB_DATA_!#REF!` — the sheet is named and the reference on it is broken.
        // The error is the value, and saying so keeps the formula readable rather
        // than discarding the whole thing.
        if case .error(let excelError) = currentToken {
            advance()
            return .error(excelError)
        }

        guard case .cellRef(let startRef) = currentToken else {
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "cell reference",
                    found: describeToken(currentToken)
                ),
                offset: position,
                formula: formula
            )
        }
        advance()

        if currentToken == .colon {
            advance()
            guard case .cellRef(let endRef) = currentToken else {
                throw FormulaParseError(
                    kind: .unexpectedToken(
                        expected: "cell reference",
                        found: describeToken(currentToken)
                    ),
                    offset: position,
                    formula: formula
                )
            }
            advance()
            return .sheetRef(SheetReference(sheet: name, range: CellRange(from: startRef, to: endRef)))
        }

        return .sheetRef(SheetReference(sheet: name, cell: startRef))
    }

    // MARK: - Binary Node Construction

    /// Creates the appropriate ``FormulaAST`` binary node for the given operator token.
    private func makeBinaryNode(
        _ op: FormulaToken,
        left: FormulaAST,
        right: FormulaAST
    ) throws -> FormulaAST {
        switch op {
        case .plus: return .add(left, right)
        case .minus: return .subtract(left, right)
        case .asterisk: return .multiply(left, right)
        case .slash: return .divide(left, right)
        case .caret: return .power(left, right)
        case .ampersand: return .concatenate(left, right)
        case .equals: return .equal(left, right)
        case .notEqual: return .notEqual(left, right)
        case .lessThan: return .lessThan(left, right)
        case .greaterThan: return .greaterThan(left, right)
        case .lessOrEqual: return .lessOrEqual(left, right)
        case .greaterOrEqual: return .greaterOrEqual(left, right)
        default:
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "binary operator",
                    found: describeToken(op)
                ),
                offset: position,
                formula: formula
            )
        }
    }
}
