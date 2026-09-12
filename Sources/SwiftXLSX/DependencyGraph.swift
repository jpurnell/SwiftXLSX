import SwiftExcelCore

/// The dependency graph, for callers who have a file.
///
/// The type itself lives in SwiftExcelCore, because a graph over cells is a fact
/// about a set of cells and holds whether or not they came from an `.xlsx`. What
/// belongs here is the part that does involve a file: turning a `Workbook` or a
/// `Worksheet` into the address set and provider the graph actually wants.
///
/// ```swift
/// let wb = Workbook()
/// let graph = DependencyGraph(workbook: wb)
/// for cell in graph.evaluationOrder {
///     // evaluate in dependency order
/// }
/// ```
///
/// No `typealias` is needed: `SwiftExcelCoreExports.swift` re-exports SwiftExcelCore,
/// so `import SwiftXLSX` still sees `DependencyGraph` by its plain name — the same
/// arrangement that already carries `CellValue` and `FormulaAST`.
public extension DependencyGraph {

    /// Builds the dependency graph from a workbook's formulas.
    ///
    /// Walks all cells in all sheets, extracts formula references from the AST,
    /// and builds adjacency lists. Then performs a topological sort using Kahn's
    /// algorithm to determine evaluation order and detect cycles.
    ///
    /// - Parameter workbook: The workbook whose formulas define the dependency graph.
    init(workbook: Workbook) {
        self.init(cells: DependencyGraph.addresses(of: workbook.sheets),
                  provider: WorkbookValueProvider(workbook: workbook,
                                                  currentSheet: workbook.sheets.first?.name ?? ""),
                  sheetScope: nil,
                  including: nil)
    }

    /// Builds the dependency graph over one sheet, optionally over part of it.
    ///
    /// ``init(workbook:)`` answers the question a spreadsheet *evaluator* asks: in
    /// what order must every cell be visited? For that, every cell belongs —
    /// labels included, and a referenced-but-empty cell too, because you still
    /// have to visit it to learn it is zero.
    ///
    /// A caller recovering a *model* from a sheet is asking something else: which
    /// quantities depend on which. There a title is not a node, and a reference to
    /// an empty cell is not an input. Filtering the whole-workbook graph
    /// afterwards does not answer it — by then the topological order and the cycle
    /// set have already been computed over the unfiltered set.
    ///
    /// So the scope is given before the graph is built. A reference to a cell the
    /// scope excludes — on another sheet, or failing the filter — is **dropped
    /// along with its edge**, rather than pulling a foreign or empty cell in.
    ///
    /// - Parameters:
    ///   - sheet: The sheet to build over.
    ///   - including: Whether a cell belongs in the graph, given its value.
    ///     Defaults to every cell the sheet holds.
    init(sheet: Worksheet, including: ((CellValue) -> Bool)? = nil) {
        self.init(cells: DependencyGraph.addresses(of: [sheet]),
                  provider: SheetValueProvider(sheet: sheet),
                  sheetScope: [sheet.name],
                  including: including)
    }

    /// Builds the dependency graph over a workbook, keeping only some cells.
    ///
    /// - Parameters:
    ///   - workbook: The workbook to build over.
    ///   - including: Whether a cell belongs in the graph, given its value.
    init(workbook: Workbook, including: @escaping (CellValue) -> Bool) {
        self.init(cells: DependencyGraph.addresses(of: workbook.sheets),
                  provider: WorkbookValueProvider(workbook: workbook,
                                                  currentSheet: workbook.sheets.first?.name ?? ""),
                  sheetScope: nil,
                  including: including)
    }

    /// Every address the given sheets hold.
    ///
    /// This is the enumeration a `CellValueProvider` cannot perform — it answers
    /// "what is at this address?" and cannot be asked "which addresses do you
    /// have?". A `Worksheet` can, because it holds the dictionary.
    ///
    /// - Parameter sheets: The sheets to enumerate.
    /// - Returns: Every populated address across them.
    private static func addresses(of sheets: [Worksheet]) -> [CellAddress] {
        sheets.flatMap { sheet in
            sheet.cells.keys.map { CellAddress(sheet: sheet.name, ref: $0) }
        }
    }
}

/// One worksheet, as a `CellValueProvider`.
///
/// `WorkbookValueProvider` needs a workbook; `init(sheet:including:)` has only a
/// sheet, which may not belong to one.
// Justification: reads a Worksheet and never mutates it, for one graph construction.
private struct SheetValueProvider: CellValueProvider, @unchecked Sendable {

    let sheet: Worksheet

    func value(at ref: CellRef) -> CellValue? {
        sheet.cells[ref.reference]?.0
    }

    func value(at ref: CellRef, inSheet: String) -> CellValue? {
        guard inSheet == sheet.name else { return nil }
        return value(at: ref)
    }

    func lastPopulatedCell() -> CellRef? { sheet.lastPopulatedCell }
    func lastPopulatedCell(inSheet: String) -> CellRef? {
        inSheet == sheet.name ? sheet.lastPopulatedCell : nil
    }
    func values(in range: CellRange) -> [CellValue] { [] }
    func values(in range: CellRange, inSheet: String) -> [CellValue] { [] }
}
