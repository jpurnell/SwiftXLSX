import Foundation

/// How a number is spelled in a spreadsheet file.
///
/// One rule, in one place, because it was in four and three of them were wrong in the same
/// way. `Workbook` writes cell values, cached results, row heights and validation bounds;
/// `FormulaSerializer` writes literals inside formula text; `StyleSheet` writes font sizes.
/// All four want a whole number written `3` rather than `3.0`, and all four had written that
/// wish as an unguarded `Int` conversion.
enum NumberText {

    /// A number as the file format wants it written.
    ///
    /// A whole number is written `3` rather than `3.0`, because that is what Excel writes and
    /// a round trip that changes every integer in a workbook cannot be diffed. The obvious
    /// way to say that — `n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) :
    /// String(n)` — is a trap in the literal sense, and stood at five call sites.
    ///
    /// The whole-ness test is right; the conversion under it is not. **Every** Double past
    /// `Int.max` is integer-valued — at that magnitude the format has no fractional bits left
    /// — so the guard admits precisely the numbers `Int` cannot represent, and `Int(n)` traps
    /// on them. A corpus round trip over 2,240 workbooks found it at a cell holding about
    /// 1e19: not a throw that could be caught and reported, a `SIGTRAP` that took the process.
    ///
    /// So the question is asked of `Int` rather than answered on its behalf. `Int(exactly:)`
    /// is the whole-ness test and the range test at once, and it is the only form of either
    /// that cannot be wrong: the first repair here checked `number <= Double(Int.max)`, which
    /// has the same defect one layer up — `Double(Int.max)` is not `Int.max` but the next
    /// representable value *above* it, so the bound admits the one number that trapped.
    ///
    /// A number `Int` cannot hold keeps its `Double` spelling, which is valid `xsd:double`
    /// and reads back as the same number. Infinity and NaN are not values a cell can hold and
    /// have no spelling any reader accepts, so they are clamped rather than written as `inf`
    /// or `nan` — which Excel reports as a damaged file.
    ///
    /// - Parameter number: The value to write.
    /// - Returns: The text for the `<v>` element.
    static func of(_ number: Double) -> String {
        guard number.isFinite else {
            guard !number.isNaN else { return "0" }
            return String(number > 0 ? Double.greatestFiniteMagnitude : -.greatestFiniteMagnitude)
        }
        guard let whole = Int(exactly: number) else { return String(number) }
        return String(whole)
    }
}
