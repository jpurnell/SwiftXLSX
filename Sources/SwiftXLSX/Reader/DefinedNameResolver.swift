import Foundation
import SwiftExcelCore

/// Turns a `definedName` element into a ``NamedRange``.
///
/// The file states a name's target as a formula string — `'ANSWER KEY'!$M$1`,
/// `Sheet1!$A$1:$D$10`, `Expenditures!$D:$D`, or an expression that is not a
/// reference at all. Excel permits any formula, so the shapes worth recognizing
/// are recognized and the rest is kept verbatim as ``NamedRangeTarget/unparsed(_:)``.
///
/// ## Why `.unparsed` rather than `.formula(.text(…))`
///
/// The old fallback claimed a name it could not read **was a text constant**, which
/// is a different name. Written back out it gains quotes — a range becomes a caption
/// and a number becomes a string — and evaluated, it hands a formula a caption where
/// a range was meant. `SUMIFS(amounts, …)` answered zero across 1,058 cells in one
/// corpus workbook for exactly that reason.
///
/// `.unparsed` says the true thing instead, and is the one target whose round trip is
/// exact by construction: reproducing it is the identity function.
enum DefinedNameResolver {

    /// Builds a named range from a parsed `definedName`.
    ///
    /// - Parameters:
    ///   - info: The element as parsed.
    ///   - sheets: The workbook's sheets, in file order, to turn a `localSheetId`
    ///     into the sheet name ``NameScope`` carries.
    /// - Returns: The named range, or `nil` when the element has no usable name.
    static func namedRange(from info: DefinedNameInfo, sheets: [SheetInfo]) -> NamedRange? {
        let name = info.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let scope: NameScope
        if let index = info.localSheetId, sheets.indices.contains(index) {
            scope = .sheet(sheets[index].name)
        } else {
            scope = .workbook
        }

        let formula = info.formula.trimmingCharacters(in: .whitespacesAndNewlines)
        return NamedRange(name: name, reference: target(of: formula), scope: scope,
                          isHidden: info.isHidden, attributes: info.attributes)
    }

    /// The target a name's formula string denotes.
    private static func target(of formula: String) -> NamedRangeTarget {
        guard let separator = formula.lastIndex(of: "!") else {
            return local(formula) ?? .unparsed(formula)
        }

        let sheet = unquoted(String(formula[formula.startIndex..<separator]))
        let body = String(formula[formula.index(after: separator)...])
        guard !sheet.isEmpty else { return .unparsed(formula) }

        switch local(body) {
        case .cell(let ref):
            return .sheetCell(SheetReference(sheet: sheet, cell: ref))
        case .range(let range):
            return .sheetRange(SheetReference(sheet: sheet, range: range))
        default:
            return .unparsed(formula)
        }
    }

    /// A sheet-less reference, as a cell or a range.
    ///
    /// Handles the whole-column and whole-row forms as well as `A1`-style ones —
    /// `$D:$D` and `$3:$3` are references, and reading them as anything else is what
    /// made `amounts = Expenditures!$D:$D` evaluate to its own text.
    private static func local(_ body: String) -> NamedRangeTarget? {
        let parts = body.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, let span = wholeSpan(parts[0], parts[1]) { return span }
        guard parts.allSatisfy({ isReference($0) }) else { return nil }

        if parts.count == 2 {
            return .range(CellRange(from: CellRef(String(parts[0])), to: CellRef(String(parts[1]))))
        }
        guard parts.count == 1 else { return nil }
        return .cell(CellRef(String(parts[0])))
    }

    /// A whole column or a whole row, as the range it names.
    ///
    /// `$D:$D` is every cell of column D and `$3:$3` is every cell of row 3. Excel writes
    /// both, and both were unreadable here because ``isReference(_:)`` requires a letter
    /// *and* a digit in each half — `$D` has no digit and `$3` has no letter.
    ///
    /// **Delegates to `CellRange.wholeSpan(from:to:)` as of SwiftExcelCore 0.14.0.** This
    /// used to carry its own copy of the rule, and it was the *correct* copy: `CellRange`'s
    /// own string initialiser split on the colon and handed each half to `CellRef`, which
    /// read `A:A` as the single cell `A1` and `1:1` as a range in column zero. Defined names
    /// round-tripped across 161,901 of them precisely because they never went through that
    /// path — which is also why nobody found it. One rule, one place, and the place is the
    /// type the rule is about.
    ///
    /// - Parameters:
    ///   - start: The half before the colon.
    ///   - end: The half after it.
    /// - Returns: The range, or `nil` when the pair is not a whole span.
    private static func wholeSpan(_ start: Substring, _ end: Substring) -> NamedRangeTarget? {
        CellRange.wholeSpan(from: start, to: end).map { .range($0) }
    }

    /// Whether a fragment is an `A1`-style reference and nothing else.
    ///
    /// Checked before parsing rather than after, because ``CellRef`` is
    /// deliberately forgiving — it reads anything and defaults what it cannot
    /// find, so `SUM(A1)` would arrive as a plausible cell rather than as a
    /// refusal.
    private static func isReference(_ fragment: Substring) -> Bool {
        var sawLetter = false
        var sawDigit = false
        for character in fragment {
            if character == "$" { continue }
            if character.isLetter, !sawDigit { sawLetter = true; continue }
            if character.isNumber, sawLetter { sawDigit = true; continue }
            return false
        }
        return sawLetter && sawDigit
    }

    /// Strips the quotes Excel puts around a sheet name that needs them.
    private static func unquoted(_ sheet: String) -> String {
        guard sheet.count >= 2, sheet.hasPrefix("'"), sheet.hasSuffix("'") else { return sheet }
        return String(sheet.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
    }
}
