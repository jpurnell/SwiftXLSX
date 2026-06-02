/// A fully-qualified cell address combining a sheet name with a cell reference.
///
/// Use `CellAddress` to identify a specific cell across worksheets in a workbook.
///
/// ```swift
/// let addr = CellAddress(sheet: "Sheet1", ref: "B5")
/// ```
public struct CellAddress: Equatable, Hashable, Sendable {
    /// The name of the worksheet containing the cell.
    public let sheet: String
    /// The cell reference within the worksheet.
    public let cell: CellRef

    /// Creates a cell address from a sheet name and cell reference.
    ///
    /// - Parameters:
    ///   - sheet: The worksheet name.
    ///   - cell: The cell reference.
    public init(sheet: String, cell: CellRef) {
        self.sheet = sheet
        self.cell = cell
    }

    /// Creates a cell address by parsing a reference string like `"A1"` or `"$B$5"`.
    ///
    /// - Parameters:
    ///   - sheet: The worksheet name.
    ///   - ref: A cell reference string to parse into a ``CellRef``.
    public init(sheet: String, ref: String) {
        self.sheet = sheet
        self.cell = CellRef(ref)
    }
}
