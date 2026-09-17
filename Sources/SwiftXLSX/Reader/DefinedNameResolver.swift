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
    /// The absolute markers are carried through, so the range remembers it was written
    /// `$D:$D` rather than `D:D` and a writer can put back what it read.
    ///
    /// - Parameters:
    ///   - start: The half before the colon.
    ///   - end: The half after it.
    /// - Returns: The range, or `nil` when the pair is not a whole span.
    private static func wholeSpan(_ start: Substring, _ end: Substring) -> NamedRangeTarget? {
        if let first = columnNumber(start), let last = columnNumber(end) {
            return .range(CellRange(
                from: CellRef(column: first, row: 1,
                              absoluteColumn: start.hasPrefix("$"), absoluteRow: false),
                to: CellRef(column: last, row: CellRef.lastOnSheet.row,
                            absoluteColumn: end.hasPrefix("$"), absoluteRow: false)))
        }
        if let first = rowNumber(start), let last = rowNumber(end) {
            return .range(CellRange(
                from: CellRef(column: 1, row: first,
                              absoluteColumn: false, absoluteRow: start.hasPrefix("$")),
                to: CellRef(column: CellRef.lastOnSheet.column, row: last,
                            absoluteColumn: false, absoluteRow: end.hasPrefix("$"))))
        }
        return nil
    }

    /// A fragment that is nothing but a column, as its number.
    private static func columnNumber(_ fragment: Substring) -> Int? {
        let letters = fragment.drop { $0 == "$" }
        guard !letters.isEmpty, letters.allSatisfy({ $0.isLetter }) else { return nil }
        var number = 0
        for letter in letters.uppercased().unicodeScalars {
            guard let value = letter.value as UInt32?, value >= 65, value <= 90 else { return nil }
            number = number * 26 + Int(value - 64)
        }
        return number <= CellRef.lastOnSheet.column ? number : nil
    }

    /// A fragment that is nothing but a row, as its number.
    private static func rowNumber(_ fragment: Substring) -> Int? {
        let digits = fragment.drop { $0 == "$" }
        guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }), let number = Int(digits)
        else { return nil }
        return (1...CellRef.lastOnSheet.row).contains(number) ? number : nil
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
