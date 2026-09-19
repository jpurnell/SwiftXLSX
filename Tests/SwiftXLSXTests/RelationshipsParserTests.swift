import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct RelationshipsParserTests {

    // MARK: - Typical Parsing

    @Test("Parse typical rels")
    func testParseTypicalRels() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 1)
        #expect(rels[0].id == "rId1")
        #expect(rels[0].type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument")
        #expect(rels[0].target == "xl/workbook.xml")
    }

    @Test("Parse multiple relationships")
    func testParseMultipleRelationships() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 3)
        #expect(rels[0].target == "worksheets/sheet1.xml")
        #expect(rels[1].target == "styles.xml")
        #expect(rels[2].target == "sharedStrings.xml")
    }

    // MARK: - Edge Cases

    @Test("Empty relationships")
    func testEmptyRelationships() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.isEmpty)
    }

    @Test("Missing attributes skips relationship")
    func testMissingAttributesSkipsRelationship() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com/type"/>
        <Relationship Id="rId2" Type="http://example.com/type" Target="valid.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 1, "Relationship missing Target should be skipped")
        #expect(rels[0].id == "rId2")
    }

    @Test("Ordering preserved")
    func testOrderingPreserved() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId3" Type="http://example.com/c" Target="c.xml"/>
        <Relationship Id="rId1" Type="http://example.com/a" Target="a.xml"/>
        <Relationship Id="rId2" Type="http://example.com/b" Target="b.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 3)
        #expect(rels[0].id == "rId3")
        #expect(rels[1].id == "rId1")
        #expect(rels[2].id == "rId2")
    }

    @Test("Namespace prefixed elements")
    func testNamespacePrefixedElements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <r:Relationships xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships">
        <r:Relationship Id="rId1" Type="http://example.com/type" Target="target.xml"/>
        </r:Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 1)
        #expect(rels[0].id == "rId1")
    }

    // MARK: - Error Handling

    @Test("Invalid XML throws")
    func testInvalidXMLThrows() throws {
        let xml = "<<<not valid xml>>>"
        let error = try #require(#expect(throws: (any Error).self) {
            try RelationshipsParser.parse(data: Data(xml.utf8))
        })
        guard case XLSXReadError.xmlParseError(let part, _) = error else {
            Issue.record("Expected xmlParseError, got \(error)")
            return
        }
        #expect(part == ".rels")
    }

    // MARK: - Real-World Round-Trip

    @Test("Parse swift XLSX rels output")
    func testParseSwiftXLSXRelsOutput() throws {
        // This is the XML that SwiftXLSX's Workbook.relsXML() generates
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 1)
        #expect(rels[0].id == "rId1")
        #expect(rels[0].target == "xl/workbook.xml")
    }

    @Test("Parse swift XLSX workbook rels output")
    func testParseSwiftXLSXWorkbookRelsOutput() throws {
        // This is the XML that SwiftXLSX's Workbook.workbookRelsXML() generates
        // for a workbook with 2 sheets
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        #expect(rels.count == 4)

        // Verify worksheet relationships
        let worksheetRels = rels.filter {
            $0.type.contains("relationships/worksheet")
        }
        #expect(worksheetRels.count == 2)

        // Verify styles relationship
        let stylesRels = rels.filter { $0.type.contains("relationships/styles") }
        #expect(stylesRels.count == 1)
        #expect(stylesRels[0].target == "styles.xml")

        // Verify sharedStrings relationship
        let ssRels = rels.filter { $0.type.contains("relationships/sharedStrings") }
        #expect(ssRels.count == 1)
        #expect(ssRels[0].target == "sharedStrings.xml")
    }
}
