import Foundation
import SwiftExcelCore

/// Reads the little of a pivot table definition that `GETPIVOTDATA` needs.
///
/// ## What is read, and what is ignored
///
/// **A pivot table's values are already on the worksheet.** Excel renders them into cells and
/// caches them there like any other formula result, so `GETPIVOTDATA` is a lookup into a
/// rendered table rather than a recomputation — it aggregates nothing, and `xl/pivotCache/` is
/// never opened. One corpus workbook carries **76 cache parts**; none of them is read.
///
/// So this takes five things out of a definition that is typically 5 KB, and ignores the rest:
///
/// | Wanted | Where |
/// |---|---|
/// | the rectangle on the sheet | `<location ref="M1:O253"/>` |
/// | where the data starts inside it | `firstDataRow`, `firstDataCol` on the same element |
/// | the data field names, in order | `<dataField name="…"/>` |
/// | whether a grand total row is rendered | `rowGrandTotals`, **defaulting to on** |
/// | whether a grand total column is | `colGrandTotals`, the same |
///
/// The defaults matter: an absent `rowGrandTotals` means the total **is** rendered, so a
/// reader that treats "attribute missing" as `false` loses the row `GETPIVOTDATA` most often
/// asks for.
///
/// ## Why the attributes rather than the labels
///
/// The grand total is the last row of `ref` when `rowGrandTotals` is on. It is deliberately
/// not found by looking for a row reading `"Grand Total"`.
///
/// Measured: `Dot Com YTD Performance Report 6 20.xlsx` carries pivots both ways, and one with
/// `rowGrandTotals="0"` ends on a row reading **`"KEY Total"`** — a *subtotal*. A label match
/// would have taken it for a grand total and returned the wrong number quietly. Reading the
/// attributes avoids that, and avoids the locale trap beside it: the same label reads
/// `"Gesamtergebnis"` in a German workbook.
enum PivotTableParser {

    /// Reads one pivot table definition.
    ///
    /// - Parameters:
    ///   - data: The bytes of an `xl/pivotTables/pivotTableN.xml` part.
    ///   - sheet: The sheet the table is rendered on.
    /// - Returns: The layout, or `nil` where the part carries no usable location.
    static func parse(data: Data, onSheet sheet: String) -> PivotTableLayout? {
        guard let xml = String(data: data, encoding: .utf8) else { return nil }
        guard let location = element(named: "location", in: xml),
              let reference = attribute("ref", of: location),
              let range = range(from: reference) else {
            return nil
        }

        // Absent means the first row and column of the rectangle are already data, which is
        // the shape a pivot with no headers has.
        let firstDataRow = attribute("firstDataRow", of: location).flatMap(Int.init) ?? 0
        let firstDataCol = attribute("firstDataCol", of: location).flatMap(Int.init) ?? 0

        var fields: [String] = []
        for element in elements(named: "dataField", in: xml) {
            guard let name = attribute("name", of: element) else { continue }
            fields.append(name)
        }

        return PivotTableLayout(
            sheet: sheet,
            range: range,
            firstDataRow: firstDataRow,
            firstDataCol: firstDataCol,
            dataFields: fields,
            // **Absent means present.** The file format defaults both to on, so a missing
            // attribute is a rendered total rather than the reverse.
            hasRowGrandTotals: flag("rowGrandTotals", in: xml) ?? true,
            hasColumnGrandTotals: flag("colGrandTotals", in: xml) ?? true)
    }

    // MARK: - Reading the pieces

    /// The first element with a given name, as its raw text.
    private static func element(named name: String, in xml: String) -> String? {
        elements(named: name, in: xml).first
    }

    /// Every element with a given name, as raw text.
    ///
    /// Matched on the opening tag rather than parsed, because five attributes out of a part
    /// this package writes nothing to does not justify a document model. The names looked for
    /// are fixed and the attribute values are quoted, which is the whole grammar needed.
    private static func elements(named name: String, in xml: String) -> [String] {
        var found: [String] = []
        var remaining = Substring(xml)
        while let open = remaining.range(of: "<\(name) ") {
            let rest = remaining[open.lowerBound...]
            guard let close = rest.range(of: ">") else { break }
            found.append(String(rest[rest.startIndex..<close.upperBound]))
            remaining = rest[close.upperBound...]
        }
        return found
    }

    /// One attribute's value out of an element's text.
    private static func attribute(_ name: String, of element: String) -> String? {
        guard let start = element.range(of: "\(name)=\"") else { return nil }
        let rest = element[start.upperBound...]
        guard let end = rest.range(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<end.lowerBound])
    }

    /// A boolean attribute anywhere in the part, or `nil` when it is absent.
    ///
    /// `nil` is the answer that matters: the caller turns it into the format's default, which
    /// is *on* for both grand totals.
    private static func flag(_ name: String, in xml: String) -> Bool? {
        guard let start = xml.range(of: "\(name)=\"") else { return nil }
        let rest = xml[start.upperBound...]
        guard let end = rest.range(of: "\"") else { return nil }
        let value = rest[rest.startIndex..<end.lowerBound]
        return value != "0" && value.lowercased() != "false"
    }

    /// A range from a `ref` attribute, which may name one cell or two.
    private static func range(from reference: String) -> CellRange? {
        let halves = reference.split(separator: ":", maxSplits: 1)
        guard let first = halves.first, !first.isEmpty else { return nil }
        let start = CellRef(String(first))
        guard halves.count == 2, !halves[1].isEmpty else {
            return CellRange(from: start, to: start)
        }
        return CellRange(from: start, to: CellRef(String(halves[1])))
    }
}
