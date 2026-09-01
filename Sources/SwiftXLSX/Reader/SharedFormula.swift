import Foundation

/// Derives a shared formula's text for the cells that do not carry it.
///
/// OOXML stores a formula repeated across a range only once. The group's master
/// cell holds the text and declares the span:
///
/// ```xml
/// <c r="B2"><f t="shared" ref="B2:B4" si="0">A2*2</f><v>40</v></c>
/// <c r="B3"><f t="shared" si="0"/><v>60</v></c>
/// <c r="B4"><f t="shared" si="0"/><v>80</v></c>
/// ```
///
/// Every other cell in the group carries only the `si` index. Its formula is the
/// master's with each **relative** reference shifted by the offset from the master
/// to that cell; absolute references are pinned and do not move. That is the same
/// rule Excel applies when a formula is filled, which is what shared formulas
/// record.
enum SharedFormula {

    /// Shifts every relative reference in a formula by a row and column offset.
    ///
    /// - Parameters:
    ///   - ast: The master cell's formula.
    ///   - rowDelta: Rows from the master to the dependent cell.
    ///   - columnDelta: Columns from the master to the dependent cell.
    /// - Returns: The dependent cell's formula. References shifted off the sheet
    ///   become `#REF!`, which is what Excel yields for the same shift.
    static func translate(_ ast: FormulaAST, rowDelta: Int, columnDelta: Int) -> FormulaAST {
        guard rowDelta != 0 || columnDelta != 0 else { return ast }

        switch ast {
        case .cellRef(let ref):
            guard let shifted = shift(ref, rowDelta: rowDelta, columnDelta: columnDelta) else {
                return .error(.ref)
            }
            return .cellRef(shifted)

        case .cellRange(let range):
            guard let shifted = shift(range, rowDelta: rowDelta, columnDelta: columnDelta) else {
                return .error(.ref)
            }
            return .cellRange(shifted)

        case .sheetRef(let reference):
            guard let shifted = shift(reference.range, rowDelta: rowDelta, columnDelta: columnDelta)
            else {
                return .error(.ref)
            }
            return .sheetRef(SheetReference(sheet: reference.sheetName, range: shifted))

        case .namedRange, .number, .text, .bool, .error:
            return ast

        case .add(let lhs, let rhs):
            return .add(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .subtract(let lhs, let rhs):
            return .subtract(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .multiply(let lhs, let rhs):
            return .multiply(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .divide(let lhs, let rhs):
            return .divide(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .power(let lhs, let rhs):
            return .power(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .concatenate(let lhs, let rhs):
            return .concatenate(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .equal(let lhs, let rhs):
            return .equal(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .notEqual(let lhs, let rhs):
            return .notEqual(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .greaterThan(let lhs, let rhs):
            return .greaterThan(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .lessThan(let lhs, let rhs):
            return .lessThan(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .greaterOrEqual(let lhs, let rhs):
            return .greaterOrEqual(
                each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .lessOrEqual(let lhs, let rhs):
            return .lessOrEqual(each(lhs, rowDelta, columnDelta), each(rhs, rowDelta, columnDelta))

        case .negate(let expr):
            return .negate(each(expr, rowDelta, columnDelta))

        case .function(let name, let args):
            return .function(name, args.map { each($0, rowDelta, columnDelta) })
        }
    }

    private static func each(
        _ ast: FormulaAST, _ rowDelta: Int, _ columnDelta: Int
    ) -> FormulaAST {
        translate(ast, rowDelta: rowDelta, columnDelta: columnDelta)
    }

    /// Shifts one reference, leaving absolute components pinned.
    ///
    /// - Returns: `nil` when the shift moves the reference off the sheet.
    private static func shift(_ ref: CellRef, rowDelta: Int, columnDelta: Int) -> CellRef? {
        let column = ref.absoluteColumn ? ref.column : ref.column + columnDelta
        let row = ref.absoluteRow ? ref.row : ref.row + rowDelta
        guard column >= 1, row >= 1 else { return nil }
        return CellRef(
            column: column,
            row: row,
            absoluteColumn: ref.absoluteColumn,
            absoluteRow: ref.absoluteRow
        )
    }

    private static func shift(_ range: CellRange, rowDelta: Int, columnDelta: Int) -> CellRange? {
        guard let start = shift(range.start, rowDelta: rowDelta, columnDelta: columnDelta),
              let end = shift(range.end, rowDelta: rowDelta, columnDelta: columnDelta) else {
            return nil
        }
        return CellRange(from: start, to: end)
    }
}
