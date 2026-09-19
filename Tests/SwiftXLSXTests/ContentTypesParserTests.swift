import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct ContentTypesParserTests {

    // MARK: - Typical Parsing

    @Test("Parse typical content types")
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
        #expect(ct.defaults.count == 2)
        #expect(ct.defaults["rels"] == "application/vnd.openxmlformats-package.relationships+xml")
        #expect(ct.defaults["xml"] == "application/xml")
        #expect(ct.overrides.count == 1)
        #expect(ct.overrides["/xl/workbook.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")
    }

    // MARK: - Edge Cases

    @Test("Empty types")
    func testEmptyTypes() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        #expect(ct.defaults.isEmpty)
        #expect(ct.overrides.isEmpty)
    }

    @Test("Defaults only")
    func testDefaultsOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        #expect(ct.defaults.count == 2)
        #expect(ct.overrides.isEmpty)
    }

    @Test("Overrides only")
    func testOverridesOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
        let ct = try ContentTypesParser.parse(data: Data(xml.utf8))
        #expect(ct.defaults.isEmpty)
        #expect(ct.overrides.count == 2)
    }

    // MARK: - Real-World Round-Trip

    @Test("Parse swift XLSX content types output")
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
        #expect(ct.defaults.count == 2)
        #expect(ct.defaults["rels"] == "application/vnd.openxmlformats-package.relationships+xml")
        #expect(ct.defaults["xml"] == "application/xml")

        // Verify overrides
        #expect(ct.overrides.count == 5)
        #expect(ct.overrides["/xl/workbook.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml")
        #expect(ct.overrides["/xl/styles.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml")
        #expect(ct.overrides["/xl/sharedStrings.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml")
        #expect(ct.overrides["/xl/worksheets/sheet1.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml")
        #expect(ct.overrides["/xl/worksheets/sheet2.xml"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml")
    }
}
