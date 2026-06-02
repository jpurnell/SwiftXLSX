/// An Excel cell fill (background) specification.
public struct Fill: Equatable, Hashable, Sendable {
    /// The fill pattern type.
    public let patternType: PatternType
    /// The foreground color as an ARGB hex string, or nil for no color.
    public let foregroundColor: String?

    /// Creates a fill with the given pattern and color.
    public init(patternType: PatternType = .none, foregroundColor: String? = nil) {
        self.patternType = patternType
        self.foregroundColor = foregroundColor
    }

    /// Creates a solid fill with the given ARGB hex color.
    public static func solid(_ color: String) -> Fill {
        Fill(patternType: .solid, foregroundColor: color)
    }

    /// Fill pattern types supported by Excel.
    public enum PatternType: String, Sendable {
        case none, solid, gray125
    }
}
