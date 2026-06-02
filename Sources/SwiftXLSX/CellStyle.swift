/// A cell formatting style composed of font, border, alignment, number format, and fill.
public struct CellStyle: Equatable, Hashable, Sendable {
    /// The font specification for this style.
    public var font: Font
    /// The border specification, or nil for no border.
    public var border: Border?
    /// The alignment specification, or nil for default alignment.
    public var alignment: Alignment?
    /// The number format for this style.
    public var numberFormat: NumberFormat
    /// The fill (background) specification, or nil for no fill.
    public var fill: Fill?

    /// Creates a cell style with the given formatting options.
    public init(font: Font = Font(), border: Border? = nil,
                alignment: Alignment? = nil,
                numberFormat: NumberFormat = .general,
                fill: Fill? = nil) {
        self.font = font
        self.border = border
        self.alignment = alignment
        self.numberFormat = numberFormat
        self.fill = fill
    }

    /// Returns a copy with the given font.
    public func with(font: Font) -> CellStyle {
        CellStyle(font: font, border: border, alignment: alignment,
                  numberFormat: numberFormat, fill: fill)
    }

    /// Returns a copy with the given border.
    public func with(border: Border?) -> CellStyle {
        CellStyle(font: font, border: border, alignment: alignment,
                  numberFormat: numberFormat, fill: fill)
    }

    /// Returns a copy with the given alignment.
    public func with(alignment: Alignment?) -> CellStyle {
        CellStyle(font: font, border: border, alignment: alignment,
                  numberFormat: numberFormat, fill: fill)
    }

    /// Returns a copy with the given number format.
    public func with(numberFormat: NumberFormat) -> CellStyle {
        CellStyle(font: font, border: border, alignment: alignment,
                  numberFormat: numberFormat, fill: fill)
    }

    /// Returns a copy with the given fill.
    public func with(fill: Fill?) -> CellStyle {
        CellStyle(font: font, border: border, alignment: alignment,
                  numberFormat: numberFormat, fill: fill)
    }

    /// Default general formatting.
    public static let general = CellStyle()
    /// Bold text for headers.
    public static let header = CellStyle(font: Font(bold: true))
    /// Currency number format.
    public static let currency = CellStyle(numberFormat: .currency)
    /// Percentage number format.
    public static let percent = CellStyle(numberFormat: .percent)
    /// Date number format.
    public static let date = CellStyle(numberFormat: .date)
    /// Integer number format.
    public static let integer = CellStyle(numberFormat: .integer)
    /// Yellow fill for input cells.
    public static let input = CellStyle(fill: .solid("FFFFFF00"))
    /// Title style with large bold font.
    public static let title = CellStyle(font: Font(size: 18, bold: true))
}
