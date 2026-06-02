/// A cell formatting style combining number format, font, and fill.
public struct CellStyle: Sendable {
    /// The Excel number format ID.
    public let numberFormatId: Int
    /// Whether the cell text is bold.
    public let bold: Bool
    /// The fill color as an ARGB hex string, e.g. `FFFFFF00`.
    public let fillColor: String?

    /// Creates a cell style with the given formatting options.
    public init(numberFormatId: Int = 0, bold: Bool = false, fillColor: String? = nil) {
        self.numberFormatId = numberFormatId
        self.bold = bold
        self.fillColor = fillColor
    }

    /// Default general formatting.
    public static let general = CellStyle()
    /// Bold text for headers.
    public static let header = CellStyle(bold: true)
    /// Currency number format.
    public static let currency = CellStyle(numberFormatId: 4)
    /// Percentage number format.
    public static let percent = CellStyle(numberFormatId: 10)
    /// Date number format.
    public static let date = CellStyle(numberFormatId: 14)
    /// Integer number format.
    public static let integer = CellStyle(numberFormatId: 1)
    /// Yellow fill for input cells.
    public static let input = CellStyle(fillColor: "FFFFFF00")
}
