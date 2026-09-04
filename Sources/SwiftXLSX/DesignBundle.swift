import SwiftExcelCore
/// Configurable default styling applied to new workbooks.
public struct DesignBundle: Equatable, Sendable {
    /// The font for body/data cells.
    public var bodyFont: Font
    /// The font for title rows.
    public var titleFont: Font
    /// The font for label cells.
    public var labelFont: Font
    /// The number of gutter columns on the left (e.g. 2 for columns A-B).
    public var gutterColumnCount: Int
    /// The width of gutter columns.
    public var gutterColumnWidth: Double
    /// The default width for data columns.
    public var dataColumnWidth: Double
    /// The height of the title row.
    public var titleRowHeight: Double
    /// The default sheet names for new workbooks.
    public var defaultSheetNames: [String]

    /// Creates a design bundle with the given properties.
    public init(
        bodyFont: Font = Font(name: "SF Mono", size: 11),
        titleFont: Font = Font(name: "SF Pro Display", size: 18, bold: true),
        labelFont: Font = Font(name: "SF Mono", size: 11, bold: true),
        gutterColumnCount: Int = 2,
        gutterColumnWidth: Double = 2.85,
        dataColumnWidth: Double = 14.28,
        titleRowHeight: Double = 40.0,
        defaultSheetNames: [String] = ["Definitions", "Sheet 1", "Sheet 2",
                                        "Sheet 3", "Sheet 4", "Sheet 5",
                                        "Sheet 6", "Sheet 7", "Sheet 8"]
    ) {
        self.bodyFont = bodyFont
        self.titleFont = titleFont
        self.labelFont = labelFont
        self.gutterColumnCount = gutterColumnCount
        self.gutterColumnWidth = gutterColumnWidth
        self.dataColumnWidth = dataColumnWidth
        self.titleRowHeight = titleRowHeight
        self.defaultSheetNames = defaultSheetNames
    }

    /// The opinionated defaults derived from the user's Book.xltx template.
    public static let `default` = DesignBundle()
}
