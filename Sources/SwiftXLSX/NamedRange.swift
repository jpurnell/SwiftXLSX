// MARK: - NameScope

/// The scope of a named range: workbook-wide or sheet-specific.
public enum NameScope: Sendable, Equatable, Hashable {
    case workbook
    case sheet(String)
}

// MARK: - NamedRangeTarget

/// What a named range resolves to.
public enum NamedRangeTarget: Sendable, Equatable, Hashable {
    case cell(CellRef) // LIVE: public API for consumers
    case range(CellRange) // LIVE: public API for consumers
    case sheetCell(SheetReference) // LIVE: public API for consumers
    case sheetRange(SheetReference) // LIVE: public API for consumers
    case formula(FormulaAST) // LIVE: public API for consumers
}

// MARK: - NamedRange

/// An Excel named range binding a name to a cell, range, or formula.
public struct NamedRange: Sendable, Equatable, Hashable {
    /// The name of this named range.
    public let name: String
    /// The target this name resolves to.
    public let reference: NamedRangeTarget
    /// Whether this name is workbook-scoped or sheet-scoped.
    public let scope: NameScope

    /// Creates a named range with the given name, target, and scope.
    public init(
        name: String,
        reference: NamedRangeTarget,
        scope: NameScope = .workbook
    ) {
        self.name = name
        self.reference = reference
        self.scope = scope
    }
}

// MARK: - NameResolver Protocol

/// Resolves named range identifiers to their targets.
public protocol NameResolver: Sendable {
    /// Resolves a name, optionally within a specific sheet context.
    func resolve(_ name: String, inSheet: String?) -> NamedRangeTarget?
}

// MARK: - NamedRangeCollection

/// A collection of named ranges with case-insensitive resolution.
public struct NamedRangeCollection: Sendable {
    private var ranges: [NamedRange] = []

    /// Creates an empty collection.
    public init() {}

    /// Creates a collection from an array of named ranges.
    public init(_ ranges: [NamedRange]) {
        self.ranges = ranges
    }

    /// Adds a named range to the collection.
    public mutating func add(_ range: NamedRange) {
        ranges.append(range)
    }

    /// Resolves a name with sheet-scope-takes-precedence semantics.
    public func resolve(_ name: String, inSheet: String? = nil) -> NamedRangeTarget? {
        let lowercasedName = name.lowercased()

        var workbookMatch: NamedRangeTarget?
        var sheetMatch: NamedRangeTarget?

        for range in ranges {
            guard range.name.lowercased() == lowercasedName else { continue }

            switch range.scope {
            case .workbook:
                if workbookMatch == nil {
                    workbookMatch = range.reference
                }
            case .sheet(let sheetName):
                if let inSheet, sheetName == inSheet, sheetMatch == nil {
                    sheetMatch = range.reference
                }
            }
        }

        return sheetMatch ?? workbookMatch
    }

    /// All named ranges in the collection.
    public var all: [NamedRange] { ranges }

    /// The number of named ranges.
    public var count: Int { ranges.count }
}

// MARK: - NamedRangeCollection + NameResolver

extension NamedRangeCollection: NameResolver {}
