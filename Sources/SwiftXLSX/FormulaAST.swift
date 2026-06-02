public indirect enum FormulaAST: Equatable, Hashable, Sendable {

    // Leaf nodes
    case cellRef(CellRef)
    case cellRange(CellRange)
    case sheetRef(SheetReference)
    case namedRange(String)
    case number(Double)
    case text(String)
    case bool(Bool)
    case error(ExcelError)

    // Arithmetic
    case add(FormulaAST, FormulaAST)
    case subtract(FormulaAST, FormulaAST)
    case multiply(FormulaAST, FormulaAST)
    case divide(FormulaAST, FormulaAST)
    case power(FormulaAST, FormulaAST)
    case negate(FormulaAST)
    case concatenate(FormulaAST, FormulaAST)

    // Comparison
    case equal(FormulaAST, FormulaAST)
    case notEqual(FormulaAST, FormulaAST)
    case greaterThan(FormulaAST, FormulaAST)
    case lessThan(FormulaAST, FormulaAST)
    case greaterOrEqual(FormulaAST, FormulaAST)
    case lessOrEqual(FormulaAST, FormulaAST)

    // Function call — generic, handles all Excel functions
    case function(String, [FormulaAST])

    // Convenience builders — stub, agent implements
}
