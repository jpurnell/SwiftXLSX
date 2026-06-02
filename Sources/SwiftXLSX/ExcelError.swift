/// Standard Excel error values.
public enum ExcelError: String, Equatable, Hashable, Sendable, CustomStringConvertible {
    case value = "#VALUE!" // LIVE: public API for consumers
    case ref = "#REF!" // LIVE: public API for consumers
    case div0 = "#DIV/0!" // LIVE: public API for consumers
    case name = "#NAME?"
    case null = "#NULL!" // LIVE: public API for consumers
    case num = "#NUM!" // LIVE: public API for consumers
    case na = "#N/A" // LIVE: public API for consumers

    /// The raw error string, e.g. `#VALUE!`.
    public var description: String { rawValue }
}
