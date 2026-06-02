import Foundation

/// A single worksheet within a workbook.
// Justification: Worksheet is only mutated during construction, before save
public final class Worksheet: @unchecked Sendable {
    /// The name of this worksheet.
    public let name: String
    private(set) var cells: [String: (CellValue, CellStyle)] = [:]
    private(set) var columnWidths: [Int: Double] = [:]

    init(name: String) {
        self.name = name
    }

    /// Writes a text value to the specified cell.
    public func write(_ value: String, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.text(value), style)
    }

    /// Writes a numeric value to the specified cell.
    public func write(_ value: Double, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.number(value), style)
    }

    /// Writes an integer value to the specified cell.
    public func write(_ value: Int, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.number(Double(value)), style)
    }

    /// Writes a raw formula string to the specified cell.
    public func writeFormula(_ formula: String, to ref: String, style: CellStyle = .general) {
        let cleaned = formula.hasPrefix("=") ? String(formula.dropFirst()) : formula
        cells[ref] = (.formula(.function("_RAW", [.text(cleaned)]), cached: nil), style)
    }

    /// Writes a formula AST to the specified cell.
    public func write(_ formula: FormulaAST, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.formula(formula, cached: nil), style)
    }

    /// Returns the formula AST at the given cell reference, if any.
    public func formulaAST(at ref: String) -> FormulaAST? {
        cells[ref]?.0.formulaAST
    }

    /// Returns the cell value at the given reference, if any.
    public func cell(at ref: String) -> CellValue? {
        cells[ref]?.0
    }

    /// Sets the width of the specified column.
    public func setColumnWidth(column: String, width: Double) {
        let ref = CellRef("\(column)1")
        columnWidths[ref.column] = width
    }
}
