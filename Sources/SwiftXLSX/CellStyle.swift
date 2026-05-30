public struct CellStyle: Sendable {
    public let numberFormatId: Int
    public let bold: Bool
    public let fillColor: String?

    public init(numberFormatId: Int = 0, bold: Bool = false, fillColor: String? = nil) {
        self.numberFormatId = numberFormatId
        self.bold = bold
        self.fillColor = fillColor
    }

    public static let general = CellStyle()
    public static let header = CellStyle(bold: true)
    public static let currency = CellStyle(numberFormatId: 4)
    public static let percent = CellStyle(numberFormatId: 10)
    public static let date = CellStyle(numberFormatId: 14)
    public static let integer = CellStyle(numberFormatId: 1)
    public static let input = CellStyle(fillColor: "FFFFFF00")
}
