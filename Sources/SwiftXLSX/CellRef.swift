/// A reference to a single Excel cell, e.g. `A1` or `$B$5`.
public struct CellRef: Equatable, Hashable, Sendable {
    /// 1-based column index (A=1, B=2, ..., Z=26, AA=27).
    public let column: Int
    /// 1-based row number.
    public let row: Int
    /// Whether the column is absolute (`$A`).
    public let absoluteColumn: Bool
    /// Whether the row is absolute (`A$1`).
    public let absoluteRow: Bool

    /// Parses a cell reference string such as `A1`, `$B$5`, or `AA100`.
    public init(_ reference: String) {
        var absCol = false
        var absRow = false
        var col = 0
        var rowStr = ""
        var expectingColumn = true

        for char in reference {
            if char == "$" {
                if expectingColumn && col == 0 {
                    absCol = true
                } else {
                    absRow = true
                }
            } else if char.isLetter && expectingColumn {
                guard let scalar = char.uppercased().unicodeScalars.first else { continue }
            let val = Int(scalar.value) - 64
                col = col * 26 + val
            } else {
                expectingColumn = false
                rowStr.append(char)
            }
        }

        self.column = col
        self.row = Int(rowStr) ?? 1
        self.absoluteColumn = absCol
        self.absoluteRow = absRow
    }

    /// Creates a cell reference from numeric column and row.
    public init(column: Int, row: Int, absoluteColumn: Bool = false, absoluteRow: Bool = false) {
        self.column = column
        self.row = row
        self.absoluteColumn = absoluteColumn
        self.absoluteRow = absoluteRow
    }

    /// The string representation of this cell reference, including `$` markers.
    public var reference: String {
        var result = ""
        if absoluteColumn { result += "$" }
        var c = column
        var colStr = ""
        while c > 0 {
            c -= 1
            guard let scalar = UnicodeScalar(65 + c % 26) else { break }
            colStr = String(scalar) + colStr
            c /= 26
        }
        result += colStr
        if absoluteRow { result += "$" }
        result += "\(row)"
        return result
    }

    /// Returns a copy with both column and row marked absolute.
    public func absolute() -> CellRef {
        CellRef(column: column, row: row, absoluteColumn: true, absoluteRow: true)
    }
}
