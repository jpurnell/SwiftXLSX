import Foundation

/// A single worksheet within a workbook.
// Justification: Worksheet is only mutated during construction, before save
public final class Worksheet: @unchecked Sendable {
    /// The name of this worksheet.
    public let name: String
    private(set) var cells: [String: (CellValue, CellStyle)] = [:]

    /// The reference strings of all non-empty cells in this worksheet.
    public var cellReferences: [String] { Array(cells.keys) }
    private(set) var columnWidths: [Int: Double] = [:]
    private(set) var validations: [(range: CellRange, type: ValidationType)] = []
    private(set) var autoFilterRange: CellRange?
    private(set) var mergedCells: [CellRange] = []
    private(set) var rowHeights: [Int: Double] = [:]
    private(set) var frozenPaneRef: String?

    init(name: String) {
        self.name = name
    }

    // MARK: - Internal Mutation (Reader Support)

    /// Sets a cell value and style directly by reference string.
    ///
    /// Used by ``WorksheetParser`` when reading cells from an XLSX file.
    func setCell(_ ref: String, value: CellValue, style: CellStyle) {
        cells[ref] = (value, style)
    }

    /// Sets the width of a column by its 1-based index.
    ///
    /// Used by ``WorksheetParser`` when reading column widths from an XLSX file.
    func setColumnWidth(columnIndex: Int, width: Double) {
        columnWidths[columnIndex] = width
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

    /// Writes a formula string to the specified cell, parsing it into an AST.
    ///
    /// If the formula cannot be parsed, it is stored as a raw string fallback
    /// that will be written verbatim to the `.xlsx` file.
    ///
    /// - Parameters:
    ///   - formula: The Excel formula string (leading `=` is optional).
    ///   - ref: The cell reference (e.g., `"B4"`).
    ///   - style: The cell style to apply.
    public func writeFormula(_ formula: String, to ref: String, style: CellStyle = .general) {
        let cleaned = formula.hasPrefix("=") ? String(formula.dropFirst()) : formula
        if let ast = try? FormulaParser.parse(cleaned) { // silent: fallback to _RAW on parse failure
            cells[ref] = (.formula(ast, cached: nil), style)
        } else {
            cells[ref] = (.formula(.function("_RAW", [.text(cleaned)]), cached: nil), style)
        }
    }

    /// Writes a formula AST to the specified cell.
    public func write(_ formula: FormulaAST, to ref: String, style: CellStyle = .general) {
        cells[ref] = (.formula(formula, cached: nil), style)
    }

    /// Returns the formula AST at the given cell reference, if any.
    public func formulaAST(at ref: String) -> FormulaAST? {
        cells[ref]?.0.formulaAST
    }

    /// The style applied to a cell, or `nil` when the cell holds nothing.
    ///
    /// A cell's number format is not decoration. It is often the only statement a
    /// workbook makes about what a number *is*: `0.4` formatted `0%` is a margin,
    /// the same `0.4` formatted `"$"#,##0` is money, and the label beside it may
    /// say neither. The reader has resolved this for every cell since it was
    /// written — Excel's built-in formats included, so `numFmtId="9"` arrives as
    /// `0%` — and it had nowhere to go.
    ///
    /// - Parameter ref: The cell reference, such as `B4`.
    /// - Returns: The cell's style, or `nil` if the cell is empty.
    public func style(at ref: String) -> CellStyle? {
        cells[ref]?.1
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

    /// Adds a data validation rule to the given cell range.
    public func addValidation(_ range: CellRange, type: ValidationType) {
        validations.append((range: range, type: type))
    }

    /// Enables auto-filter dropdown headers for the given range.
    public func setAutoFilter(_ range: CellRange) {
        autoFilterRange = range
    }

    /// Marks the given range as a merged cell region.
    public func mergeCells(_ range: CellRange) {
        mergedCells.append(range)
    }

    /// Sets the height of the specified row.
    public func setRowHeight(row: Int, height: Double) {
        rowHeights[row] = height
    }

    /// Freezes rows and columns above and to the left of the given cell reference.
    public func freezePanes(at ref: String) {
        frozenPaneRef = ref
    }
}
