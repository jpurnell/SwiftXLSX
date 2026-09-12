import XCTest
@testable import SwiftXLSX
import Foundation

final class RelationshipsParserTests: XCTestCase {

    // MARK: - Typical Parsing

    func testParseTypicalRels() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(rels.count, 1)
        XCTAssertEqual(rels[0].id, "rId1")
        XCTAssertEqual(rels[0].type,
                       "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument")
        XCTAssertEqual(rels[0].target, "xl/workbook.xml")
    }

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
        XCTAssertEqual(rels.count, 3)
        XCTAssertEqual(rels[0].target, "worksheets/sheet1.xml")
        XCTAssertEqual(rels[1].target, "styles.xml")
        XCTAssertEqual(rels[2].target, "sharedStrings.xml")
    }

    // MARK: - Edge Cases

    func testEmptyRelationships() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        XCTAssertTrue(rels.isEmpty)
    }

    func testMissingAttributesSkipsRelationship() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com/type"/>
        <Relationship Id="rId2" Type="http://example.com/type" Target="valid.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(rels.count, 1, "Relationship missing Target should be skipped")
        XCTAssertEqual(rels[0].id, "rId2")
    }

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
        XCTAssertEqual(rels.count, 3)
        XCTAssertEqual(rels[0].id, "rId3")
        XCTAssertEqual(rels[1].id, "rId1")
        XCTAssertEqual(rels[2].id, "rId2")
    }

    func testNamespacePrefixedElements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <r:Relationships xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships">
        <r:Relationship Id="rId1" Type="http://example.com/type" Target="target.xml"/>
        </r:Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(rels.count, 1)
        XCTAssertEqual(rels[0].id, "rId1")
    }

    // MARK: - Error Handling

    func testInvalidXMLThrows() {
        let xml = "<<<not valid xml>>>"
        XCTAssertThrowsError(try RelationshipsParser.parse(data: Data(xml.utf8))) { error in
            guard case XLSXReadError.xmlParseError(let part, _) = error else {
                XCTFail("Expected xmlParseError, got \(error)")
                return
            }
            XCTAssertEqual(part, ".rels")
        }
    }

    // MARK: - Real-World Round-Trip

    func testParseSwiftXLSXRelsOutput() throws {
        // This is the XML that SwiftXLSX's Workbook.relsXML() generates
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let rels = try RelationshipsParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(rels.count, 1)
        XCTAssertEqual(rels[0].id, "rId1")
        XCTAssertEqual(rels[0].target, "xl/workbook.xml")
    }

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
        XCTAssertEqual(rels.count, 4)

        // Verify worksheet relationships
        let worksheetRels = rels.filter {
            $0.type.contains("relationships/worksheet")
        }
        XCTAssertEqual(worksheetRels.count, 2)

        // Verify styles relationship
        let stylesRels = rels.filter { $0.type.contains("relationships/styles") }
        XCTAssertEqual(stylesRels.count, 1)
        XCTAssertEqual(stylesRels[0].target, "styles.xml")

        // Verify sharedStrings relationship
        let ssRels = rels.filter { $0.type.contains("relationships/sharedStrings") }
        XCTAssertEqual(ssRels.count, 1)
        XCTAssertEqual(ssRels[0].target, "sharedStrings.xml")
    }
}
