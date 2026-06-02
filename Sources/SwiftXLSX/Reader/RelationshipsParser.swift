import Foundation

struct Relationship: Sendable {
    let id: String
    let type: String
    let target: String
}

final class RelationshipsParser: NSObject, XMLParserDelegate {
    private var relationships: [Relationship] = []

    static func parse(data: Data) throws -> [Relationship] {
        let parser = RelationshipsParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = true
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            throw XLSXReadError.xmlParseError(
                part: ".rels",
                description: xmlParser.parserError?.localizedDescription ?? "Unknown error"
            )
        }
        return parser.relationships
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "Relationship" {
            if let id = attributeDict["Id"],
               let type = attributeDict["Type"],
               let target = attributeDict["Target"] {
                relationships.append(Relationship(id: id, type: type, target: target))
            }
        }
    }
}
