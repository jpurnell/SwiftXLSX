import SwiftExcelCore
/// Tokenizes an Excel formula string into a sequence of ``FormulaToken`` values.
///
/// The lexer handles all standard Excel formula constructs including cell references
/// (with absolute `$` markers), string literals with doubled-quote escaping, error
/// literals like `#DIV/0!`, quoted sheet names, boolean literals, and all arithmetic
/// and comparison operators.
///
/// ```swift
/// let tokens = try FormulaLexer.tokenize("=SUM(A1:B5)")
/// // [.identifier("SUM"), .leftParen, .cellRef(...), .colon, .cellRef(...), .rightParen, .eof]
/// ```
public enum FormulaLexer {

    // MARK: - Maximum Excel limits

    /// Maximum valid column number in Excel (XFD = 16384).
    private static let maxColumn = 16384

    /// Maximum valid row number in Excel.
    private static let maxRow = 1_048_576

    /// Tokenize a formula string. Leading `=` is consumed and discarded.
    ///
    /// - Parameter formula: The Excel formula string to tokenize.
    /// - Returns: An array of ``FormulaToken`` values, always ending with `.eof`.
    /// - Throws: ``FormulaParseError`` if the formula contains invalid syntax.
    public static func tokenize(_ formula: String) throws -> [FormulaToken] {
        let chars = Array(formula)
        var pos = 0
        var tokens: [FormulaToken] = []
        var consumedLeadingEquals = false

        while pos < chars.count {
            let ch = chars[pos]

            // 1. Whitespace: skip silently
            if ch.isWhitespace {
                pos += 1
                continue
            }

            // 2. Leading = at position 0 (or after leading whitespace)
            if ch == "=" && !consumedLeadingEquals && tokens.isEmpty {
                consumedLeadingEquals = true
                pos += 1
                continue
            }

            // 3. Digits / decimal point: number literal
            if ch.isNumber || (ch == "." && pos + 1 < chars.count && chars[pos + 1].isNumber) {
                let token = try scanNumber(chars: chars, pos: &pos, formula: formula)
                tokens.append(token)
                continue
            }

            // 4. String literal
            if ch == "\"" {
                let token = try scanString(chars: chars, pos: &pos, formula: formula)
                tokens.append(token)
                continue
            }

            // 5. Error literal (#VALUE!, #DIV/0!, etc.)
            if ch == "#" {
                let token = try scanError(chars: chars, pos: &pos, formula: formula)
                tokens.append(token)
                continue
            }

            // 6. Quoted sheet name
            if ch == "'" {
                let token = try scanQuotedName(chars: chars, pos: &pos, formula: formula)
                tokens.append(token)
                continue
            }

            // 6a. A trailing % scales the number just read: `0.25%` is 0.0025.

            // A suffix, not an operator — nothing follows it to operate on.

            if ch == "%", case .number(let value)? = tokens.last {

                tokens[tokens.count - 1] = .number(value / 100)

                pos += 1

                continue

            }


            // 7. $, letter or underscore: cell ref, boolean, or identifier.
            // A leading underscore is how Excel marks a function it did not
            // define itself — `_xll.` for an add-in, `_xlfn.` for one newer than
            // the file format — and it is legal at the start of a defined name.
            if ch == "$" || ch.isLetter || ch == "_" {
                let token = try scanWordOrCellRef(chars: chars, pos: &pos, formula: formula)
                tokens.append(token)
                continue
            }

            // 8-9. Operators (check multi-char first)
            if ch == "<" {
                pos += 1
                if pos < chars.count && chars[pos] == ">" {
                    pos += 1
                    tokens.append(.notEqual)
                } else if pos < chars.count && chars[pos] == "=" {
                    pos += 1
                    tokens.append(.lessOrEqual)
                } else {
                    tokens.append(.lessThan)
                }
                continue
            }

            if ch == ">" {
                pos += 1
                if pos < chars.count && chars[pos] == "=" {
                    pos += 1
                    tokens.append(.greaterOrEqual)
                } else {
                    tokens.append(.greaterThan)
                }
                continue
            }

            // Single-character operators and punctuation
            if let token = singleCharToken(ch) {
                pos += 1
                tokens.append(token)
                continue
            }

            // 11. Unknown character
            throw FormulaParseError(
                kind: .unexpectedToken(
                    expected: "valid token",
                    found: String(ch)
                ),
                offset: pos,
                formula: formula
            )
        }

        tokens.append(.eof)
        return tokens
    }

    // MARK: - Single character token mapping

    /// Maps a single character to its corresponding token, if any.
    ///
    /// - Parameter ch: The character to check.
    /// - Returns: The matching ``FormulaToken``, or `nil` if not a single-char token.
    private static func singleCharToken(_ ch: Character) -> FormulaToken? {
        switch ch {
        case "+": return .plus
        case "-": return .minus
        case "*": return .asterisk
        case "/": return .slash
        case "^": return .caret
        case "&": return .ampersand
        case "=": return .equals
        case "(": return .leftParen
        case ")": return .rightParen
        case ",": return .comma
        case ":": return .colon
        case "!": return .exclamation // LIVE: public API for consumers
        default: return nil
        }
    }

    // MARK: - Number scanning

    /// Scans a numeric literal from the character array.
    ///
    /// Handles integers (`42`), decimals (`3.14`), and leading decimal (`.5`).
    ///
    /// - Parameters:
    ///   - chars: The character array being scanned.
    ///   - pos: The current scan position (updated on return).
    ///   - formula: The original formula string for error reporting.
    /// - Returns: A `.number` token.
    /// - Throws: ``FormulaParseError`` if the number cannot be parsed.
    private static func scanNumber(
        chars: [Character],
        pos: inout Int,
        formula: String
    ) throws -> FormulaToken {
        let start = pos
        var hasDecimal = false

        while pos < chars.count {
            let ch = chars[pos]
            if ch.isNumber {
                pos += 1
            } else if ch == "." && !hasDecimal {
                hasDecimal = true
                pos += 1
            } else {
                break
            }
        }

        let numStr = String(chars[start..<pos])
        guard let value = Double(numStr) else {
            throw FormulaParseError(
                kind: .unexpectedToken(expected: "number", found: numStr),
                offset: start,
                formula: formula
            )
        }
        return .number(value)
    }

    // MARK: - String scanning

    /// Scans a string literal, handling `""` escaped quotes.
    ///
    /// - Parameters:
    ///   - chars: The character array being scanned.
    ///   - pos: The current scan position (updated on return).
    ///   - formula: The original formula string for error reporting.
    /// - Returns: A `.string` token with outer quotes stripped.
    /// - Throws: ``FormulaParseError`` if the string is unterminated.
    private static func scanString(
        chars: [Character],
        pos: inout Int,
        formula: String
    ) throws -> FormulaToken {
        let start = pos
        pos += 1 // skip opening quote
        var result: [Character] = []

        while pos < chars.count {
            let ch = chars[pos]
            if ch == "\"" {
                pos += 1
                // Check for escaped quote ""
                if pos < chars.count && chars[pos] == "\"" {
                    result.append("\"")
                    pos += 1
                } else {
                    return .string(String(result))
                }
            } else {
                result.append(ch)
                pos += 1
            }
        }

        throw FormulaParseError(
            kind: .unexpectedEnd(expected: "closing quote"),
            offset: start,
            formula: formula
        )
    }

    // MARK: - Error literal scanning

    /// Scans an Excel error literal (e.g., `#VALUE!`, `#DIV/0!`, `#N/A`).
    ///
    /// - Parameters:
    ///   - chars: The character array being scanned.
    ///   - pos: The current scan position (updated on return).
    ///   - formula: The original formula string for error reporting.
    /// - Returns: An `.error` token.
    /// - Throws: ``FormulaParseError`` if the error literal is not recognized.
    private static func scanError(
        chars: [Character],
        pos: inout Int,
        formula: String
    ) throws -> FormulaToken {
        let start = pos

        // Collect characters that could form an error literal.
        // Error literals contain: #, letters, /, !, ?  (e.g., #DIV/0!, #N/A, #NAME?)
        // We scan until we hit a terminator character (!, ?) or run out of valid chars.
        var errorStr: [Character] = []
        errorStr.append(chars[pos])
        pos += 1

        while pos < chars.count {
            let ch = chars[pos]
            if ch.isLetter || ch == "/" || ch.isNumber {
                errorStr.append(ch)
                pos += 1
            } else if ch == "!" || ch == "?" {
                errorStr.append(ch)
                pos += 1
                break
            } else {
                break
            }
        }

        let errorString = String(errorStr)
        guard let excelError = ExcelError(rawValue: errorString) else {
            throw FormulaParseError(
                kind: .unexpectedToken(expected: "Excel error", found: errorString),
                offset: start,
                formula: formula
            )
        }
        return .error(excelError)
    }

    // MARK: - Quoted name scanning

    /// Scans a quoted sheet name (e.g., `'My Sheet'`), handling `''` escaped quotes.
    ///
    /// The `!` after the closing quote is emitted as a separate `.exclamation` token.
    ///
    /// - Parameters:
    ///   - chars: The character array being scanned.
    ///   - pos: The current scan position (updated on return).
    ///   - formula: The original formula string for error reporting.
    /// - Returns: A `.quotedName` token with outer quotes stripped.
    /// - Throws: ``FormulaParseError`` if the quoted name is unterminated.
    private static func scanQuotedName(
        chars: [Character],
        pos: inout Int,
        formula: String
    ) throws -> FormulaToken {
        let start = pos
        pos += 1 // skip opening quote
        var result: [Character] = []

        while pos < chars.count {
            let ch = chars[pos]
            if ch == "'" {
                pos += 1
                // Check for escaped quote ''
                if pos < chars.count && chars[pos] == "'" {
                    result.append("'")
                    pos += 1
                } else {
                    return .quotedName(String(result))
                }
            } else {
                result.append(ch)
                pos += 1
            }
        }

        throw FormulaParseError(
            kind: .unexpectedEnd(expected: "closing single quote"),
            offset: start,
            formula: formula
        )
    }

    // MARK: - Word / Cell Reference scanning

    /// Scans a word that could be a boolean, cell reference, or identifier.
    ///
    /// Disambiguation rules:
    /// 1. `TRUE` / `FALSE` (case-insensitive) -> `.bool`
    /// 2. Valid cell reference pattern with valid bounds -> `.cellRef`
    /// 3. Had `$` prefix but failed validation -> error (invalid cell ref)
    /// 4. Otherwise -> `.identifier`
    ///
    /// - Parameters:
    ///   - chars: The character array being scanned.
    ///   - pos: The current scan position (updated on return).
    ///   - formula: The original formula string for error reporting.
    /// - Returns: A `.bool`, `.cellRef`, or `.identifier` token.
    /// - Throws: ``FormulaParseError`` if a `$`-prefixed reference is invalid.
    private static func scanWordOrCellRef(
        chars: [Character],
        pos: inout Int,
        formula: String
    ) throws -> FormulaToken {
        let start = pos

        // Collect the full sequence: $, letters, digits, and embedded $ between letters and digits
        var raw: [Character] = []
        while pos < chars.count {
            let ch = chars[pos]
            // Underscores and dots belong inside the word. A defined name may
            // contain both — `days_per_week`, `report.week` — and a function name
            // may too: `COVARIANCE.P` is one name, not `COVARIANCE` followed by
            // something, and `_xlfn.COVARIANCE.P` is that with a marker on front.
            // A number cannot reach here, because this scanner is only entered on
            // `$`, a letter or an underscore, so a dot is never a decimal point.
            if ch == "$" || ch.isLetter || ch.isNumber || ch == "_" || ch == "." {
                raw.append(ch)
                pos += 1
            } else {
                break
            }
        }

        let word = String(raw)
        let upper = word.uppercased()

        // Check for boolean literals first
        if upper == "TRUE" {
            return .bool(true)
        }
        if upper == "FALSE" {
            return .bool(false)
        }

        // Try to parse as cell reference
        let hasDollar = raw.contains("$")
        if let cellRef = parseCellReference(raw: raw) {
            return .cellRef(cellRef)
        }

        // `$E` and `$2` are not failed cell references. They are how a formula
        // names a whole column or a whole row — `SUMIFS(Sheet2!$E:$E, ...)` — and
        // the corpus writes them about 135,000 times.
        if hasDollar, let partial = parsePartialReference(raw: raw) {
            return partial
        }

        // If $ was present, it must be a cell ref attempt that failed
        if hasDollar {
            throw FormulaParseError(
                kind: .unexpectedToken(expected: "valid cell reference", found: word),
                offset: start,
                formula: formula
            )
        }

        return .identifier(word)
    }

    /// Parses `$E` as a column and `$2` as a row.
    ///
    /// Excel's limits decide validity: 16,384 columns and 1,048,576 rows. A word
    /// mixing letters and digits is a cell reference and is not handled here.
    ///
    /// - Parameter raw: The raw characters, `$` markers included.
    /// - Returns: `.columnRef`, `.rowRef`, or `nil` if it is neither.
    private static func parsePartialReference(raw: [Character]) -> FormulaToken? {
        let bare = raw.filter { $0 != "$" }
        guard !bare.isEmpty else { return nil }

        if bare.allSatisfy(\.isLetter) {
            var column = 0
            for ch in bare {
                guard let value = ch.uppercased().unicodeScalars.first?.value else { return nil }
                column = column * 26 + Int(value - 64)
            }
            guard column >= 1 && column <= 16_384 else { return nil }
            return .columnRef(column)
        }

        if bare.allSatisfy(\.isNumber) {
            guard let row = Int(String(bare)), row >= 1 && row <= 1_048_576 else { return nil }
            return .rowRef(row)
        }

        return nil
    }

    // MARK: - Cell reference parsing

    /// Attempts to parse a character sequence as a cell reference.
    ///
    /// Extracts column letters and row digits, accounting for `$` markers,
    /// then validates against Excel's maximum bounds (column 1-16384, row 1-1048576).
    ///
    /// - Parameter raw: The raw characters to parse.
    /// - Returns: A ``CellRef`` if valid, or `nil` if the sequence does not
    ///   match a valid cell reference pattern.
    private static func parseCellReference(raw: [Character]) -> CellRef? {
        var idx = 0
        var absCol = false
        var absRow = false
        var colLetters: [Character] = []
        var rowDigits: [Character] = []

        // Optional leading $ for absolute column
        if idx < raw.count && raw[idx] == "$" {
            absCol = true
            idx += 1
        }

        // Collect column letters
        while idx < raw.count && raw[idx].isLetter {
            colLetters.append(raw[idx])
            idx += 1
        }

        // Must have at least one column letter
        if colLetters.isEmpty {
            return nil
        }

        // Optional $ for absolute row
        if idx < raw.count && raw[idx] == "$" {
            absRow = true
            idx += 1
        }

        // Collect row digits
        while idx < raw.count && raw[idx].isNumber {
            rowDigits.append(raw[idx])
            idx += 1
        }

        // Must have consumed everything, and must have row digits
        guard idx == raw.count, !rowDigits.isEmpty else {
            return nil
        }

        // Compute column number (base-26: A=1, Z=26, AA=27)
        var col = 0
        for letter in colLetters {
            guard let scalar = letter.uppercased().unicodeScalars.first else { return nil }
            let val = Int(scalar.value) - 64
            col = col * 26 + val
        }

        // Parse row number
        guard let row = Int(String(rowDigits)) else { return nil }

        // Validate bounds
        guard col >= 1, col <= maxColumn, row >= 1, row <= maxRow else {
            return nil
        }

        return CellRef(column: col, row: row, absoluteColumn: absCol, absoluteRow: absRow)
    }
}
