import Foundation

/// Parses the shared strings table (`xl/sharedStrings.xml`) from an XLSX archive.
///
/// The shared strings table stores deduplicated text strings referenced by cells
/// via zero-based index. This parser handles both simple `<si><t>` entries and
/// rich-text `<si><r><t>` entries (concatenating all runs, ignoring formatting).
final class SharedStringsParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentText = ""
    private var inSI = false
    private var inT = false

    /// Parses shared strings XML data into an ordered array of strings.
    static func parse(data: Data) throws -> [String] {
        guard !data.isEmpty else { return [] }
        let handler = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = handler
        guard parser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: "sharedStrings.xml",
                description: parser.parserError?.localizedDescription ?? "Unknown error"
            )
        }
        return handler.strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "si":
            inSI = true
            currentText = ""
        case "t" where inSI:
            inT = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "t":
            inT = false
        case "si":
            strings.append(currentText)
            currentText = ""
            inSI = false
        default:
            break
        }
    }
}
