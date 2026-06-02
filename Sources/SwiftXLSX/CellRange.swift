/// A rectangular range of cells, e.g. `A1:B10`.
public struct CellRange: Equatable, Hashable, Sendable {
    /// The top-left cell of the range.
    public let start: CellRef
    /// The bottom-right cell of the range.
    public let end: CellRef

    /// Creates a range from two cell references.
    public init(from: CellRef, to: CellRef) {
        self.start = from
        self.end = to
    }

    /// Creates a range from two cell reference strings.
    public init(from: String, to: String) {
        self.start = CellRef(from)
        self.end = CellRef(to)
    }

    /// Parses a range string like `A1:B10` or a single cell like `A1`.
    public init(_ reference: String) {
        let parts = reference.split(separator: ":", maxSplits: 1)
        self.start = CellRef(String(parts[0]))
        self.end = parts.count > 1 ? CellRef(String(parts[1])) : CellRef(String(parts[0]))
    }

    /// The string representation, e.g. `A1:B10` or `A1` for single-cell ranges.
    public var reference: String {
        if start == end {
            return start.reference
        }
        return "\(start.reference):\(end.reference)"
    }

    /// Returns a copy with all cell references marked absolute.
    public func absolute() -> CellRange {
        CellRange(from: start.absolute(), to: end.absolute())
    }

    /// All cells in the range, iterated row by row.
    public var cells: [CellRef] {
        var result: [CellRef] = []
        result.reserveCapacity(rowCount * columnCount)
        for row in start.row...end.row {
            for col in start.column...end.column {
                result.append(CellRef(column: col, row: row))
            }
        }
        return result
    }

    /// The number of rows in the range.
    public var rowCount: Int {
        end.row - start.row + 1
    }

    /// The number of columns in the range.
    public var columnCount: Int {
        end.column - start.column + 1
    }
}
