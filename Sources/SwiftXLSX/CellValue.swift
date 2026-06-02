import Foundation

public enum CellValue: Equatable, Hashable, Sendable {
    case number(Double)
    case text(String)
    case bool(Bool)
    case error(ExcelError)
    indirect case formula(FormulaAST, cached: CellValue?)
    case date(Date)
    case blank
    indirect case array([CellValue])

    public var resolved: CellValue {
        switch self {
        case .formula(_, let cached):
            return cached ?? .blank
        default:
            return self
        }
    }

    public var isFormula: Bool {
        if case .formula = self { return true }
        return false
    }

    public var formulaAST: FormulaAST? {
        if case .formula(let ast, _) = self { return ast }
        return nil
    }
}
