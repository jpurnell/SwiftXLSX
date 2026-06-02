public struct CellRange: Equatable, Hashable, Sendable {
    public let start: CellRef
    public let end: CellRef

    public init(from: CellRef, to: CellRef) {
        self.start = from
        self.end = to
    }

    public init(from: String, to: String) {
        self.start = CellRef(from)
        self.end = CellRef(to)
    }

    public init(_ reference: String) {
        let parts = reference.split(separator: ":", maxSplits: 1)
        self.start = CellRef(String(parts[0]))
        self.end = parts.count > 1 ? CellRef(String(parts[1])) : CellRef(String(parts[0]))
    }

    public var reference: String {
        if start == end {
            return start.reference
        }
        return "\(start.reference):\(end.reference)"
    }

    public func absolute() -> CellRange {
        CellRange(from: start.absolute(), to: end.absolute())
    }

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

    public var rowCount: Int {
        end.row - start.row + 1
    }

    public var columnCount: Int {
        end.column - start.column + 1
    }
}
