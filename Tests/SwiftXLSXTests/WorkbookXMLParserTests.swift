import XCTest
@testable import SwiftXLSX

final class WorkbookXMLParserTests: XCTestCase {

    // MARK: - Helper

    private func xmlData(_ xml: String) -> Data {
        Data(xml.utf8)
    }

    // MARK: - Sheet Tests

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
        XCTAssertEqual(result.sheets.count, 1)
        XCTAssertEqual(result.sheets[0].name, "Sheet1")
        XCTAssertEqual(result.sheets[0].sheetId, 1)
        XCTAssertEqual(result.sheets[0].rId, "rId1")
    }

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
        XCTAssertEqual(result.sheets.count, 3)
        XCTAssertEqual(result.sheets[0].name, "Revenue")
        XCTAssertEqual(result.sheets[0].sheetId, 1)
        XCTAssertEqual(result.sheets[0].rId, "rId1")
        XCTAssertEqual(result.sheets[1].name, "Expenses")
        XCTAssertEqual(result.sheets[1].sheetId, 2)
        XCTAssertEqual(result.sheets[1].rId, "rId2")
        XCTAssertEqual(result.sheets[2].name, "Summary")
        XCTAssertEqual(result.sheets[2].sheetId, 3)
        XCTAssertEqual(result.sheets[2].rId, "rId3")
    }

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
        XCTAssertEqual(result.sheets.count, 3)
        // Sheets come back in XML document order regardless of sheetId
        XCTAssertEqual(result.sheets[0].name, "First")
        XCTAssertEqual(result.sheets[1].name, "Second")
        XCTAssertEqual(result.sheets[2].name, "Third")
        // sheetIds are preserved as-is
        XCTAssertEqual(result.sheets[0].sheetId, 5)
        XCTAssertEqual(result.sheets[1].sheetId, 2)
        XCTAssertEqual(result.sheets[2].sheetId, 9)
    }

    func testNoSheets() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets/>
        </workbook>
        """
        let result = try WorkbookXMLParser.parse(data: xmlData(xml))
        XCTAssertTrue(result.sheets.isEmpty)
        XCTAssertTrue(result.definedNames.isEmpty)
    }

    // MARK: - Defined Names Tests

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
        XCTAssertEqual(result.definedNames.count, 1)
        XCTAssertEqual(result.definedNames[0].name, "TaxRate")
        XCTAssertEqual(result.definedNames[0].formula, "Sheet1!$B$1")
    }

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
        XCTAssertEqual(result.definedNames.count, 1)
        XCTAssertEqual(result.definedNames[0].name, "LocalRange")
        XCTAssertEqual(result.definedNames[0].formula, "Sheet1!$A$1:$C$10")
        XCTAssertEqual(result.definedNames[0].localSheetId, 0)
    }

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
        XCTAssertEqual(result.definedNames.count, 1)
        XCTAssertEqual(result.definedNames[0].name, "GlobalRate")
        XCTAssertNil(result.definedNames[0].localSheetId)
    }

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
        XCTAssertEqual(result.definedNames.count, 3)
        XCTAssertEqual(result.definedNames[0].name, "TaxRate")
        XCTAssertEqual(result.definedNames[0].formula, "Sheet1!$B$1")
        XCTAssertNil(result.definedNames[0].localSheetId)
        XCTAssertEqual(result.definedNames[1].name, "PrintArea")
        XCTAssertEqual(result.definedNames[1].formula, "Sheet1!$A$1:$F$20")
        XCTAssertEqual(result.definedNames[1].localSheetId, 0)
        XCTAssertEqual(result.definedNames[2].name, "Discount")
        XCTAssertEqual(result.definedNames[2].formula, "Sheet1!$C$3")
    }

    // MARK: - Special Characters

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
        XCTAssertEqual(result.sheets.count, 2)
        XCTAssertEqual(result.sheets[0].name, "Q1 Sales & Revenue")
        XCTAssertEqual(result.sheets[1].name, "Year <2025>")
    }

    // MARK: - Real-World Format

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
        XCTAssertEqual(result.sheets.count, 3)
        XCTAssertEqual(result.sheets[0].name, "Income")
        XCTAssertEqual(result.sheets[0].sheetId, 1)
        XCTAssertEqual(result.sheets[0].rId, "rId1")
        XCTAssertEqual(result.sheets[1].name, "Balance Sheet")
        XCTAssertEqual(result.sheets[1].sheetId, 2)
        XCTAssertEqual(result.sheets[1].rId, "rId2")
        XCTAssertEqual(result.sheets[2].name, "Cash Flow")
        XCTAssertEqual(result.sheets[2].sheetId, 3)
        XCTAssertEqual(result.sheets[2].rId, "rId3")
        // No defined names in the generated format
        XCTAssertTrue(result.definedNames.isEmpty)
    }
}
