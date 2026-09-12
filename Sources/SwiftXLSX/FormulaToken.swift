import SwiftExcelCore
/// A token produced by the formula lexer.
///
/// Represents a single lexical unit from an Excel formula string.
/// The lexer classifies cell references, error literals, and booleans
/// at tokenization time. Function names vs named ranges are disambiguated
/// by the parser based on context (lookahead for `(`).
public enum FormulaToken: Equatable, Sendable {

    // MARK: - Literals

    /// A numeric literal (e.g., `42`, `3.14`, `0.065`).
    case number(Double)

    /// A string literal with quotes stripped (e.g., `"hello"` becomes `hello`).
    case string(String)

    /// A boolean literal (`TRUE` or `FALSE`).
    case bool(Bool)

    /// An Excel error literal (e.g., `#VALUE!`, `#DIV/0!`).
    case error(ExcelError)

    // MARK: - References

    /// A cell reference (e.g., `A1`, `$A$1`, `AA100`).
    case cellRef(CellRef)

    /// A quoted sheet name with quotes stripped (e.g., `'My Sheet'` becomes `My Sheet`).
    /// A reference naming a column and no row — the `$E` of `$E:$E`.
    ///
    /// Only ever produced with a `$`, because a bare `E` is indistinguishable
    /// from a defined name until the parser sees what follows it.
    case columnRef(Int)

    /// A reference naming a row and no column — the `$2` of `$2:$3`.
    case rowRef(Int)

    case quotedName(String)

    // MARK: - Identifiers

    /// An identifier: function name, named range, or unquoted sheet name.
    ///
    /// The parser disambiguates based on context:
    /// - Followed by `(` → function call
    /// - Followed by `!` → sheet reference
    /// - Otherwise → named range
    case identifier(String)

    // MARK: - Operators

    /// The `+` operator.
    case plus
    /// The `-` operator.
    case minus
    /// The `*` operator.
    case asterisk
    /// The `/` operator.
    case slash
    /// The `^` operator.
    case caret
    /// The `&` concatenation operator.
    case ampersand
    /// The `=` comparison operator.
    case equals
    /// The `<>` not-equal operator.
    case notEqual
    /// The `<` operator.
    case lessThan
    /// The `>` operator.
    case greaterThan
    /// The `<=` operator.
    case lessOrEqual
    /// The `>=` operator.
    case greaterOrEqual

    // MARK: - Punctuation

    /// A left parenthesis `(`.
    case leftParen
    /// A right parenthesis `)`.
    case rightParen
    /// A comma `,`.
    case comma
    /// A colon `:` (range separator).
    case colon
    /// An exclamation mark `!` (sheet reference separator).
    case exclamation

    // MARK: - Sentinel

    /// End of formula.
    case eof
}
