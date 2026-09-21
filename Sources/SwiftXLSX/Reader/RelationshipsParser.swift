import Foundation
import SwiftExcelCore

struct Relationship: Sendable {
    let id: String
    let type: String
    let target: String
}

final class RelationshipsParser: NSObject, XMLParserDelegate {
    private var relationships: [Relationship] = []

    static func parse(data: Data) throws -> [Relationship] {
        switch attempt(data: data) {
        case .success(let relationships): return relationships
        case .failure(let error): throw error
        }
    }

    /// The relationships a part declares, where a part that cannot be read declares none.
    ///
    /// **This is not `try?` with a nicer name**, and the difference is the question being
    /// asked. The callers — the pivot tables a sheet renders, and the cache definition behind
    /// a pivot — are asking something *optional* of a package: does this part point at
    /// anything? A `.rels` part that is absent and one that is malformed are the same answer
    /// to that question, which is "nothing to follow", and both leave the workbook readable.
    ///
    /// It is deliberately not used where a relationship is load-bearing. The workbook's own
    /// `.rels`, which says where `workbook.xml` lives, still throws through ``parse(data:)``:
    /// a package unreadable there has no sheets, and reporting that as an empty workbook would
    /// be a lie about the file.
    ///
    /// - Parameter data: The bytes of a `.rels` part.
    /// - Returns: The relationships, or `[]` where the part is not readable XML.
    static func declaredRelationships(data: Data) -> [Relationship] {
        switch attempt(data: data) {
        case .success(let relationships): return relationships
        case .failure: return []
        }
    }

    /// Parses a `.rels` part, reporting failure as a value rather than as a thrown error.
    ///
    /// Both entry points read the same bytes the same way and differ only in what they do
    /// when it will not parse, so the failure is produced once and each caller decides.
    private static func attempt(data: Data) -> Result<[Relationship], XLSXReadError> {
        let parser = RelationshipsParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.shouldProcessNamespaces = true
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            return .failure(.xmlParseError(
                part: ".rels",
                description: xmlParser.parserError?.localizedDescription ?? "Unknown error"))
        }
        return .success(parser.relationships)
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
