import Foundation
import SwiftExcelCore

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

    /// The array formulas on this sheet, each anchored at the top-left cell of the
    /// span it fills.
    ///
    /// Sheet-level rather than part of a cell's value, alongside merged cells and
    /// the auto-filter, because that is what it is: a statement about a rectangle.
    /// Keeping it out of the anchor's `CellValue` leaves that formula's AST exactly
    /// what the author wrote, which is what every reader downstream wants to see.
    private(set) var arrayFormulas: [(anchor: CellRef, span: CellRange)] = []
    private(set) var rowHeights: [Int: Double] = [:]
    private(set) var frozenPaneRef: String?

    /// The far corner of everything this sheet holds, or `nil` when it holds
    /// nothing.
    ///
    /// The bounding box's bottom-right, which is not necessarily a populated cell
    /// itself: its column may come from one cell and its row from another. That is
    /// exactly what a clip wants — the point past which nothing can be.
    ///
    /// Maintained on write rather than scanned on read. A sheet can hold hundreds
    /// of thousands of cells and this is asked once per range read during
    /// evaluation, so scanning would make whole-column references expensive in a
    /// different way than the one it exists to fix.
    public private(set) var lastPopulatedCell: CellRef?

    init(name: String) {
        self.name = name
    }

    /// Writes one cell and keeps ``lastPopulatedCell`` true.
    ///
    /// Every write goes through here. The bound is only as good as the guarantee
    /// that nothing sets `cells` behind its back.
    ///
    /// - Parameters:
    ///   - ref: The cell reference, in A1 notation.
    ///   - entry: The value and style to store.
    private func store(_ ref: String, _ entry: (CellValue, CellStyle)) {
        cells[ref] = entry
        let cell = CellRef(ref)
        lastPopulatedCell = CellRef(
            column: Swift.max(lastPopulatedCell?.column ?? 0, cell.column),
            row: Swift.max(lastPopulatedCell?.row ?? 0, cell.row))
    }

    // MARK: - Internal Mutation (Reader Support)

    /// Sets a cell value and style directly by reference string.
    ///
    /// Used by ``WorksheetParser`` when reading cells from an XLSX file.
    func setCell(_ ref: String, value: CellValue, style: CellStyle) {
        store(ref, (value, style))
    }

    /// Records an array formula's span, as read from a file.
    ///
    /// - Parameters:
    ///   - anchor: The top-left cell, which carries the formula.
    ///   - span: The rectangle the formula fills.
    func addArrayFormula(anchor: CellRef, span: CellRange) {
        arrayFormulas.append((anchor: anchor, span: span))
    }

    /// Sets the width of a column by its 1-based index.
    ///
    /// Used by ``WorksheetParser`` when reading column widths from an XLSX file.
    func setColumnWidth(columnIndex: Int, width: Double) {
        columnWidths[columnIndex] = width
    }

    /// Writes a text value to the specified cell.
    public func write(_ value: String, to ref: String, style: CellStyle = .general) {
        store(ref, (.text(value), style))
    }

    /// Writes a numeric value to the specified cell.
    public func write(_ value: Double, to ref: String, style: CellStyle = .general) {
        store(ref, (.number(value), style))
    }

    /// Writes an integer value to the specified cell.
    public func write(_ value: Int, to ref: String, style: CellStyle = .general) {
        store(ref, (.number(Double(value)), style))
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
            store(ref, (.formula(ast, cached: nil), style))
        } else {
            store(ref, (.formula(.function("_RAW", [.text(cleaned)]), cached: nil), style))
        }
    }

    /// Writes a formula together with the value Excel last computed for it.
    ///
    /// A formula cell in a real workbook carries both — the rule in `<f>` and the
    /// last result in `<v>` — and until now the writer could only say the first.
    /// A `Workbook` built in code therefore could not be made to look like one
    /// read from disk, which is exactly what a test of the reader's own shapes
    /// needs: a data table's body is cached numbers under a single marker, and a
    /// cached value is sometimes the only evidence of what a formula produced.
    ///
    /// - Parameters:
    ///   - formula: The formula.
    ///   - ref: The cell reference, such as `B4`.
    ///   - cached: The value the formula last evaluated to.
    ///   - style: The cell style to apply.
    public func write(
        _ formula: FormulaAST, to ref: String, cached: CellValue, style: CellStyle = .general
    ) {
        store(ref, (.formula(formula, cached: cached), style))
    }

    /// Writes a formula AST to the specified cell.
    ///
    /// - Parameters:
    ///   - formula: The formula.
    ///   - ref: The cell reference, such as `B4`.
    ///   - style: The cell style to apply.
    public func write(_ formula: FormulaAST, to ref: String, style: CellStyle = .general) {
        store(ref, (.formula(formula, cached: nil), style))
    }

    /// Writes an array formula over a range of cells.
    ///
    /// One formula fills the whole rectangle. The top-left cell carries the text,
    /// and every other cell in the span is marked as computed by it — which is how
    /// Excel stores this and, more importantly, what is true: the formula evaluates
    /// once and its result fills the span.
    ///
    /// ```swift
    /// let workbook = Workbook()
    /// let sheet = workbook.addSheet(name: "Sheet1")
    /// sheet.writeArrayFormula("TRANSPOSE(B1:D1)", over: CellRange(from: "A1", to: "A3"))
    /// ```
    ///
    /// - Parameters:
    ///   - formula: The formula text, without a leading `=`.
    ///   - range: The rectangle it fills. Its top-left cell becomes the anchor.
    ///   - style: The style for every cell in the span.
    public func writeArrayFormula(
        _ formula: String, over range: CellRange, style: CellStyle = .general
    ) {
        let anchor = range.start
        writeFormula(formula, to: anchor.reference, style: style)
        arrayFormulas.append((anchor: anchor, span: range))

        for row in range.start.row...range.end.row {
            for column in range.start.column...range.end.column {
                let cell = CellRef(column: column, row: row)
                guard cell != anchor else { continue }
                store(cell.reference, (
                    .formula(
                        .function("_ARRAY", [.cellRef(anchor), .text(range.reference)]),
                        cached: nil),
                    style))
            }
        }
    }

    /// Writes an evaluated result across a span.
    ///
    /// One formula fills a rectangle, and until something evaluates it those cells
    /// have no values. This writes them: each cell of `range` takes its element of
    /// `matrix`, reconciled by
    /// `CellMatrix.spilled(toRows:columns:)` — a vector broadcasts,
    /// unreachable cells become `#N/A`, and anything that does not fit is dropped.
    ///
    /// A cell that already holds a formula keeps it and gains a cached value, which
    /// is how Excel stores a calculated array formula. A cell that holds no formula
    /// simply receives the value, so the same call also serves a caller who wants a
    /// block of numbers written and nothing more.
    ///
    /// This package does not evaluate anything, so the result is supplied rather
    /// than computed — `SwiftExcelFunctions.FormulaEvaluator.spill(_:over:…)`
    /// produces one.
    ///
    /// ```swift
    /// let workbook = Workbook()
    /// let sheet = workbook.addSheet(name: "Sheet1")
    /// sheet.writeArrayFormula("TRANSPOSE(A1:A3)", over: CellRange(from: "C1", to: "E1"))
    /// sheet.spill(CellMatrix(row: [.number(10), .number(20), .number(30)]),
    ///             over: CellRange(from: "C1", to: "E1"))
    /// ```
    ///
    /// - Parameters:
    ///   - matrix: The evaluated result.
    ///   - range: The span it fills.
    public func spill(_ matrix: CellMatrix, over range: CellRange) {
        let filled = matrix.spilled(toRows: range.rowCount, columns: range.columnCount)
        for row in 0..<filled.rows {
            for column in 0..<filled.columns {
                let cell = CellRef(column: range.start.column + column,
                                   row: range.start.row + row)
                let value = filled[row, column]
                let existing = cells[cell.reference]
                let style = existing?.1 ?? .general
                if case .formula(let ast, _)? = existing?.0 {
                    store(cell.reference, (.formula(ast, cached: value), style))
                } else {
                    store(cell.reference, (value, style))
                }
            }
        }
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
