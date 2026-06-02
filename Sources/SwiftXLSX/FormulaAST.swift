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

    // Function call
    case function(String, [FormulaAST])
}

// MARK: - Convenience Builders

extension FormulaAST {

    // MARK: Aggregation

    public static func sum(_ range: FormulaAST) -> FormulaAST {
        .function("SUM", [range])
    }

    public static func average(_ range: FormulaAST) -> FormulaAST {
        .function("AVERAGE", [range])
    }

    public static func count(_ range: FormulaAST) -> FormulaAST {
        .function("COUNT", [range])
    }

    public static func min(_ range: FormulaAST) -> FormulaAST {
        .function("MIN", [range])
    }

    public static func max(_ range: FormulaAST) -> FormulaAST {
        .function("MAX", [range])
    }

    public static func stdev(_ range: FormulaAST) -> FormulaAST {
        .function("STDEV", [range])
    }

    public static func median(_ range: FormulaAST) -> FormulaAST {
        .function("MEDIAN", [range])
    }

    // MARK: Financial

    public static func pmt(rate: FormulaAST, nper: FormulaAST, pv: FormulaAST) -> FormulaAST {
        .function("PMT", [rate, nper, pv])
    }

    public static func ipmt(rate: FormulaAST, per: FormulaAST,
                             nper: FormulaAST, pv: FormulaAST) -> FormulaAST {
        .function("IPMT", [rate, per, nper, pv])
    }

    public static func ppmt(rate: FormulaAST, per: FormulaAST,
                             nper: FormulaAST, pv: FormulaAST) -> FormulaAST {
        .function("PPMT", [rate, per, nper, pv])
    }

    public static func npv(rate: FormulaAST, values: FormulaAST) -> FormulaAST {
        .function("NPV", [rate, values])
    }

    public static func irr(values: FormulaAST, guess: FormulaAST = .number(0.1)) -> FormulaAST {
        .function("IRR", [values, guess])
    }

    public static func fv(rate: FormulaAST, nper: FormulaAST, pmt: FormulaAST) -> FormulaAST {
        .function("FV", [rate, nper, pmt])
    }

    public static func pv(rate: FormulaAST, nper: FormulaAST, pmt: FormulaAST) -> FormulaAST {
        .function("PV", [rate, nper, pmt])
    }

    // MARK: Statistical

    public static func percentile(_ range: FormulaAST, k: FormulaAST) -> FormulaAST {
        .function("PERCENTILE", [range, k])
    }

    // MARK: Logical

    public static func `if`(_ test: FormulaAST, then: FormulaAST,
                             `else`: FormulaAST) -> FormulaAST {
        .function("IF", [test, then, `else`])
    }

    // MARK: Lookup

    public static func vlookup(value: FormulaAST, table: FormulaAST,
                                col: FormulaAST, exactMatch: Bool = false) -> FormulaAST {
        .function("VLOOKUP", [value, table, col, .bool(!exactMatch)])
    }
}
