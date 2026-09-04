import SwiftExcelCore
/// The type of data validation to apply to a cell range.
public enum ValidationType: Sendable {
    /// Restricts input to a dropdown list of values.
    case list([String]) // LIVE: public API for consumers
    /// Restricts input to a decimal number within a range.
    case decimal(min: Double, max: Double) // LIVE: public API for consumers
    /// Restricts input to an integer within a range.
    case integer(min: Int, max: Int) // LIVE: public API for consumers
}
