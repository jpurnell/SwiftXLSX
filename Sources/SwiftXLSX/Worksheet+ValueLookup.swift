import SwiftExcelCore
/// Convenience methods for looking up cell values by ``CellRef`` and ``CellRange``.
extension Worksheet {
    /// Returns the value at the given cell reference, or `nil` if the cell is empty.
    ///
    /// Markers are ignored: `$D$66` and `D66` name the same cell, and `$` says how
    /// a reference behaves when a formula is copied rather than where it points.
    ///
    /// - Parameter ref: The cell reference to look up.
    /// - Returns: The cell value, or `nil` if the cell is empty.
    func value(at ref: CellRef) -> CellValue? {
        cells[Worksheet.storageKey(for: ref)]?.0
    }

    /// Returns all non-nil values in the given cell range.
    ///
    /// Iterates over every cell in the range and collects those that have values,
    /// skipping empty cells.
    ///
    /// - Parameter range: The cell range to enumerate.
    /// - Returns: An array of cell values for populated cells.
    func values(in range: CellRange) -> [CellValue] {
        range.cells.compactMap { value(at: $0) }
    }
}
