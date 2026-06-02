public enum ExcelError: String, Equatable, Hashable, Sendable, CustomStringConvertible {
    case value = "#VALUE!"
    case ref = "#REF!"
    case div0 = "#DIV/0!"
    case name = "#NAME?"
    case null = "#NULL!"
    case num = "#NUM!"
    case na = "#N/A"

    public var description: String { rawValue }
}
