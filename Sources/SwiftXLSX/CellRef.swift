public struct CellRef: Equatable, Hashable, Sendable {
    public let column: Int
    public let row: Int
    public let absoluteColumn: Bool
    public let absoluteRow: Bool

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
                let val = Int(char.uppercased().unicodeScalars.first!.value) - 64
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

    public init(column: Int, row: Int, absoluteColumn: Bool = false, absoluteRow: Bool = false) {
        self.column = column
        self.row = row
        self.absoluteColumn = absoluteColumn
        self.absoluteRow = absoluteRow
    }

    public var reference: String {
        var result = ""
        if absoluteColumn { result += "$" }
        var c = column
        var colStr = ""
        while c > 0 {
            c -= 1
            colStr = String(UnicodeScalar(65 + c % 26)!) + colStr
            c /= 26
        }
        result += colStr
        if absoluteRow { result += "$" }
        result += "\(row)"
        return result
    }

    public func absolute() -> CellRef {
        CellRef(column: column, row: row, absoluteColumn: true, absoluteRow: true)
    }
}
