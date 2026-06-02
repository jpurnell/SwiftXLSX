import XCTest
@testable import SwiftXLSX

final class StyleSheetTests: XCTestCase {

    // MARK: - Registration

    func testRegisterGeneralReturnsZero() {
        let sheet = StyleSheet()
        let id = sheet.register(.general)
        XCTAssertEqual(id, 0)
    }

    func testRegisterHeaderReturnsOne() {
        let sheet = StyleSheet()
        let id = sheet.register(.header)
        XCTAssertEqual(id, 1)
    }

    func testDeduplicatesSameStyle() {
        let sheet = StyleSheet()
        let id1 = sheet.register(.header)
        let id2 = sheet.register(.header)
        XCTAssertEqual(id1, id2)
    }

    func testDifferentStylesGetDifferentIds() {
        let sheet = StyleSheet()
        let id1 = sheet.register(.header)
        let id2 = sheet.register(.currency)
        XCTAssertNotEqual(id1, id2)
    }

    func testRegisterMultipleStyles() {
        let sheet = StyleSheet()
        _ = sheet.register(.general)
        _ = sheet.register(.header)
        _ = sheet.register(.currency)
        _ = sheet.register(.percent)
        let id = sheet.register(.date)
        XCTAssertEqual(id, 4)
    }

    // MARK: - XML Output: Fonts

    func testXMLContainsDefaultFont() {
        let sheet = StyleSheet()
        _ = sheet.register(.general)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<name val=\"Calibri\"/>"))
        XCTAssertTrue(xml.contains("<sz val=\"11\"/>"))
    }

    func testXMLContainsBoldFont() {
        let sheet = StyleSheet()
        _ = sheet.register(.header)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<b/>"))
    }

    func testXMLContainsItalicFont() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(italic: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<i/>"))
    }

    func testXMLContainsUnderlineFont() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(underline: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<u/>"))
    }

    func testXMLContainsFontColor() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(color: "FFFF0000"))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<color rgb=\"FFFF0000\"/>"))
    }

    func testXMLContainsCustomFontName() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(name: "SF Mono", size: 14))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<name val=\"SF Mono\"/>"))
        XCTAssertTrue(xml.contains("<sz val=\"14\"/>"))
    }

    // MARK: - XML Output: Fills

    func testXMLContainsRequiredFills() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("patternType=\"none\""))
        XCTAssertTrue(xml.contains("patternType=\"gray125\""))
    }

    func testXMLContainsSolidFill() {
        let sheet = StyleSheet()
        _ = sheet.register(.input)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("patternType=\"solid\""))
        XCTAssertTrue(xml.contains("<fgColor rgb=\"FFFFFF00\"/>"))
    }

    // MARK: - XML Output: Borders

    func testXMLContainsEmptyBorder() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<border>"))
        XCTAssertTrue(xml.contains("<left/>"))
    }

    func testXMLContainsThinBorder() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .thin))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("style=\"thin\""))
        XCTAssertTrue(xml.contains("<color rgb=\"FF000000\"/>"))
    }

    func testXMLContainsBottomBorderOnly() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .bottom))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<bottom style=\"thin\">"))
        XCTAssertTrue(xml.contains("<top/>"))
        XCTAssertTrue(xml.contains("<left/>"))
        XCTAssertTrue(xml.contains("<right/>"))
    }

    // MARK: - XML Output: Number Formats

    func testXMLContainsBuiltinNumberFormat() {
        let sheet = StyleSheet()
        _ = sheet.register(.currency)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("numFmtId=\"4\""))
        XCTAssertFalse(xml.contains("<numFmts"))
    }

    func testXMLContainsCustomNumberFormat() {
        let sheet = StyleSheet()
        let style = CellStyle(numberFormat: NumberFormat(formatString: "0.000"))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<numFmts count=\"1\">"))
        XCTAssertTrue(xml.contains("numFmtId=\"164\""))
        XCTAssertTrue(xml.contains("formatCode=\"0.000\""))
    }

    func testCustomNumberFormatsGetSequentialIds() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(numberFormat: NumberFormat(formatString: "0.000")))
        _ = sheet.register(CellStyle(numberFormat: NumberFormat(formatString: "#,##0.0")))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<numFmts count=\"2\">"))
        XCTAssertTrue(xml.contains("numFmtId=\"164\""))
        XCTAssertTrue(xml.contains("numFmtId=\"165\""))
    }

    // MARK: - XML Output: Alignment

    func testXMLContainsAlignment() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(horizontal: .center, vertical: .bottom))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("applyAlignment=\"1\""))
        XCTAssertTrue(xml.contains("horizontal=\"center\""))
        XCTAssertTrue(xml.contains("vertical=\"bottom\""))
    }

    func testXMLContainsWrapText() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(wrapText: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("wrapText=\"1\""))
    }

    func testXMLContainsIndent() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(indent: 2))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("indent=\"2\""))
    }

    // MARK: - XML Output: Apply Attributes

    func testApplyFontAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.header)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("applyFont=\"1\""))
    }

    func testApplyFillAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.input)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("applyFill=\"1\""))
    }

    func testApplyBorderAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .thin))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("applyBorder=\"1\""))
    }

    func testApplyNumberFormatAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.currency)
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("applyNumberFormat=\"1\""))
    }

    // MARK: - XML Structure

    func testXMLHasStyleSheetRoot() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<styleSheet"))
        XCTAssertTrue(xml.contains("</styleSheet>"))
    }

    func testXMLHasCellStyleXfs() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<cellStyleXfs count=\"1\">"))
    }

    // MARK: - Deduplication

    func testFontDeduplication() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(font: Font(bold: true)))
        _ = sheet.register(CellStyle(font: Font(bold: true), numberFormat: .currency))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<fonts count=\"2\">"))
    }

    func testFillDeduplication() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(fill: .solid("FFFFFF00")))
        _ = sheet.register(CellStyle(font: Font(bold: true), fill: .solid("FFFFFF00")))
        let xml = sheet.toXML()
        XCTAssertTrue(xml.contains("<fills count=\"3\">"))
    }
}
