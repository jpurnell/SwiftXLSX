import SwiftExcelCore
/// An Excel cell border specification with four independent edges.
public struct Border: Equatable, Hashable, Sendable {
    /// The top edge border.
    public var top: BorderEdge?
    /// The bottom edge border.
    public var bottom: BorderEdge?
    /// The left edge border.
    public var left: BorderEdge?
    /// The right edge border.
    public var right: BorderEdge?

    /// Creates a border with the given edges.
    public init(top: BorderEdge? = nil, bottom: BorderEdge? = nil,
                left: BorderEdge? = nil, right: BorderEdge? = nil) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    /// A border with thin black lines on all four edges.
    public static let thin = Border(
        top: BorderEdge(), bottom: BorderEdge(),
        left: BorderEdge(), right: BorderEdge()
    )

    /// A border with a thin black line on the bottom edge only.
    public static let bottom = Border(bottom: BorderEdge())

    /// A single border edge with a line style and color.
    public struct BorderEdge: Equatable, Hashable, Sendable {
        /// The line style for this edge.
        public let style: Style
        /// The edge color as an ARGB hex string.
        public let color: String

        /// Creates a border edge.
        public init(style: Style = .thin, color: String = "FF000000") {
            self.style = style
            self.color = color
        }

        /// Border line styles supported by Excel.
        public enum Style: String, Sendable {
            case thin, medium, thick, double, dashed, dotted // LIVE: public API for consumers
        }
    }
}
