public struct NamedRange: Equatable, Hashable, Sendable {
    public let name: String
    public let reference: NamedRangeTarget
    public let scope: NameScope

    public enum NameScope: Equatable, Hashable, Sendable {
        case workbook
        case sheet(String)
    }

    public init(name: String, reference: NamedRangeTarget, scope: NameScope = .workbook) {
        self.name = name
        self.reference = reference
        self.scope = scope
    }
}

public enum NamedRangeTarget: Equatable, Hashable, Sendable {
    case cell(CellRef)
    case range(CellRange)
    case sheetCell(SheetReference)
    case sheetRange(SheetReference)
    case formula(FormulaAST)
}
