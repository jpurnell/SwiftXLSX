import Foundation

public final class Worksheet: @unchecked Sendable {
    // Justification: Worksheet is only mutated during construction, before save
    public let name: String
    private(set) var cells: [String: (CellValue, CellStyle)] = [:]
    private(set) var columnWidths: [Int: Double] = [:]

    init(name: String) {
        self.name = name
    }

    public func write(_ value: String, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.string(value), style)
    }

    public func write(_ value: Double, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.number(value), style)
    }

    public func write(_ value: Int, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.number(Double(value)), style)
    }

    public func writeFormula(_ formula: String, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.formula(formula), style)
    }

    public func cell(at ref: String) -> CellValue? {
        cells[ref]?.0
    }

    public func setColumnWidth(column: String, width: Double) {
        let ref = CellRef("\(column)1")
        columnWidths[ref.column] = width
    }
}
