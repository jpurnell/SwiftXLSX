/// An error encountered while parsing an Excel formula string.
///
/// Contains the error kind, the character offset where the error occurred,
/// and the original formula string for diagnostic context.
///
/// ```swift
/// do {
///     let ast = try FormulaParser.parse("SUM(A1:B5")
/// } catch let error as FormulaParseError {
///     print(error.kind)    // .unexpectedEnd(expected: ")")
///     print(error.offset)  // 9
///     print(error.formula) // "SUM(A1:B5"
/// }
/// ```
public struct FormulaParseError: Error, Equatable, Sendable {

    /// The kind of parse error.
    public let kind: Kind

    /// The character offset in the original formula where the error occurred.
    public let offset: Int

    /// The original formula string.
    public let formula: String

    /// Creates a new parse error.
    ///
    /// - Parameters:
    ///   - kind: The error classification.
    ///   - offset: The character position of the error.
    ///   - formula: The original formula string.
    public init(kind: Kind, offset: Int, formula: String) {
        self.kind = kind
        self.offset = offset
        self.formula = formula
    }

    /// The classification of a formula parse error.
    public enum Kind: Equatable, Sendable {
        /// An unexpected token was encountered.
        case unexpectedToken(expected: String, found: String) // LIVE: public API for consumers

        /// The formula ended before a complete expression was parsed.
        case unexpectedEnd(expected: String) // LIVE: public API for consumers

        /// An unsupported construct was encountered.
        case unsupported(String) // LIVE: public API for consumers

        /// The formula string was empty or contained only whitespace.
        case emptyFormula // LIVE: public API for consumers
    }
}
