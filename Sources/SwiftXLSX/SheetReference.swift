public struct SheetReference: Equatable, Hashable, Sendable {
    public let sheetName: String
    public let range: CellRange

    public init(sheet: String, range: CellRange) {
        self.sheetName = sheet
        self.range = range
    }

    public init(sheet: String, cell: CellRef) {
        self.sheetName = sheet
        self.range = CellRange(from: cell, to: cell)
    }

    public var reference: String {
        let escaped = sheetName.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'!\(range.reference)"
    }
}
