/// An Excel cell font specification.
public struct Font: Equatable, Hashable, Sendable {
    /// The font family name, e.g. "Calibri" or "SF Mono".
    public var name: String
    /// The font size in points.
    public var size: Double
    /// The font color as an ARGB hex string, or nil for the theme default.
    public var color: String?
    /// Whether the font is bold.
    public var bold: Bool
    /// Whether the font is italic.
    public var italic: Bool
    /// Whether the font is underlined.
    public var underline: Bool

    /// Creates a font with the given properties.
    public init(name: String = "Calibri", size: Double = 11,
                color: String? = nil, bold: Bool = false,
                italic: Bool = false, underline: Bool = false) {
        self.name = name
        self.size = size
        self.color = color
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}
