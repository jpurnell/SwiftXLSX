import SwiftExcelCore
/// An Excel cell alignment specification.
public struct Alignment: Equatable, Hashable, Sendable {
    /// The horizontal alignment within the cell.
    public var horizontal: Horizontal?
    /// The vertical alignment within the cell.
    public var vertical: Vertical?
    /// Whether text wraps within the cell.
    public var wrapText: Bool
    /// The indentation level (0 = no indent).
    public var indent: Int

    /// Creates an alignment with the given properties.
    public init(horizontal: Horizontal? = nil, vertical: Vertical? = nil,
                wrapText: Bool = false, indent: Int = 0) {
        self.horizontal = horizontal
        self.vertical = vertical
        self.wrapText = wrapText
        self.indent = indent
    }

    /// Horizontal alignment options.
    public enum Horizontal: String, Sendable {
        case left, center, right // LIVE: public API for consumers
    }

    /// Vertical alignment options.
    public enum Vertical: String, Sendable {
        case top, center, bottom // LIVE: public API for consumers
    }
}
