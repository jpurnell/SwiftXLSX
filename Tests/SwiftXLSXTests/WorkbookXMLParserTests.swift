import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct WorkbookXMLParserTests {

    // MARK: - Helper

    private func xmlData(_ xml: String) -> Data {
        Data(xml.utf8)
    }

    // MARK: - Sheet Tests

    @Test("Single sheet")
    func testSingleSheet() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.count == 1)
        #expect(result.sheets[0].name == "Sheet1")
        #expect(result.sheets[0].sheetId == 1)
        #expect(result.sheets[0].rId == "rId1")
    }

    @Test("Multiple sheets")
    func testMultipleSheets() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Revenue" sheetId="1" r:id="rId1"/>
        <sheet name="Expenses" sheetId="2" r:id="rId2"/>
        <sheet name="Summary" sheetId="3" r:id="rId3"/>
        </sheets>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.count == 3)
        #expect(result.sheets[0].name == "Revenue")
        #expect(result.sheets[0].sheetId == 1)
        #expect(result.sheets[0].rId == "rId1")
        #expect(result.sheets[1].name == "Expenses")
        #expect(result.sheets[1].sheetId == 2)
        #expect(result.sheets[1].rId == "rId2")
        #expect(result.sheets[2].name == "Summary")
        #expect(result.sheets[2].sheetId == 3)
        #expect(result.sheets[2].rId == "rId3")
    }

    @Test("Sheet ordering")
    func testSheetOrdering() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="First" sheetId="5" r:id="rId5"/>
        <sheet name="Second" sheetId="2" r:id="rId2"/>
        <sheet name="Third" sheetId="9" r:id="rId9"/>
        </sheets>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.count == 3)
        // Sheets come back in XML document order regardless of sheetId
        #expect(result.sheets[0].name == "First")
        #expect(result.sheets[1].name == "Second")
        #expect(result.sheets[2].name == "Third")
        // sheetIds are preserved as-is
        #expect(result.sheets[0].sheetId == 5)
        #expect(result.sheets[1].sheetId == 2)
        #expect(result.sheets[2].sheetId == 9)
    }

    @Test("No sheets")
    func testNoSheets() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets/>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.isEmpty)
        #expect(result.definedNames.isEmpty)
    }

    // MARK: - Defined Names Tests

    @Test("Defined names")
    func testDefinedNames() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        <definedNames>
        <definedName name="TaxRate">Sheet1!$B$1</definedName>
        </definedNames>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.definedNames.count == 1)
        #expect(result.definedNames[0].name == "TaxRate")
        #expect(result.definedNames[0].formula == "Sheet1!$B$1")
    }

    @Test("Defined name with local sheet id")
    func testDefinedNameWithLocalSheetId() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        <definedNames>
        <definedName name="LocalRange" localSheetId="0">Sheet1!$A$1:$C$10</definedName>
        </definedNames>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.definedNames.count == 1)
        #expect(result.definedNames[0].name == "LocalRange")
        #expect(result.definedNames[0].formula == "Sheet1!$A$1:$C$10")
        #expect(result.definedNames[0].localSheetId == 0)
    }

    @Test("Defined name without local sheet id")
    func testDefinedNameWithoutLocalSheetId() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        <definedNames>
        <definedName name="GlobalRate">Sheet1!$D$5</definedName>
        </definedNames>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.definedNames.count == 1)
        #expect(result.definedNames[0].name == "GlobalRate")
        #expect(result.definedNames[0].localSheetId == nil)
    }

    @Test("Multiple defined names")
    func testMultipleDefinedNames() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        <definedNames>
        <definedName name="TaxRate">Sheet1!$B$1</definedName>
        <definedName name="PrintArea" localSheetId="0">Sheet1!$A$1:$F$20</definedName>
        <definedName name="Discount">Sheet1!$C$3</definedName>
        </definedNames>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.definedNames.count == 3)
        #expect(result.definedNames[0].name == "TaxRate")
        #expect(result.definedNames[0].formula == "Sheet1!$B$1")
        #expect(result.definedNames[0].localSheetId == nil)
        #expect(result.definedNames[1].name == "PrintArea")
        #expect(result.definedNames[1].formula == "Sheet1!$A$1:$F$20")
        #expect(result.definedNames[1].localSheetId == 0)
        #expect(result.definedNames[2].name == "Discount")
        #expect(result.definedNames[2].formula == "Sheet1!$C$3")
    }

    // MARK: - Special Characters

    @Test("Special characters in sheet name")
    func testSpecialCharactersInSheetName() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Q1 Sales &amp; Revenue" sheetId="1" r:id="rId1"/>
        <sheet name="Year &lt;2025&gt;" sheetId="2" r:id="rId2"/>
        </sheets>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.count == 2)
        #expect(result.sheets[0].name == "Q1 Sales & Revenue")
        #expect(result.sheets[1].name == "Year <2025>")
    }

    // MARK: - Real-World Format

    @Test("Real world format from workbook XML")
    func testRealWorldFormatFromWorkbookXML() throws {
        // This matches the exact format produced by Workbook.workbookXML()
        // (see Sources/SwiftXLSX/Workbook.swift, line ~75)
        // The method concatenates strings without extra whitespace between elements.
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>\
        <sheet name="Income" sheetId="1" r:id="rId1"/>\
        <sheet name="Balance Sheet" sheetId="2" r:id="rId2"/>\
        <sheet name="Cash Flow" sheetId="3" r:id="rId3"/>\
        </sheets></workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        #expect(result.sheets.count == 3)
        #expect(result.sheets[0].name == "Income")
        #expect(result.sheets[0].sheetId == 1)
        #expect(result.sheets[0].rId == "rId1")
        #expect(result.sheets[1].name == "Balance Sheet")
        #expect(result.sheets[1].sheetId == 2)
        #expect(result.sheets[1].rId == "rId2")
        #expect(result.sheets[2].name == "Cash Flow")
        #expect(result.sheets[2].sheetId == 3)
        #expect(result.sheets[2].rId == "rId3")
        // No defined names in the generated format
        #expect(result.definedNames.isEmpty)
    }
}
