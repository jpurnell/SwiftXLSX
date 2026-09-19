import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct StyleSheetTests {

    // MARK: - Registration

    @Test("Register general returns zero")
    func testRegisterGeneralReturnsZero() {
        let sheet = StyleSheet()
        let id = sheet.register(.general)
        #expect(id == 0)
    }

    @Test("Register header returns one")
    func testRegisterHeaderReturnsOne() {
        let sheet = StyleSheet()
        let id = sheet.register(.header)
        #expect(id == 1)
    }

    @Test("Deduplicates same style")
    func testDeduplicatesSameStyle() {
        let sheet = StyleSheet()
        let id1 = sheet.register(.header)
        let id2 = sheet.register(.header)
        #expect(id1 == id2)
    }

    @Test("Different styles get different ids")
    func testDifferentStylesGetDifferentIds() {
        let sheet = StyleSheet()
        let id1 = sheet.register(.header)
        let id2 = sheet.register(.currency)
        #expect(id1 != id2)
    }

    @Test("Register multiple styles")
    func testRegisterMultipleStyles() {
        let sheet = StyleSheet()
        _ = sheet.register(.general)
        _ = sheet.register(.header)
        _ = sheet.register(.currency)
        _ = sheet.register(.percent)
        let id = sheet.register(.date)
        #expect(id == 4)
    }

    // MARK: - XML Output: Fonts

    @Test("XML contains default font")
    func testXMLContainsDefaultFont() {
        let sheet = StyleSheet()
        _ = sheet.register(.general)
        let xml = sheet.toXML()
        #expect(xml.contains("<name val=\"Calibri\"/>"))
        #expect(xml.contains("<sz val=\"11\"/>"))
    }

    @Test("XML contains bold font")
    func testXMLContainsBoldFont() {
        let sheet = StyleSheet()
        _ = sheet.register(.header)
        let xml = sheet.toXML()
        #expect(xml.contains("<b/>"))
    }

    @Test("XML contains italic font")
    func testXMLContainsItalicFont() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(italic: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("<i/>"))
    }

    @Test("XML contains underline font")
    func testXMLContainsUnderlineFont() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(underline: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("<u/>"))
    }

    @Test("XML contains font color")
    func testXMLContainsFontColor() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(color: "FFFF0000"))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("<color rgb=\"FFFF0000\"/>"))
    }

    @Test("XML contains custom font name")
    func testXMLContainsCustomFontName() {
        let sheet = StyleSheet()
        let style = CellStyle(font: Font(name: "SF Mono", size: 14))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("<name val=\"SF Mono\"/>"))
        #expect(xml.contains("<sz val=\"14\"/>"))
    }

    // MARK: - XML Output: Fills

    @Test("XML contains required fills")
    func testXMLContainsRequiredFills() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        #expect(xml.contains("patternType=\"none\""))
        #expect(xml.contains("patternType=\"gray125\""))
    }

    @Test("XML contains solid fill")
    func testXMLContainsSolidFill() {
        let sheet = StyleSheet()
        _ = sheet.register(.input)
        let xml = sheet.toXML()
        #expect(xml.contains("patternType=\"solid\""))
        #expect(xml.contains("<fgColor rgb=\"FFFFFF00\"/>"))
    }

    // MARK: - XML Output: Borders

    @Test("XML contains empty border")
    func testXMLContainsEmptyBorder() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        #expect(xml.contains("<border>"))
        #expect(xml.contains("<left/>"))
    }

    @Test("XML contains thin border")
    func testXMLContainsThinBorder() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .thin))
        let xml = sheet.toXML()
        #expect(xml.contains("style=\"thin\""))
        #expect(xml.contains("<color rgb=\"FF000000\"/>"))
    }

    @Test("XML contains bottom border only")
    func testXMLContainsBottomBorderOnly() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .bottom))
        let xml = sheet.toXML()
        #expect(xml.contains("<bottom style=\"thin\">"))
        #expect(xml.contains("<top/>"))
        #expect(xml.contains("<left/>"))
        #expect(xml.contains("<right/>"))
    }

    // MARK: - XML Output: Number Formats

    @Test("XML contains builtin number format")
    func testXMLContainsBuiltinNumberFormat() {
        let sheet = StyleSheet()
        _ = sheet.register(.currency)
        let xml = sheet.toXML()
        #expect(xml.contains("numFmtId=\"4\""))
        #expect(!(xml.contains("<numFmts")))
    }

    @Test("XML contains custom number format")
    func testXMLContainsCustomNumberFormat() {
        let sheet = StyleSheet()
        let style = CellStyle(numberFormat: NumberFormat(formatString: "0.000"))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("<numFmts count=\"1\">"))
        #expect(xml.contains("numFmtId=\"164\""))
        #expect(xml.contains("formatCode=\"0.000\""))
    }

    @Test("Custom number formats get sequential ids")
    func testCustomNumberFormatsGetSequentialIds() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(numberFormat: NumberFormat(formatString: "0.000")))
        _ = sheet.register(CellStyle(numberFormat: NumberFormat(formatString: "#,##0.0")))
        let xml = sheet.toXML()
        #expect(xml.contains("<numFmts count=\"2\">"))
        #expect(xml.contains("numFmtId=\"164\""))
        #expect(xml.contains("numFmtId=\"165\""))
    }

    // MARK: - XML Output: Alignment

    @Test("XML contains alignment")
    func testXMLContainsAlignment() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(horizontal: .center, vertical: .bottom))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("applyAlignment=\"1\""))
        #expect(xml.contains("horizontal=\"center\""))
        #expect(xml.contains("vertical=\"bottom\""))
    }

    @Test("XML contains wrap text")
    func testXMLContainsWrapText() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(wrapText: true))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("wrapText=\"1\""))
    }

    @Test("XML contains indent")
    func testXMLContainsIndent() {
        let sheet = StyleSheet()
        let style = CellStyle(alignment: Alignment(indent: 2))
        _ = sheet.register(style)
        let xml = sheet.toXML()
        #expect(xml.contains("indent=\"2\""))
    }

    // MARK: - XML Output: Apply Attributes

    @Test("Apply font attribute")
    func testApplyFontAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.header)
        let xml = sheet.toXML()
        #expect(xml.contains("applyFont=\"1\""))
    }

    @Test("Apply fill attribute")
    func testApplyFillAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.input)
        let xml = sheet.toXML()
        #expect(xml.contains("applyFill=\"1\""))
    }

    @Test("Apply border attribute")
    func testApplyBorderAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(border: .thin))
        let xml = sheet.toXML()
        #expect(xml.contains("applyBorder=\"1\""))
    }

    @Test("Apply number format attribute")
    func testApplyNumberFormatAttribute() {
        let sheet = StyleSheet()
        _ = sheet.register(.currency)
        let xml = sheet.toXML()
        #expect(xml.contains("applyNumberFormat=\"1\""))
    }

    // MARK: - XML Structure

    @Test("XML has style sheet root")
    func testXMLHasStyleSheetRoot() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        #expect(xml.contains("<styleSheet"))
        #expect(xml.contains("</styleSheet>"))
    }

    @Test("XML has cell style xfs")
    func testXMLHasCellStyleXfs() {
        let sheet = StyleSheet()
        let xml = sheet.toXML()
        #expect(xml.contains("<cellStyleXfs count=\"1\">"))
    }

    // MARK: - Deduplication

    @Test("Font deduplication")
    func testFontDeduplication() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(font: Font(bold: true)))
        _ = sheet.register(CellStyle(font: Font(bold: true), numberFormat: .currency))
        let xml = sheet.toXML()
        #expect(xml.contains("<fonts count=\"2\">"))
    }

    @Test("Fill deduplication")
    func testFillDeduplication() {
        let sheet = StyleSheet()
        _ = sheet.register(CellStyle(fill: .solid("FFFFFF00")))
        _ = sheet.register(CellStyle(font: Font(bold: true), fill: .solid("FFFFFF00")))
        let xml = sheet.toXML()
        #expect(xml.contains("<fills count=\"3\">"))
    }
}
