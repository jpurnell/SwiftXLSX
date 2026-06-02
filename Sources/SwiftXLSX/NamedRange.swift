// MARK: - NameScope

public enum NameScope: Sendable, Equatable, Hashable {
    case workbook
    case sheet(String)
}

// MARK: - NamedRangeTarget

public enum NamedRangeTarget: Sendable, Equatable, Hashable {
    case cell(CellRef)
    case range(CellRange)
    case sheetCell(SheetReference)
    case sheetRange(SheetReference)
    case formula(FormulaAST)
}

// MARK: - NamedRange

public struct NamedRange: Sendable, Equatable, Hashable {
    public let name: String
    public let reference: NamedRangeTarget
    public let scope: NameScope

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

public protocol NameResolver: Sendable {
    func resolve(_ name: String, inSheet: String?) -> NamedRangeTarget?
}

// MARK: - NamedRangeCollection

public struct NamedRangeCollection: Sendable {
    private var ranges: [NamedRange] = []

    public init() {}

    public init(_ ranges: [NamedRange]) {
        self.ranges = ranges
    }

    public mutating func add(_ range: NamedRange) {
        ranges.append(range)
    }

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

    public var all: [NamedRange] { ranges }

    public var count: Int { ranges.count }
}

// MARK: - NamedRangeCollection + NameResolver

extension NamedRangeCollection: NameResolver {}
