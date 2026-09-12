import Foundation
import SwiftExcelCore

/// Information about a single sheet extracted from `xl/workbook.xml`.
struct SheetInfo: Sendable {
    let name: String
    let sheetId: Int
    let rId: String
}

/// A defined name entry from `xl/workbook.xml`.
struct DefinedNameInfo: Sendable {
    let name: String
    let formula: String
    let localSheetId: Int?
}

/// Parses `xl/workbook.xml` to extract sheet metadata and defined names.
///
/// Sheet elements map a human-readable name and sheetId to a relationship ID (`r:id`),
/// which is then resolved via the workbook relationships file to find the actual
/// worksheet XML path. Defined names capture named ranges and formulas.
final class WorkbookXMLParser: NSObject, XMLParserDelegate {
    private var sheets: [SheetInfo] = []
    private var definedNames: [DefinedNameInfo] = []
    private var currentDefinedName: String?
    private var currentLocalSheetId: Int?
    private var currentText = ""
    private var inDefinedName = false

    /// Parses workbook XML data into sheet info and defined names.
    static func parse(data: Data) throws -> (sheets: [SheetInfo], definedNames: [DefinedNameInfo]) {
        let handler = WorkbookXMLParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = handler
        guard parser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: "workbook.xml",
                description: parser.parserError?.localizedDescription ?? "Unknown error"
            )
        }
        return (handler.sheets, handler.definedNames)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "sheet":
            let name = attributeDict["name"] ?? ""
            let sheetId = Int(attributeDict["sheetId"] ?? "0") ?? 0
            // When shouldProcessNamespaces is true, XMLParser strips the namespace
            // prefix from attributes. The "r:id" attribute becomes just "id".
            // We try both keys for robustness.
            let rId = attributeDict["id"] ?? attributeDict["r:id"] ?? ""
            sheets.append(SheetInfo(name: name, sheetId: sheetId, rId: rId))
        case "definedName":
            currentDefinedName = attributeDict["name"]
            currentLocalSheetId = attributeDict["localSheetId"].flatMap { Int($0) }
            currentText = ""
            inDefinedName = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inDefinedName {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "definedName", let name = currentDefinedName {
            definedNames.append(DefinedNameInfo(
                name: name, formula: currentText, localSheetId: currentLocalSheetId))
            inDefinedName = false
            currentDefinedName = nil
            currentLocalSheetId = nil
        }
    }
}
