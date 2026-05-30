public struct CellRef: Sendable {
    public let column: Int
    public let row: Int
    public let reference: String

    public init(_ reference: String) {
        self.reference = reference
        var col = 0
        var rowStr = ""
        for char in reference {
            if char.isLetter {
                let val = Int(char.asciiValue ?? 65) - 64
                col = col * 26 + val
            } else {
                rowStr.append(char)
            }
        }
        self.column = col
        self.row = Int(rowStr) ?? 1
    }

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
        var result = ""
        var c = column
        while c > 0 {
            c -= 1
            result = String(UnicodeScalar(65 + c % 26)!) + result
            c /= 26
        }
        self.reference = "\(result)\(row)"
    }
}
