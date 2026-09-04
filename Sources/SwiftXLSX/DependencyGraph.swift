import SwiftExcelCore
/// A directed acyclic graph of cell dependencies built from formula ASTs.
///
/// Use `DependencyGraph` to determine the correct evaluation order for cells
/// in a workbook, detect circular references, and query dependency relationships.
///
/// ```swift
/// let wb = Workbook()
/// let graph = DependencyGraph(workbook: wb)
/// for cell in graph.evaluationOrder {
///     // evaluate in dependency order
/// }
/// ```
public struct DependencyGraph: Sendable {

    /// Errors during graph construction.
    public enum GraphError: Error, Equatable, Sendable {
        /// A circular reference was detected involving the given cells.
        case circularReference([CellAddress]) // LIVE: public API for consumers
    }

    // MARK: - Internal Storage

    /// Maps each cell to the set of cells it directly depends on (precedents).
    private let precedentMap: [CellAddress: [CellAddress]]

    /// Maps each cell to the set of cells that directly depend on it (dependents).
    private let dependentMap: [CellAddress: [CellAddress]]

    /// All cells known to the graph, in no particular order.
    /// Every cell in the graph.
    ///
    /// Worth having separately from ``evaluationOrder``, which is empty when the
    /// graph has a cycle — so with a cycle present there would otherwise be no way
    /// to enumerate membership at all. That matters most for a scoped graph, where
    /// knowing what the scope kept is the first thing a caller asks.
    public let allCells: Set<CellAddress>

    /// Cells in topological order, computed during init. Empty if cycles exist.
    private let sortedCells: [CellAddress]

    /// Detected cycles, if any.
    private let detectedCycles: [[CellAddress]]

    // MARK: - Init

    /// Builds the dependency graph from a workbook's formulas.
    ///
    /// Walks all cells in all sheets, extracts formula references from the AST,
    /// and builds adjacency lists. Then performs a topological sort using Kahn's
    /// algorithm to determine evaluation order and detect cycles.
    ///
    /// - Parameter workbook: The workbook whose formulas define the dependency graph.
    public init(workbook: Workbook) {
        self.init(sheets: workbook.sheets, sheetScope: nil, including: nil)
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
    public init(sheet: Worksheet, including: ((CellValue) -> Bool)? = nil) {
        self.init(sheets: [sheet], sheetScope: [sheet.name], including: including)
    }

    /// Builds the dependency graph over a workbook, keeping only some cells.
    ///
    /// - Parameters:
    ///   - workbook: The workbook to build over.
    ///   - including: Whether a cell belongs in the graph, given its value.
    public init(workbook: Workbook, including: @escaping (CellValue) -> Bool) {
        self.init(sheets: workbook.sheets, sheetScope: nil, including: including)
    }

    /// The one builder. Everything above narrows what it is given.
    ///
    /// - Parameters:
    ///   - sheets: The sheets to walk.
    ///   - sheetScope: The sheet names a reference may point at, or `nil` to allow
    ///     any. `nil` for the whole-workbook initializers, which must keep
    ///     registering referenced addresses exactly as they always have.
    ///   - including: The filter, or `nil` to keep every cell — which also keeps
    ///     referenced cells that hold nothing, preserving ``init(workbook:)``.
    private init(
        sheets: [Worksheet],
        sheetScope: Set<String>?,
        including: ((CellValue) -> Bool)?
    ) {
        var precedents: [CellAddress: [CellAddress]] = [:]
        var dependents: [CellAddress: [CellAddress]] = [:]
        var cells: Set<CellAddress> = []

        // Which addresses are in scope at all. Built first, because an edge can
        // only be kept once both ends are known to belong.
        var inScope: Set<CellAddress> = []
        for sheet in sheets {
            for (refString, (value, _)) in sheet.cells {
                guard including?(value) ?? true else { continue }
                inScope.insert(CellAddress(sheet: sheet.name, ref: refString))
            }
        }

        for sheet in sheets {
            for (refString, (value, _)) in sheet.cells {
                let cellAddr = CellAddress(sheet: sheet.name, ref: refString)
                guard inScope.contains(cellAddr) else { continue }
                cells.insert(cellAddr)

                guard case .formula(let ast, _) = value else { continue }
                let refs = DependencyGraph.extractReferences(from: ast, inSheet: sheet.name)

                // Deduplicate while preserving order.
                var seen = Set<CellAddress>()
                var uniqueRefs: [CellAddress] = []
                for ref in refs where seen.insert(ref).inserted {
                    // A reference off the scoped sheets is out of scope whether or
                    // not a content filter was given: the caller asked for a graph
                    // over this sheet, and another sheet's cell is not on it.
                    if let sheetScope, !sheetScope.contains(ref.sheet) { continue }

                    // With a filter, a reference to an excluded cell is dropped with
                    // its edge. Without one, every referenced address becomes a node
                    // — including cells holding nothing — which is what an evaluator
                    // needs and what ``init(workbook:)`` has always done.
                    if including != nil && !inScope.contains(ref) { continue }

                    uniqueRefs.append(ref)
                }

                precedents[cellAddr] = uniqueRefs
                for ref in uniqueRefs {
                    cells.insert(ref)
                    dependents[ref, default: []].append(cellAddr)
                }
            }
        }

        self.precedentMap = precedents
        self.dependentMap = dependents
        self.allCells = cells

        let (sorted, cycles) = DependencyGraph.topologicalSort(
            cells: cells,
            precedents: precedents,
            dependents: dependents
        )
        self.sortedCells = sorted
        self.detectedCycles = cycles
    }

    // MARK: - Public API

    /// All cells in topological order (evaluate in this order).
    ///
    /// Cells with no dependencies appear first, followed by cells that
    /// depend only on already-listed cells. If cycles exist, only the
    /// acyclic portion is included.
    public var evaluationOrder: [CellAddress] {
        sortedCells
    }

    /// Cells with no formula -- the inputs to the model.
    ///
    /// A cell is an input if it has no precedents (i.e., it does not contain
    /// a formula referencing other cells).
    public var inputs: [CellAddress] {
        allCells
            .filter { (precedentMap[$0] ?? []).isEmpty }
            .sorted { $0.sortKey < $1.sortKey }
    }

    /// Cells with no dependents -- the outputs of the model.
    ///
    /// A cell is an output if no other cell's formula references it.
    public var outputs: [CellAddress] {
        allCells
            .filter { (dependentMap[$0] ?? []).isEmpty }
            .sorted { $0.sortKey < $1.sortKey }
    }

    /// Cells that directly depend on the given cell.
    ///
    /// - Parameter cell: The cell to query.
    /// - Returns: Cells whose formulas reference this cell.
    public func dependents(of cell: CellAddress) -> [CellAddress] {
        dependentMap[cell] ?? []
    }

    /// Cells that the given cell directly references in its formula.
    ///
    /// - Parameter cell: The cell to query.
    /// - Returns: Cells referenced by this cell's formula.
    public func precedents(of cell: CellAddress) -> [CellAddress] {
        precedentMap[cell] ?? []
    }

    /// All cells downstream of the given cell (transitive dependents).
    ///
    /// Uses breadth-first traversal to find all cells that would need
    /// recalculation if the given cell's value changed.
    ///
    /// - Parameter cell: The starting cell.
    /// - Returns: All transitively dependent cells.
    public func allDependents(of cell: CellAddress) -> Set<CellAddress> {
        var result = Set<CellAddress>()
        var queue = dependentMap[cell] ?? []

        // Guard: iterative BFS, no recursion needed
        while let current = queue.first {
            queue.removeFirst()
            guard result.insert(current).inserted else { continue }
            queue.append(contentsOf: dependentMap[current] ?? [])
        }

        return result
    }

    /// True if the graph has no cycles.
    public var isAcyclic: Bool {
        detectedCycles.isEmpty
    }

    /// If cycles exist, returns the cells involved in each cycle.
    public var cycles: [[CellAddress]] {
        detectedCycles
    }

    // MARK: - Reference Extraction

    /// Extracts all cell address references from a formula AST.
    ///
    /// Recursively walks the AST and collects every cell reference,
    /// including those inside ranges and cross-sheet references.
    ///
    /// - Parameters:
    ///   - ast: The formula AST to walk.
    ///   - inSheet: The name of the sheet containing the formula (for unqualified refs).
    /// - Returns: All cell addresses referenced by the formula.
    /// A reference with its `$` markers dropped.
    ///
    /// A marker says how a formula *fills* when copied, not which cell it means:
    /// `$C12`, `C$12` and `C12` are one cell. ``CellRef`` hashes the markers, so
    /// carrying them into the graph splits a cell into as many nodes as the forms
    /// used to reach it — a phantom `$B$3` beside the real `B3`, with the edges
    /// divided between them.
    ///
    /// That is not a small error on real models. A mixed reference is how a rule
    /// fills across a row while holding one operand still, so the edges lost are
    /// exactly the ones tying every period back to its assumptions.
    ///
    /// - Parameter reference: The reference as written.
    /// - Returns: The same cell, unmarked.
    private static func unmarked(_ reference: CellRef) -> CellRef {
        CellRef(column: reference.column, row: reference.row)
    }

    private static func extractReferences(
        from ast: FormulaAST,
        inSheet: String
    ) -> [CellAddress] {
        // Guard: base cases return immediately, recursive cases reduce AST depth
        switch ast {
        case .cellRef(let ref):
            return [CellAddress(sheet: inSheet, cell: unmarked(ref))]

        case .cellRange(let range):
            return range.cells.map { CellAddress(sheet: inSheet, cell: unmarked($0)) }

        case .sheetRef(let sheetRef):
            return sheetRef.range.cells.map {
                CellAddress(sheet: sheetRef.sheetName, cell: unmarked($0))
            }

        case .namedRange:
            // Named range resolution requires a NameResolver; skip for now
            return []

        case .number, .text, .bool, .error:
            return []

        case .add(let l, let r),
             .subtract(let l, let r),
             .multiply(let l, let r),
             .divide(let l, let r),
             .power(let l, let r),
             .concatenate(let l, let r),
             .equal(let l, let r),
             .notEqual(let l, let r),
             .greaterThan(let l, let r),
             .lessThan(let l, let r),
             .greaterOrEqual(let l, let r),
             .lessOrEqual(let l, let r):
            return extractReferences(from: l, inSheet: inSheet)
                 + extractReferences(from: r, inSheet: inSheet)

        case .negate(let expr):
            return extractReferences(from: expr, inSheet: inSheet)

        case .function(_, let args):
            return args.flatMap { extractReferences(from: $0, inSheet: inSheet) }
        }
    }

    // MARK: - Topological Sort

    /// Performs Kahn's algorithm for topological sorting.
    ///
    /// - Parameters:
    ///   - cells: All cells in the graph.
    ///   - precedents: Map from each cell to its direct precedents.
    ///   - dependents: Map from each cell to its direct dependents.
    /// - Returns: A tuple of (sorted cells, detected cycles).
    private static func topologicalSort(
        cells: Set<CellAddress>,
        precedents: [CellAddress: [CellAddress]],
        dependents: [CellAddress: [CellAddress]]
    ) -> ([CellAddress], [[CellAddress]]) {
        guard !cells.isEmpty else { return ([], []) }

        // Compute in-degree for each cell
        var inDegree: [CellAddress: Int] = [:]
        for cell in cells {
            inDegree[cell] = (precedents[cell] ?? []).count
        }

        // Start with cells that have in-degree 0 (no dependencies)
        var queue = cells
            .filter { inDegree[$0] == 0 }
            .sorted { $0.sortKey < $1.sortKey }
        var result: [CellAddress] = []

        while let current = queue.first {
            queue.removeFirst()
            result.append(current)

            // For each dependent, reduce its in-degree
            for dep in dependents[current] ?? [] {
                guard var degree = inDegree[dep] else { continue }
                degree -= 1
                inDegree[dep] = degree
                if degree == 0 {
                    // Insert in sorted order for deterministic output
                    let insertIdx = queue.firstIndex { $0.sortKey > dep.sortKey } ?? queue.endIndex
                    queue.insert(dep, at: insertIdx)
                }
            }
        }

        // If not all cells were processed, there are cycles
        var detectedCycles: [[CellAddress]] = []
        if result.count < cells.count {
            let remaining = cells.subtracting(Set(result))
            detectedCycles = findCycles(in: remaining, precedents: precedents)
        }

        return (result, detectedCycles)
    }

    // MARK: - Cycle Detection

    /// Finds cycles among the remaining (unprocessed) nodes using DFS.
    ///
    /// - Parameters:
    ///   - nodes: The set of nodes known to be part of cycles.
    ///   - precedents: The precedent map.
    /// - Returns: An array of cycle paths.
    private static func findCycles(
        in nodes: Set<CellAddress>,
        precedents: [CellAddress: [CellAddress]]
    ) -> [[CellAddress]] {
        var visited = Set<CellAddress>()
        var cycles: [[CellAddress]] = []

        for node in nodes.sorted(by: { $0.sortKey < $1.sortKey }) {
            guard !visited.contains(node) else { continue }

            // Follow precedent chain within remaining nodes to find cycle
            var path: [CellAddress] = []
            var current = node
            var pathSet = Set<CellAddress>()

            // Guard: each iteration either adds to path or exits
            while !pathSet.contains(current) {
                pathSet.insert(current)
                path.append(current)
                visited.insert(current)

                // Follow a precedent that is also in the remaining set
                let nextCandidates = (precedents[current] ?? []).filter { nodes.contains($0) }
                guard let next = nextCandidates.first else { break }
                current = next
            }

            // If we found a cycle, extract the cycle portion
            if let cycleStart = path.firstIndex(of: current) {
                let cycle = Array(path[cycleStart...])
                if !cycle.isEmpty {
                    cycles.append(cycle)
                }
            }
        }

        return cycles
    }
}

// MARK: - CellAddress Sort Key

extension CellAddress {
    /// A deterministic sort key for consistent ordering: sheet name, then column, then row.
    var sortKey: String {
        let colStr = String(cell.column)
        let rowStr = String(cell.row)
        let col = String(repeating: "0", count: max(0, 6 - colStr.count)) + colStr
        let row = String(repeating: "0", count: max(0, 9 - rowStr.count)) + rowStr
        return "\(sheet)!\(col)\(row)"
    }
}
