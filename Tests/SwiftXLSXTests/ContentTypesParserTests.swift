import XCTest
@testable import SwiftXLSX
import Foundation

final class ContentTypesParserTests: XCTestCase {

    // MARK: - Typical Parsing

    func testParseTypicalContentTypes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(ct.defaults.count, 2)
        XCTAssertEqual(ct.defaults["rels"],
                       "application/vnd.openxmlformats-package.relationships+xml")
        XCTAssertEqual(ct.defaults["xml"], "application/xml")
        XCTAssertEqual(ct.overrides.count, 1)
        XCTAssertEqual(ct.overrides["/xl/workbook.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")
    }

    // MARK: - Edge Cases

    func testEmptyTypes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        XCTAssertTrue(ct.defaults.isEmpty)
        XCTAssertTrue(ct.overrides.isEmpty)
    }

    func testDefaultsOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        XCTAssertEqual(ct.defaults.count, 2)
        XCTAssertTrue(ct.overrides.isEmpty)
    }

    func testOverridesOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        XCTAssertTrue(ct.defaults.isEmpty)
        XCTAssertEqual(ct.overrides.count, 2)
    }

    // MARK: - Real-World Round-Trip

    func testParseSwiftXLSXContentTypesOutput() throws {
        // This is the XML that SwiftXLSX's Workbook.contentTypesXML() generates
        // for a workbook with 2 sheets
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))

        // Verify defaults
        XCTAssertEqual(ct.defaults.count, 2)
        XCTAssertEqual(ct.defaults["rels"],
                       "application/vnd.openxmlformats-package.relationships+xml")
        XCTAssertEqual(ct.defaults["xml"], "application/xml")

        // Verify overrides
        XCTAssertEqual(ct.overrides.count, 5)
        XCTAssertEqual(ct.overrides["/xl/workbook.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")
        XCTAssertEqual(ct.overrides["/xl/styles.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml")
        XCTAssertEqual(ct.overrides["/xl/sharedStrings.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml")
        XCTAssertEqual(ct.overrides["/xl/worksheets/sheet1.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml")
        XCTAssertEqual(ct.overrides["/xl/worksheets/sheet2.xml"],
                       "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml")
    }
}
