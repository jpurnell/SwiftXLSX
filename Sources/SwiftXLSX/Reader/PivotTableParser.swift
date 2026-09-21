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
    ///   - cacheFields: The names from the pivot's cache definition, in order, which is what
    ///     the indices in this part count in. Pass `[]` where the cache could not be read: the
    ///     axes then come back empty and the two-argument form still works off the captions.
    /// - Returns: The layout, or `nil` where the part carries no usable location.
    static func parse(data: Data, onSheet sheet: String,
                      cacheFields: [String] = []) -> PivotTableLayout? {
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

        // `firstHeaderRow` is its own attribute. It equals `firstDataRow - 1` on every pivot
        // measured so far, which is exactly why it must not be derived from it.
        let firstHeaderRow = attribute("firstHeaderRow", of: location).flatMap(Int.init) ?? 0
        let pageRows = attribute("rowPageCount", of: location).flatMap(Int.init) ?? 0

        var captions: [String] = []
        var sources: [String] = []
        for element in elements(named: "dataField", in: xml) {
            guard let caption = attribute("name", of: element) else { continue }
            captions.append(caption)
            // The **source** field, which is the other name Excel answers to: the corpus asks
            // for `"Subs"` against a caption of `"Sum of Subs"`. Empty where the index cannot
            // be resolved, leaving the caption as the only route in rather than inventing one.
            let index = attribute("fld", of: element).flatMap(Int.init)
            sources.append(name(at: index, in: cacheFields) ?? "")
        }

        return PivotTableLayout(
            sheet: sheet,
            range: range,
            firstHeaderRow: firstHeaderRow,
            firstDataRow: firstDataRow,
            firstDataCol: firstDataCol,
            dataFields: captions,
            dataFieldSources: sources,
            rowFields: axis(named: "rowFields", in: xml, cacheFields: cacheFields),
            columnFields: axis(named: "colFields", in: xml, cacheFields: cacheFields),
            pageFields: pageAxis(in: xml, cacheFields: cacheFields),
            pageFieldRowCount: pageRows,
            // **Absent means present.** The file format defaults both to on, so a missing
            // attribute is a rendered total rather than the reverse.
            hasRowGrandTotals: flag("rowGrandTotals", in: xml) ?? true,
            hasColumnGrandTotals: flag("colGrandTotals", in: xml) ?? true)
    }

    // MARK: - The axes

    /// One axis, resolved from indices to names.
    ///
    /// **`-2` is the values pseudo-field**, not index -2 of anything: it marks where the data
    /// field names are rendered. Resolving it through the name list would read off the end.
    /// Any other index the cache cannot name is **dropped rather than invented** — a layout
    /// claiming four row fields whose names match nothing describes a table that does not
    /// exist, and would put the label columns out by one.
    private static func axis(named name: String, in xml: String,
                             cacheFields: [String]) -> [PivotAxisField] {
        guard let body = body(of: name, in: xml) else { return [] }
        var fields: [PivotAxisField] = []
        for element in elements(named: "field", in: body) {
            guard let index = attribute("x", of: element).flatMap(Int.init) else { continue }
            if index == Self.valuesPseudoField {
                fields.append(.dataFieldNames)
                continue
            }
            guard let resolved = self.name(at: index, in: cacheFields) else { continue }
            fields.append(.field(resolved))
        }
        return fields
    }

    /// The page (filter) fields, which are indexed by `fld` rather than `x` and never carry
    /// the pseudo-field — the data field names are not a filter.
    private static func pageAxis(in xml: String, cacheFields: [String]) -> [String] {
        guard let body = body(of: "pageFields", in: xml) else { return [] }
        var fields: [String] = []
        for element in elements(named: "pageField", in: body) {
            guard let index = attribute("fld", of: element).flatMap(Int.init),
                  let resolved = name(at: index, in: cacheFields) else { continue }
            fields.append(resolved)
        }
        return fields
    }

    /// The index the file writes where an axis entry is the data field names rather than a
    /// field of the source data.
    private static let valuesPseudoField = -2

    /// A cache field's name, or `nil` where the index names none.
    private static func name(at index: Int?, in cacheFields: [String]) -> String? {
        guard let index, index >= 0, index < cacheFields.count else { return nil }
        return cacheFields[index]
    }

    /// The text between an element's opening and closing tags.
    private static func body(of name: String, in xml: String) -> String? {
        guard let open = xml.range(of: "<\(name) ") ?? xml.range(of: "<\(name)>") else {
            return nil
        }
        let rest = xml[open.lowerBound...]
        guard let start = rest.range(of: ">"), let end = rest.range(of: "</\(name)>") else {
            return nil
        }
        guard start.upperBound <= end.lowerBound else { return nil }
        return String(rest[start.upperBound..<end.lowerBound])
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
