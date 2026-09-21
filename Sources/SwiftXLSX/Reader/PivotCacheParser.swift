import Foundation

/// Reads the **field names** out of a pivot cache definition, and nothing else.
///
/// ## Why the cache is opened at all
///
/// It is not, for the two-argument `GETPIVOTDATA` — see ``PivotTableParser``, whose note on
/// that still holds. Field/item pairs are what change it, because **field identity in a pivot
/// table definition is positional**:
///
/// ```xml
/// <rowFields count="4"><field x="4"/><field x="0"/><field x="7"/><field x="16"/></rowFields>
/// <colFields count="1"><field x="1"/></colFields>
/// <pageFields count="2"><pageField fld="9"/><pageField fld="6"/></pageFields>
/// <dataFields count="1"><dataField name="Sum of Subs" fld="11"/></dataFields>
/// ```
///
/// Indices, every one of them. A formula asking for `"Scenario"` cannot be answered from that
/// part alone, and only `pivotCacheDefinition*.xml` carries `<cacheField name="…"/>`.
///
/// ## Definitions, never records
///
/// The distinction keeps the original insight intact rather than overturning it:
///
/// | part | in `Dot Com YTD Performance Report 6 20.xlsx` | read |
/// |---|---|---|
/// | `pivotCacheDefinition*.xml` | 7 parts, 0.8–12 KB | the `<cacheField name>` list |
/// | `pivotCacheRecords*.xml` | 2 parts, 32 KB | **never** |
///
/// Nothing is aggregated and no record is ever touched. A cache definition declaring
/// `recordCount="12300"` contributes eighteen strings here and not one row.
enum PivotCacheParser {

    /// The cache's field names, in the order it lists them — which is the order the indices
    /// in a pivot table definition count in.
    ///
    /// Names are stored **exactly as the cache spells them**, including case and any
    /// surrounding space. The corpus forces this: one field is spelled `week ending` while
    /// every formula that reads it writes `"Week Ending"`. Matching is case-insensitive where
    /// it happens; normalising here would throw away the workbook's own spelling.
    ///
    /// - Parameter data: The bytes of an `xl/pivotCache/pivotCacheDefinitionN.xml` part.
    /// - Returns: The field names in order, or an empty array where the part cannot be read.
    ///   Empty leaves every index unresolved and every pair refused, which is honest.
    static func fieldNames(data: Data) -> [String] {
        guard let xml = String(data: data, encoding: .utf8) else { return [] }

        // **Only `cacheField`.** A `<cacheHierarchy name="…"/>` lives in the same part, and
        // counting it would shift every index by one — the quietest possible way to start
        // answering from the wrong column.
        var names: [String] = []
        var remaining = Substring(xml)
        while let open = remaining.range(of: "<cacheField ") {
            let rest = remaining[open.upperBound...]
            guard let close = rest.range(of: ">") else { break }
            let element = rest[rest.startIndex..<close.lowerBound]
            if let name = attribute("name", of: element) {
                names.append(name)
            }
            remaining = rest[close.upperBound...]
        }
        return names
    }

    /// One attribute's value out of an element's text.
    private static func attribute(_ name: String, of element: Substring) -> String? {
        guard let start = element.range(of: "\(name)=\"") else { return nil }
        let rest = element[start.upperBound...]
        guard let end = rest.range(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<end.lowerBound])
    }
}
