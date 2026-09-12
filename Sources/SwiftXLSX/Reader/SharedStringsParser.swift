import Foundation
import SwiftExcelCore

/// Parses the shared strings table (`xl/sharedStrings.xml`) from an XLSX archive.
///
/// The shared strings table stores deduplicated text strings referenced by cells
/// via zero-based index. This parser handles both simple `<si><t>` entries and
/// rich-text `<si><r><t>` entries (concatenating all runs, ignoring formatting).
///
/// **Phonetic runs are excluded.** A Japanese workbook stores the reading of a name in an
/// `<rPh>` sibling of the text runs — the cell says 山田 and `<rPh>` says ヤマダ, which is how
/// to pronounce it rather than part of what it says. `<rPh>` contains its own `<t>`, so a
/// parser that accumulates every `<t>` inside `<si>` returns 山田ヤマダ. That is a corrupted
/// value rather than a missing feature: it is wrong for every function that reads the cell,
/// and invisible to a reader who cannot tell the two scripts apart.
final class SharedStringsParser: NSObject, XMLParserDelegate {
    /// One shared string: what the cell says, and how to say it.
    struct Entry: Equatable {
        /// The cell's text — the runs, with phonetic annotation excluded.
        let text: String
        /// The reading from `<rPh>`, or `nil` when the entry carries none.
        let phonetic: String?
    }

    private var entries: [Entry] = []
    private var currentText = ""
    private var currentPhonetic = ""
    private var inSI = false
    private var inT = false
    private var inRPh = false

    /// Parses shared strings XML data into an ordered array of strings.
    ///
    /// The values only. Use ``parseEntries(data:)`` where the readings are wanted too.
    static func parse(data: Data) throws -> [String] {
        try parseEntries(data: data).map(\.text)
    }

    /// Parses shared strings XML into values paired with their phonetic readings.
    static func parseEntries(data: Data) throws -> [Entry] {
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
        return handler.entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "si":
            inSI = true
            currentText = ""
            currentPhonetic = ""
            inRPh = false
        case "rPh":
            inRPh = true
        case "t" where inSI:
            inT = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inT else { return }
        // The same `<t>` element means different things depending on its parent, which is
        // the whole of this bug: inside `<rPh>` it is a reading, elsewhere it is content.
        if inRPh {
            currentPhonetic += string
        } else {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "t":
            inT = false
        case "rPh":
            inRPh = false
        case "si":
            entries.append(Entry(text: currentText,
                                 phonetic: currentPhonetic.isEmpty ? nil : currentPhonetic))
            currentText = ""
            currentPhonetic = ""
            inSI = false
            inRPh = false
        default:
            break
        }
    }
}
