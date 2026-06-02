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
        let parts = reference.split(separator: ":")
        self.start = CellRef(String(parts[0]))
        self.end = parts.count > 1 ? CellRef(String(parts[1])) : CellRef(String(parts[0]))
    }

    public var reference: String {
        "\(start.reference):\(end.reference)"
    }

    public func absolute() -> CellRange {
        CellRange(from: start.absolute(), to: end.absolute())
    }

    public var cells: [CellRef] {
        // Stub — agent implements full iteration
        []
    }

    public var rowCount: Int {
        end.row - start.row + 1
    }

    public var columnCount: Int {
        end.column - start.column + 1
    }
}
