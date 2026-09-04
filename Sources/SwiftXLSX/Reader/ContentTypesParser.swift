import Foundation
import SwiftExcelCore

struct ContentTypes: Sendable {
    var defaults: [String: String]     // extension -> content type
    var overrides: [String: String]    // partName -> content type
}

final class ContentTypesParser: NSObject, XMLParserDelegate {
    private var defaults: [String: String] = [:]
    private var overrides: [String: String] = [:]

    // LIVE: public API for consumers parsing OOXML content types
    static func parse(data: Data) throws -> ContentTypes {
        let parser = ContentTypesParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = true
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: "[Content_Types].xml",
                description: xmlParser.parserError?.localizedDescription ?? "Unknown error"
            )
        }
        return ContentTypes(defaults: parser.defaults, overrides: parser.overrides)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "Default":
            if let ext = attributeDict["Extension"],
               let contentType = attributeDict["ContentType"] {
                defaults[ext] = contentType
            }
        case "Override":
            if let partName = attributeDict["PartName"],
               let contentType = attributeDict["ContentType"] {
                overrides[partName] = contentType
            }
        default:
            break
        }
    }
}
