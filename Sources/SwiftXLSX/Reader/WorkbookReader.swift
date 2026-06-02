import Foundation
import SwiftZIP

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
        let workbookPath = topRels.first {
            $0.type.contains("officeDocument")
        }?.target ?? "xl/workbook.xml"

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
        let (sheetInfos, _) = try WorkbookXMLParser.parse(data: wbData)

        // 5. Parse xl/sharedStrings.xml (optional -- might not exist if no text cells)
        let sharedStrings: [String]
        if let ssData = entryMap["xl/sharedStrings.xml"] {
            sharedStrings = try SharedStringsParser.parse(data: ssData)
        } else {
            sharedStrings = []
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
        for info in sheetInfos {
            let sheet = workbook.addSheet(name: info.name)

            // Find the relationship to get the target path
            let rel = wbRels.first { $0.id == info.rId }
            let relTarget = rel?.target ?? "worksheets/sheet\(info.sheetId).xml"

            // Resolve relative path against workbook directory
            let wbDir = workbookPath.contains("/")
                ? workbookPath.components(separatedBy: "/").dropLast().joined(separator: "/")
                : ""
            let sheetPath = wbDir.isEmpty ? relTarget : "\(wbDir)/\(relTarget)"

            guard let sheetData = entryMap[sheetPath] else {
                continue  // Skip sheets with missing data rather than failing
            }

            try WorksheetParser.parse(data: sheetData, into: sheet,
                                       sharedStrings: sharedStrings, styles: styles)
        }

        return workbook
    }
}
