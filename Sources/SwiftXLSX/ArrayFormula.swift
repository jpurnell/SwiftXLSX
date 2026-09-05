import SwiftExcelCore

/// One formula filling a rectangle of cells.
///
/// An array formula is stored once, at the top-left cell of the range it fills;
/// every other cell in that range is marked as computed by it. ``Worksheet``
/// records them so that something recalculating a workbook can find them —
/// evaluating one and writing its result back needs both halves, and only the
/// sheet knows where the spans are.
///
/// A struct rather than a tuple because this is public surface: a struct can gain
/// a field without breaking the callers that already destructure it.
public struct ArrayFormula: Equatable, Hashable, Sendable {

    /// The top-left cell, which carries the formula text.
    public let anchor: CellRef

    /// The rectangle the formula fills, including the anchor.
    public let span: CellRange

    /// Creates a record of an array formula.
    ///
    /// - Parameters:
    ///   - anchor: The top-left cell, which carries the formula.
    ///   - span: The rectangle it fills.
    public init(anchor: CellRef, span: CellRange) {
        self.anchor = anchor
        self.span = span
    }
}
