import Foundation

/// A unified cell value type matching Excel's value semantics.
public enum CellValue: Equatable, Hashable, Sendable {
    case number(Double)
    case text(String)
    case bool(Bool)
    case error(ExcelError)
    indirect case formula(FormulaAST, cached: CellValue?)
    case date(Date)
    case blank
    indirect case array([CellValue])

    /// The resolved value; returns cached value for formulas, self otherwise.
    public var resolved: CellValue {
        switch self {
        case .formula(_, let cached):
            return cached ?? .blank
        default:
            return self
        }
    }

    /// Whether this value is a formula.
    public var isFormula: Bool {
        if case .formula = self { return true }
        return false
    }

    /// The formula AST if this is a formula value, nil otherwise.
    public var formulaAST: FormulaAST? {
        if case .formula(let ast, _) = self { return ast }
        return nil
    }
}
