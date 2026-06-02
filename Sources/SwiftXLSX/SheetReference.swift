/// A cross-sheet cell or range reference, e.g. `'Sheet1'!A1:B10`.
public struct SheetReference: Equatable, Hashable, Sendable {
    /// The name of the referenced worksheet.
    public let sheetName: String
    /// The cell range within the referenced sheet.
    public let range: CellRange

    /// Creates a sheet reference to a cell range.
    public init(sheet: String, range: CellRange) {
        self.sheetName = sheet
        self.range = range
    }

    /// Creates a sheet reference to a single cell.
    public init(sheet: String, cell: CellRef) {
        self.sheetName = sheet
        self.range = CellRange(from: cell, to: cell)
    }

    /// The formatted reference string with quoted sheet name.
    public var reference: String {
        let escaped = sheetName.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'!\(range.reference)"
    }
}
