import Foundation

/// Turns a `definedName` element into a ``NamedRange``.
///
/// The file states a name's target as a formula string — `'ANSWER KEY'!$M$1`,
/// `Sheet1!$A$1:$D$10`, or an expression that is not a reference at all. Excel
/// permits any formula, so the shapes worth recognizing are recognized and the
/// rest is kept verbatim rather than discarded: a name whose target this cannot
/// parse is still a name, and a caller can look at what the file said.
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
        return NamedRange(name: name, reference: target(of: formula), scope: scope)
    }

    /// The target a name's formula string denotes.
    private static func target(of formula: String) -> NamedRangeTarget {
        guard let separator = formula.lastIndex(of: "!") else {
            return local(formula) ?? .formula(.text(formula))
        }

        let sheet = unquoted(String(formula[formula.startIndex..<separator]))
        let body = String(formula[formula.index(after: separator)...])
        guard !sheet.isEmpty else { return .formula(.text(formula)) }

        switch local(body) {
        case .cell(let ref):
            return .sheetCell(SheetReference(sheet: sheet, cell: ref))
        case .range(let range):
            return .sheetRange(SheetReference(sheet: sheet, range: range))
        default:
            return .formula(.text(formula))
        }
    }

    /// A sheet-less reference, as a cell or a range.
    private static func local(_ body: String) -> NamedRangeTarget? {
        let parts = body.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.allSatisfy({ isReference($0) }) else { return nil }

        if parts.count == 2 {
            return .range(CellRange(from: CellRef(String(parts[0])), to: CellRef(String(parts[1]))))
        }
        guard parts.count == 1 else { return nil }
        return .cell(CellRef(String(parts[0])))
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
