import Foundation

public enum CellValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case formula(String)
    case date(Date)
    case blank
}
