import Foundation
import SwiftZIP
import SwiftExcelCore

/// Orchestrates reading an `.xlsx` file by delegating to individual OOXML parsers.
///
/// Reads the ZIP archive, resolves relationships between parts, and populates
/// a ``Workbook`` with cell values, formulas, styles, and layout features.
enum WorkbookReader {

    /// Reads an `.xlsx` file from data and returns a populated ``Workbook``.
    ///
    /// - Parameter data: The raw `.xlsx` file bytes.
    /// - Returns: A fully-populated ``Workbook``.
    /// - Throws: ``XLSXReadError`` if the archive is invalid or any part fails to parse.
    static func read(from data: Data) throws -> Workbook {
        // 1. Read ZIP archive
        let entries: [ZIPEntry]
        do {
            entries = try ZIPReader.read(from: data)
        } catch {
            throw XLSXReadError.zipError(error.localizedDescription)
        }

        // Build lookup: path -> data
        var entryMap: [String: Data] = [:]
        for entry in entries {
            entryMap[entry.path] = entry.data
        }

        // 2. Parse _rels/.rels to find the workbook path
        let topRels: [Relationship]
        if let relsData = entryMap["_rels/.rels"] {
            topRels = try RelationshipsParser.parse(data: relsData)
        } else {
            topRels = []
        }
        // Match the relationship type exactly, not by substring. Several OOXML
        // relationship types live under the `.../officeDocument/2006/relationships/`
        // namespace, so a `contains("officeDocument")` test also matches
        // `.../relationships/extended-properties` — which Excel writes *first*.
        // That selects `docProps/app.xml`, which is well-formed XML containing no
        // `<sheet>` elements, so the workbook parses to zero sheets and the read
        // succeeds silently. Only the main-document type ends in `/officeDocument`.
        let workbookTarget = topRels.first {
            $0.type.hasSuffix("/officeDocument")
        }?.target ?? "xl/workbook.xml"
        let workbookPath = resolvePart(workbookTarget, relativeTo: "")

        // 3. Parse xl/_rels/workbook.xml.rels to map rIds to sheet paths
        let wbRelsPath: String
        if workbookPath.contains("/") {
            let components = workbookPath.components(separatedBy: "/")
            let dir = components.dropLast().joined(separator: "/")
            let filename = components.last ?? "workbook.xml"
            wbRelsPath = "\(dir)/_rels/\(filename).rels"
        } else {
            wbRelsPath = "_rels/\(workbookPath).rels"
        }

        let wbRels: [Relationship]
        if let wbRelsData = entryMap[wbRelsPath] {
            wbRels = try RelationshipsParser.parse(data: wbRelsData)
        } else {
            wbRels = []
        }

        // 4. Parse xl/workbook.xml for sheet info
        guard let wbData = entryMap[workbookPath] else {
            throw XLSXReadError.missingPart(workbookPath)
        }
        let (sheetInfos, definedNameInfos) = try WorkbookXMLParser.parse(data: wbData)

        // 5. Parse xl/sharedStrings.xml (optional -- might not exist if no text cells)
        let sharedStrings: [String]
        let phonetics: [String?]
        if let ssData = entryMap["xl/sharedStrings.xml"] {
            let entries = try SharedStringsParser.parseEntries(data: ssData)
            sharedStrings = entries.map(\.text)
            phonetics = entries.map(\.phonetic)
        } else {
            sharedStrings = []
            phonetics = []
        }

        // 6. Parse xl/styles.xml (optional -- might not exist)
        let styles: ParsedStyleSheet
        if let stylesData = entryMap["xl/styles.xml"] {
            styles = try StyleSheetParser.parse(data: stylesData)
        } else {
            styles = ParsedStyleSheet()
        }

        // 7. For each sheet, resolve its file path and parse
        let workbook = Workbook()

        // Cache definitions are **shared**: 50 pivots in one corpus workbook are backed by 7
        // definitions, and one of them answers for 29 of the tables. Read each part once.
        var cacheFieldsByPart: [String: [String]] = [:]
        for info in definedNameInfos {
            guard let named = DefinedNameResolver.namedRange(from: info, sheets: sheetInfos)
            else { continue }
            workbook.adopt(named)
        }
        for info in sheetInfos {
            let sheet = workbook.addSheet(name: info.name)

            // Find the relationship to get the target path
            let rel = wbRels.first { $0.id == info.rId }
            let relTarget = rel?.target ?? "worksheets/sheet\(info.sheetId).xml"

            // Resolve the target against the workbook's own directory
            let wbDir = workbookPath.contains("/")
                ? workbookPath.components(separatedBy: "/").dropLast().joined(separator: "/")
                : ""
            let sheetPath = resolvePart(relTarget, relativeTo: wbDir)

            guard let sheetData = entryMap[sheetPath] else {
                continue  // Skip sheets with missing data rather than failing
            }

            try WorksheetParser.parse(data: sheetData, into: sheet,
                                       sharedStrings: sharedStrings, styles: styles,
                                       phonetics: phonetics)

            // A sheet's own relationships say which pivot tables it renders. Read for
            // `GETPIVOTDATA`, which looks a value up in a table already on the sheet rather
            // than recomputing one — so the definitions are wanted and `xl/pivotCache/` is
            // not. A sheet with no pivots costs one dictionary miss.
            let sheetDir = sheetPath.contains("/")
                ? sheetPath.components(separatedBy: "/").dropLast().joined(separator: "/")
                : ""
            let sheetFile = sheetPath.components(separatedBy: "/").last ?? sheetPath
            let sheetRelsPath = sheetDir.isEmpty
                ? "_rels/\(sheetFile).rels"
                : "\(sheetDir)/_rels/\(sheetFile).rels"
            guard let sheetRelsData = entryMap[sheetRelsPath] else { continue }
            let sheetRels = RelationshipsParser.declaredRelationships(data: sheetRelsData)
            for relationship in sheetRels where relationship.type.hasSuffix("/pivotTable") {
                let partPath = resolvePart(relationship.target, relativeTo: sheetDir)
                guard let partData = entryMap[partPath] else { continue }
                let fields = cacheFieldNames(forPivotAt: partPath, in: entryMap,
                                             remembering: &cacheFieldsByPart)
                guard let layout = PivotTableParser.parse(data: partData, onSheet: info.name,
                                                          cacheFields: fields) else { continue }
                workbook.adopt(layout)
            }
        }

        return workbook
    }

    /// The field names backing one pivot table, read from its cache **definition**.
    ///
    /// **Field identity in a pivot table definition is positional** — `<field x="4"/>`,
    /// `fld="11"` — and only `pivotCacheDefinition*.xml` carries the names those index into.
    /// So a pivot's own relationships are followed one step further, to the definition and no
    /// further: `pivotCacheRecords*.xml` is never opened, nothing is aggregated, and the
    /// values still come off the worksheet where Excel rendered them.
    ///
    /// Definitions are shared between tables — 50 pivots in the corpus workbook are backed by
    /// 7 definitions — so each part is read once and remembered.
    ///
    /// - Parameters:
    ///   - partPath: The ZIP path of the `pivotTableN.xml` part.
    ///   - entryMap: Every part in the package, by path.
    ///   - seen: Field names already read, by definition path. Updated in place.
    /// - Returns: The names in cache order, or `[]` where no definition can be reached. Empty
    ///   leaves the axes unresolved and the two-argument form still working off the captions.
    private static func cacheFieldNames(forPivotAt partPath: String,
                                        in entryMap: [String: Data],
                                        remembering seen: inout [String: [String]]) -> [String] {
        let dir = partPath.contains("/")
            ? partPath.components(separatedBy: "/").dropLast().joined(separator: "/")
            : ""
        let file = partPath.components(separatedBy: "/").last ?? partPath
        let relsPath = dir.isEmpty ? "_rels/\(file).rels" : "\(dir)/_rels/\(file).rels"
        guard let relsData = entryMap[relsPath] else { return [] }
        let rels = RelationshipsParser.declaredRelationships(data: relsData)
        guard let definition = rels.first(where: {
            $0.type.hasSuffix("/pivotCacheDefinition")
        }) else {
            return []
        }
        let definitionPath = resolvePart(definition.target, relativeTo: dir)
        if let already = seen[definitionPath] { return already }
        guard let definitionData = entryMap[definitionPath] else { return [] }
        let names = PivotCacheParser.fieldNames(data: definitionData)
        seen[definitionPath] = names
        return names
    }

    /// Resolves an OOXML relationship target to a ZIP entry path.
    ///
    /// Targets come in three legal shapes and only one of them is a plain
    /// concatenation:
    ///
    /// - **Package-absolute** (`/xl/workbook.xml`) — relative to the package root,
    ///   so the base is discarded rather than prepended.
    /// - **Relative** (`worksheets/sheet1.xml`) — joined onto the base.
    /// - **Relative with traversal** (`../xl/workbook.xml`) — joined, then the
    ///   `.` and `..` segments are collapsed.
    ///
    /// ZIP entry paths carry no leading slash, so the result never has one.
    ///
    /// - Parameters:
    ///   - target: The relationship's `Target` attribute.
    ///   - base: The directory the target is relative to, without a trailing
    ///     slash. Empty means the package root.
    /// - Returns: A normalized path suitable for looking up a ZIP entry.
    static func resolvePart(_ target: String, relativeTo base: String) -> String {
        let joined: String
        if target.hasPrefix("/") {
            joined = String(target.dropFirst())
        } else if base.isEmpty {
            joined = target
        } else {
            joined = "\(base)/\(target)"
        }

        guard joined.contains("./") || joined.hasSuffix("/.") || joined.hasSuffix("/..") else {
            return joined
        }

        var resolved: [String] = []
        for segment in joined.components(separatedBy: "/") {
            switch segment {
            case "", ".":
                continue
            case "..":
                if !resolved.isEmpty { resolved.removeLast() }
            default:
                resolved.append(segment)
            }
        }
        return resolved.joined(separator: "/")
    }
}
