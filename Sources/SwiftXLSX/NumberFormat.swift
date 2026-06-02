/// An Excel number format specification.
public struct NumberFormat: Equatable, Hashable, Sendable {
    /// The Excel format string, e.g. "#,##0.00" or "mm/dd/yyyy".
    public let formatString: String

    /// Creates a number format with the given format string.
    public init(formatString: String) {
        self.formatString = formatString
    }

    /// General formatting (no specific number format).
    public static let general = NumberFormat(formatString: "General")
    /// Currency format: $#,##0.00
    public static let currency = NumberFormat(formatString: "$#,##0.00")
    /// Percentage format: 0.00%
    public static let percent = NumberFormat(formatString: "0.00%")
    /// Date format: mm/dd/yyyy
    public static let date = NumberFormat(formatString: "mm/dd/yyyy")
    /// Integer format with thousands separator: #,##0
    public static let integer = NumberFormat(formatString: "#,##0")
    /// Accounting format with aligned currency symbol.
    public static let accounting = NumberFormat(formatString: "_($* #,##0.00_)")
}
