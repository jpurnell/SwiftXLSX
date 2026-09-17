import Foundation
import SwiftExcelCore

/// Writes a workbook's defined names back into `xl/workbook.xml`.
///
/// ## Reconstructed, not copied
///
/// A name is held once — its ``NamedRangeTarget`` *is* its meaning — and the refers-to text
/// is derived from that target here rather than kept alongside it. The alternative, storing
/// the file's original string beside the parsed target, is a second representation of one
/// fact, and two representations disagree the moment anything changes one of them: the writer
/// would put the *old* reference back into somebody's workbook and nothing would say so.
///
/// The cost of reconstructing is that every rule below has to be right. That cost is
/// **measurable** — read a corpus, write it, read it again, and any name that comes back
/// different has an address — where drift is a future mutation no test can enumerate.
///
/// ## The rules, and why each is a rule rather than stored state
///
/// | Shape | Written as | |
/// |---|---|---|
/// | ``NamedRangeTarget/unparsed(_:)`` | the text itself | exact by construction |
/// | a cell or range | its `A1` form | `CellRef` carries its own `$` markers |
/// | a full column or row span | `$D:$D`, not `D1:D1048576` | recognised from the span |
/// | a formula | ``FormulaSerializer`` | |
///
/// Sheet names are quoted only where Excel quotes them, which is the one rule here that is a
/// *judgement* rather than a fact about the data — see ``needsQuoting(_:)``.
enum DefinedNameWriter {

    /// The `<definedNames>` element, or empty when the workbook has none.
    ///
    /// - Parameters:
    ///   - names: The workbook's names, in the order they were read.
    ///   - sheets: The sheets, in file order, to turn a sheet-scoped name back into the
    ///     `localSheetId` index the format uses.
    /// - Returns: The XML, ready to sit between `</sheets>` and `<calcPr>`.
    static func element(for names: [NamedRange], sheets: [Worksheet]) -> String {
        guard !names.isEmpty else { return "" }
        var xml = "<definedNames>"
        for name in names {
            xml += "<definedName name=\"\(escape(name.name))\""
            if case .sheet(let sheetName) = name.scope,
               let index = sheets.firstIndex(where: { $0.name == sheetName }) {
                xml += " localSheetId=\"\(index)\""
            }
            if name.isHidden { xml += " hidden=\"1\"" }
            // Sorted so the output is stable: a workbook written twice is the same bytes,
            // which is what lets a round trip be diffed at all.
            for key in name.attributes.keys.sorted() {
                guard let value = name.attributes[key] else { continue }
                xml += " \(key)=\"\(escape(value))\""
            }
            xml += ">\(escape(refersTo(name.reference)))</definedName>"
        }
        return xml + "</definedNames>"
    }

    /// The refers-to text for a target.
    ///
    /// - Parameter target: What the name points at.
    /// - Returns: The formula string Excel expects.
    static func refersTo(_ target: NamedRangeTarget) -> String {
        switch target {
        case .unparsed(let text):
            // The identity, and the reason the rest of this is safe: anything this package
            // cannot prove it reproduces arrives here unchanged.
            return text
        case .cell(let ref):
            return ref.reference
        case .range(let range):
            return span(range)
        case .sheetCell(let reference):
            return "\(qualified(reference.sheetName))!\(reference.range.start.reference)"
        case .sheetRange(let reference):
            return "\(qualified(reference.sheetName))!\(span(reference.range))"
        case .formula(let ast):
            return FormulaSerializer.serialize(ast)
        }
    }

    /// A range, in the shortest form that names the same cells.
    ///
    /// **A full column is written `$D:$D`, not `D1:D1048576`.** The two select the same cells
    /// and only one of them is what the author wrote — the expansion shows up in the Name
    /// Manager and reads as a mistake. Recognising the span needs no stored flag: a range
    /// covering every row of its columns *is* a column reference.
    private static func span(_ range: CellRange) -> String {
        let start = range.start, end = range.end
        if start.row == 1, end.row == CellRef.lastOnSheet.row {
            return "\(marker(start.absoluteColumn))\(columnLetters(start.column))"
                + ":\(marker(end.absoluteColumn))\(columnLetters(end.column))"
        }
        if start.column == 1, end.column == CellRef.lastOnSheet.column {
            return "\(marker(start.absoluteRow))\(start.row):\(marker(end.absoluteRow))\(end.row)"
        }
        return "\(start.reference):\(end.reference)"
    }

    private static func marker(_ absolute: Bool) -> String { absolute ? "$" : "" }

    /// A column number as its letters.
    private static func columnLetters(_ column: Int) -> String {
        var remaining = column
        var letters = ""
        // Bounded: `remaining` divides by 26 each pass and the grid stops at 16,384.
        while remaining > 0 {
            let value = (remaining - 1) % 26
            guard let scalar = UnicodeScalar(UInt32(65 + value)) else { break }
            letters = String(Character(scalar)) + letters
            remaining = (remaining - 1) / 26
        }
        return letters
    }

    /// A sheet name, quoted if Excel would quote it.
    private static func qualified(_ sheet: String) -> String {
        needsQuoting(sheet) ? "'\(sheet.replacingOccurrences(of: "'", with: "''"))'" : sheet
    }

    /// Whether Excel writes a sheet name in quotes.
    ///
    /// **The one rule here that is a judgement rather than a fact about the data**, and the
    /// one to measure against a corpus rather than assume. Excel quotes a sheet name unless it
    /// is letters, digits and underscores and does not begin with a digit; quoting one that
    /// needs no quotes is accepted but is not what the file said, and this writer's job is to
    /// give back what it read.
    ///
    /// - Parameter sheet: The sheet's name.
    /// - Returns: `true` when the name must be quoted.
    static func needsQuoting(_ sheet: String) -> Bool {
        guard let first = sheet.first else { return true }
        if first.isNumber { return true }
        return !sheet.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    /// XML's five, so a name carrying an ampersand does not break the file.
    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
