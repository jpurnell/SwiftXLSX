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

    // MARK: - Identifier Dispatch

    /// After consuming an `.identifier`, dispatches to function call, sheet
    /// reference, or named range based on the next token.
    private mutating func parseIdentifier(_ name: String) throws -> FormulaAST {
        guard currentToken != .eof else { return .namedRange(name) }
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

        if currentToken != .rightParen {
            let firstArg = try parseExpression()
            args.append(firstArg)

            while currentToken == .comma {
                advance()
                let nextArg = try parseExpression()
                args.append(nextArg)
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
