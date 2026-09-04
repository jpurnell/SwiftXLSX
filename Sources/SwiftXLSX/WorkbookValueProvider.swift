import SwiftExcelCore


/// A ``CellValueProvider`` backed by a ``Workbook``, scoped to a current sheet.
///
/// Use this provider to resolve cell references during formula evaluation.
///
/// ```swift
/// let wb = Workbook()
/// _ = wb.addSheet(name: "Sheet1")
/// let provider = WorkbookValueProvider(workbook: wb, currentSheet: "Sheet1")
/// let val = provider.value(at: CellRef("A1"))
/// ```
// Justification: Workbook is @unchecked Sendable (mutated only during construction)
public struct WorkbookValueProvider: CellValueProvider, @unchecked Sendable {
    /// The workbook to look up values in.
    private let workbook: Workbook
    /// The name of the current (default) sheet for unqualified references.
    private let currentSheet: String

    /// Creates a value provider for the given workbook and current sheet context.
    ///
    /// - Parameters:
    ///   - workbook: The workbook containing the worksheets.
    ///   - currentSheet: The name of the sheet to use for unqualified cell references.
    public init(workbook: Workbook, currentSheet: String) {
        self.workbook = workbook
        self.currentSheet = currentSheet
    }

    /// Returns the cell value at the given reference in the current sheet.
    public func value(at ref: CellRef) -> CellValue? {
        value(at: ref, inSheet: currentSheet)
    }

    /// Returns the cell value at the given reference in the specified sheet.
    public func value(at ref: CellRef, inSheet sheetName: String) -> CellValue? {
        guard let sheet = workbook.sheets.first(where: { $0.name == sheetName }) else {
            return nil
        }
        return sheet.value(at: ref)
    }

    /// Returns the cell values in the given range from the current sheet.
    public func values(in range: CellRange) -> [CellValue] {
        values(in: range, inSheet: currentSheet)
    }

    /// Returns the cell values in the given range from the specified sheet.
    public func values(in range: CellRange, inSheet sheetName: String) -> [CellValue] {
        guard let sheet = workbook.sheets.first(where: { $0.name == sheetName }) else {
            return []
        }
        return sheet.values(in: range)
    }
}
