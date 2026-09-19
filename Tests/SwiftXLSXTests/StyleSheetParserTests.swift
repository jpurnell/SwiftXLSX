import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct StyleSheetParserTests {

    // MARK: - Helpers

    /// Wraps a body in a minimal `<styleSheet>` envelope.
    private func xmlData(_ body: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\(body)</styleSheet>
        """
        return Data(xml.utf8)
    }

    /// Builds a minimal styles XML with the given sections.
    private func fullStylesXML(
        numFmts: String = "",
        fonts: String = "<fonts count=\"1\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>",
        fills: String = "<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill>"
            + "<fill><patternFill patternType=\"gray125\"/></fill></fills>",
        borders: String = "<borders count=\"1\"><border><left/><right/><top/><bottom/></border></borders>",
        cellStyleXfs: String = "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>",
        cellXfs: String = "<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
    ) -> Data {
        xmlData(numFmts + fonts + fills + borders + cellStyleXfs + cellXfs)
    }

    // MARK: - 1. Empty data

    @Test("Empty data returns empty style sheet")
    func testEmptyDataReturnsEmptyStyleSheet() throws {
        let result = try StyleSheetParser.parse(data: Data())
        #expect(result.fonts.isEmpty)
        #expect(result.fills.isEmpty)
        #expect(result.borders.isEmpty)
        #expect(result.cellFormats.isEmpty)
        #expect(result.numberFormats.isEmpty)
    }

    // MARK: - Number Formats

    // 2. Built-in format ID 0 -> .general
    @Test("Builtin format id0 is general")
    func testBuiltinFormatId0IsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == .general)
    }

    // 3. Built-in format ID 4 -> "$#,##0.00"
    @Test("Builtin format id4 is currency")
    func testBuiltinFormatId4IsCurrency() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"4\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == NumberFormat(formatString: "$#,##0.00"))
    }

    // 4. Built-in format ID 10 -> "0.00%"
    @Test("Builtin format id10 is percent")
    func testBuiltinFormatId10IsPercent() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"10\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == .percent)
    }

    // 5. Built-in format ID 14 -> "mm/dd/yyyy"
    @Test("Builtin format id14 is date")
    func testBuiltinFormatId14IsDate() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"14\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == .date)
    }

    // 6. Custom format (ID 164+)
    @Test("Custom number format")
    func testCustomNumberFormat() throws {
        let data = fullStylesXML(
            numFmts: "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"0.000%\"/></numFmts>",
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == NumberFormat(formatString: "0.000%"))
    }

    // 7. Unknown format ID -> .general fallback
    @Test("Unknown format id falls back to general")
    func testUnknownFormatIdFallsBackToGeneral() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"999\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.numberFormat == .general)
    }

    // MARK: - Fonts

    // 8. Default font (Calibri 11pt)
    @Test("Default font")
    func testDefaultFont() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts.count == 1)
        #expect(result.fonts[0].name == "Calibri")
        #expect(result.fonts[0].size.isEqual(to: 11))
        #expect(!(result.fonts[0].bold))
        #expect(!(result.fonts[0].italic))
        #expect(!(result.fonts[0].underline))
        #expect(result.fonts[0].color == nil)
    }

    // 9. Bold font
    @Test("Bold font")
    func testBoldFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts.count == 1)
        #expect(result.fonts[0].bold)
    }

    // 10. Italic font
    @Test("Italic font")
    func testItalicFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><i/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts[0].italic)
    }

    // 11. Underline font
    @Test("Underline font")
    func testUnderlineFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><u/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts[0].underline)
    }

    // 12. Font with color
    @Test("Font with color")
    func testFontWithColor() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><sz val=\"11\"/><color rgb=\"FFFF0000\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts[0].color == "FFFF0000")
    }

    // 13. Font with all properties
    @Test("Font with all properties")
    func testFontWithAllProperties() throws {
        let data = fullStylesXML(
            fonts: """
            <fonts count="1"><font>\
            <b/><i/><u/>\
            <sz val="14.5"/>\
            <color rgb="FF0000FF"/>\
            <name val="SF Mono"/>\
            </font></fonts>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let font = result.fonts[0]
        #expect(font.name == "SF Mono")
        #expect(font.size.isEqual(to: 14.5))
        #expect(font.color == "FF0000FF")
        #expect(font.bold)
        #expect(font.italic)
        #expect(font.underline)
    }

    // 14. Multiple fonts (verify fontId indexing)
    @Test("Multiple fonts preserve order")
    func testMultipleFontsPreserveOrder() throws {
        let data = fullStylesXML(
            fonts: """
            <fonts count="3">\
            <font><sz val="11"/><name val="Calibri"/></font>\
            <font><b/><sz val="11"/><name val="Calibri"/></font>\
            <font><sz val="18"/><name val="Arial"/></font>\
            </fonts>
            """,
            cellXfs: """
            <cellXfs count="3">\
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>\
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0"/>\
            <xf numFmtId="0" fontId="2" fillId="0" borderId="0"/>\
            </cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fonts.count == 3)
        // Index 0: default
        #expect(!(result.fonts[0].bold))
        // Index 1: bold
        #expect(result.fonts[1].bold)
        // Index 2: large Arial
        #expect(result.fonts[2].name == "Arial")
        #expect(result.fonts[2].size.isEqual(to: 18))
        // Resolve style index 1 -> bold font
        let style1 = result.resolve(styleIndex: 1)
        #expect(style1.font.bold)
        // Resolve style index 2 -> large Arial
        let style2 = result.resolve(styleIndex: 2)
        #expect(style2.font.name == "Arial")
    }

    // MARK: - Fills

    // 15. None fill (patternType="none")
    @Test("None fill")
    func testNoneFill() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        // First fill is always "none" -> stored as nil
        #expect(result.fills[0] == nil)
    }

    // 16. Gray125 fill
    @Test("Gray125 fill")
    func testGray125Fill() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fills.count == 2)
        // Second fill is always gray125
        #expect(result.fills[1] == Fill(patternType: .gray125))
    }

    // 17. Solid fill with foreground color
    @Test("Solid fill with color")
    func testSolidFillWithColor() throws {
        let data = fullStylesXML(
            fills: """
            <fills count="3">\
            <fill><patternFill patternType="none"/></fill>\
            <fill><patternFill patternType="gray125"/></fill>\
            <fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/></patternFill></fill>\
            </fills>
            """,
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"2\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fills.count == 3)
        #expect(result.fills[2] == Fill(patternType: .solid, foregroundColor: "FFFFFF00"))
        // Resolve produces correct fill
        let style = result.resolve(styleIndex: 0)
        #expect(style.fill == .solid("FFFFFF00"))
    }

    // 18. First two fills always none + gray125
    @Test("First two fills are standard")
    func testFirstTwoFillsAreStandard() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.fills.count == 2)
        #expect(result.fills[0] == nil)
        #expect(result.fills[1] == Fill(patternType: .gray125))
    }

    // MARK: - Borders

    // 19. Empty border (no styled edges)
    @Test("Empty border")
    func testEmptyBorder() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.borders.count == 1)
        // Empty border elements with no style -> nil
        #expect(result.borders[0] == nil)
    }

    // 20. Thin border all sides
    @Test("Thin border all sides")
    func testThinBorderAllSides() throws {
        let data = fullStylesXML(
            borders: """
            <borders count="1"><border>\
            <left style="thin"><color rgb="FF000000"/></left>\
            <right style="thin"><color rgb="FF000000"/></right>\
            <top style="thin"><color rgb="FF000000"/></top>\
            <bottom style="thin"><color rgb="FF000000"/></bottom>\
            </border></borders>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.borders.count == 1)
        let border = try #require(result.borders[0])
        #expect(border == Border.thin)
        #expect(border.top == Border.BorderEdge(style: .thin, color: "FF000000"))
        #expect(border.bottom == Border.BorderEdge(style: .thin, color: "FF000000"))
        #expect(border.left == Border.BorderEdge(style: .thin, color: "FF000000"))
        #expect(border.right == Border.BorderEdge(style: .thin, color: "FF000000"))
    }

    // 21. Bottom-only border
    @Test("Bottom only border")
    func testBottomOnlyBorder() throws {
        let data = fullStylesXML(
            borders: """
            <borders count="1"><border>\
            <left/><right/><top/>\
            <bottom style="thin"><color rgb="FF000000"/></bottom>\
            </border></borders>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let border = try #require(result.borders[0])
        #expect(border == Border(bottom: Border.BorderEdge(style: .thin, color: "FF000000")))
        #expect(border.top == nil)
        #expect(border.left == nil)
        #expect(border.right == nil)
        #expect(border.bottom == Border.BorderEdge(style: .thin, color: "FF000000"))
    }

    // 22. Border with custom color
    @Test("Border with color")
    func testBorderWithColor() throws {
        let data = fullStylesXML(
            borders: """
            <borders count="1"><border>\
            <left style="thin"><color rgb="FF0000FF"/></left>\
            <right/><top/><bottom/>\
            </border></borders>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let border = try #require(result.borders[0])
        #expect(border == Border(left: Border.BorderEdge(style: .thin, color: "FF0000FF")))
        #expect(border.left?.color == "FF0000FF")
        #expect(border.left?.style == .thin)
    }

    // 23. Mixed border styles (thin bottom, medium top)
    @Test("Mixed border styles")
    func testMixedBorderStyles() throws {
        let data = fullStylesXML(
            borders: """
            <borders count="1"><border>\
            <left/><right/>\
            <top style="medium"><color rgb="FF000000"/></top>\
            <bottom style="thin"><color rgb="FF000000"/></bottom>\
            </border></borders>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let border = try #require(result.borders[0])
        #expect(border == Border(
            top: Border.BorderEdge(style: .medium, color: "FF000000"),
            bottom: Border.BorderEdge(style: .thin, color: "FF000000")
        ))
        #expect(border.top?.style == .medium)
        #expect(border.bottom?.style == .thin)
        #expect(border.left == nil)
        #expect(border.right == nil)
    }

    // MARK: - Alignment

    // 24. Horizontal alignment (center)
    @Test("Horizontal alignment")
    func testHorizontalAlignment() throws {
        let data = fullStylesXML(
            cellXfs: """
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyAlignment="1">\
            <alignment horizontal="center"/>\
            </xf></cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(horizontal: .center))
        #expect(alignment.horizontal == .center)
        #expect(alignment.vertical == nil)
    }

    // 25. Vertical alignment (center)
    @Test("Vertical alignment")
    func testVerticalAlignment() throws {
        let data = fullStylesXML(
            cellXfs: """
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyAlignment="1">\
            <alignment vertical="center"/>\
            </xf></cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(vertical: .center))
        #expect(alignment.vertical == .center)
    }

    // 26. Wrap text
    @Test("Wrap text")
    func testWrapText() throws {
        let data = fullStylesXML(
            cellXfs: """
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyAlignment="1">\
            <alignment wrapText="1"/>\
            </xf></cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(wrapText: true))
        #expect(alignment.wrapText == true)
    }

    // 27. Indent
    @Test("Indent")
    func testIndent() throws {
        let data = fullStylesXML(
            cellXfs: """
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyAlignment="1">\
            <alignment indent="3"/>\
            </xf></cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(indent: 3))
        #expect(alignment.indent == 3)
    }

    // 28. Combined alignment properties
    @Test("Combined alignment")
    func testCombinedAlignment() throws {
        let data = fullStylesXML(
            cellXfs: """
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyAlignment="1">\
            <alignment horizontal="right" vertical="top" wrapText="1" indent="2"/>\
            </xf></cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(horizontal: .right, vertical: .top, wrapText: true, indent: 2))
        #expect(alignment.horizontal == .right)
        #expect(alignment.vertical == .top)
        #expect(alignment.wrapText == true)
        #expect(alignment.indent == 2)
    }

    // MARK: - CellXfs (combined resolution)

    // 29. Style index 0 -> default/general
    @Test("Style index0 is default")
    func testStyleIndex0IsDefault() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.font == Font())
        #expect(style.numberFormat == .general)
        #expect(style.border == nil)
        #expect(style.fill == nil)
        #expect(style.alignment == nil)
    }

    // 30. Bold header style (fontId=1 with bold font)
    @Test("Bold header style resolution")
    func testBoldHeaderStyleResolution() throws {
        let data = fullStylesXML(
            fonts: """
            <fonts count="2">\
            <font><sz val="11"/><name val="Calibri"/></font>\
            <font><b/><sz val="11"/><name val="Calibri"/></font>\
            </fonts>
            """,
            cellXfs: """
            <cellXfs count="2">\
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>\
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" applyFont="1"/>\
            </cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 1)
        #expect(style.font.bold)
        #expect(style.font.name == "Calibri")
        #expect(style.font.size.isEqual(to: 11))
    }

    // 31. Fully styled cell (custom numfmt + fill + border + alignment)
    @Test("Fully styled cell resolution")
    func testFullyStyledCellResolution() throws {
        let data = fullStylesXML(
            numFmts: "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"0.000%\"/></numFmts>",
            fonts: """
            <fonts count="2">\
            <font><sz val="11"/><name val="Calibri"/></font>\
            <font><b/><i/><sz val="12"/><color rgb="FFFF0000"/><name val="Arial"/></font>\
            </fonts>
            """,
            fills: """
            <fills count="3">\
            <fill><patternFill patternType="none"/></fill>\
            <fill><patternFill patternType="gray125"/></fill>\
            <fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/></patternFill></fill>\
            </fills>
            """,
            borders: """
            <borders count="2">\
            <border><left/><right/><top/><bottom/></border>\
            <border>\
            <left style="thin"><color rgb="FF000000"/></left>\
            <right style="thin"><color rgb="FF000000"/></right>\
            <top style="thin"><color rgb="FF000000"/></top>\
            <bottom style="thin"><color rgb="FF000000"/></bottom>\
            </border>\
            </borders>
            """,
            cellXfs: """
            <cellXfs count="2">\
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>\
            <xf numFmtId="164" fontId="1" fillId="2" borderId="1" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">\
            <alignment horizontal="center" vertical="center" wrapText="1"/>\
            </xf>\
            </cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 1)

        // Font
        #expect(style.font.bold)
        #expect(style.font.italic)
        #expect(style.font.size.isEqual(to: 12))
        #expect(style.font.color == "FFFF0000")
        #expect(style.font.name == "Arial")

        // Number format
        #expect(style.numberFormat == NumberFormat(formatString: "0.000%"))

        // Fill
        #expect(style.fill == .solid("FFFFFF00"))

        // Border
        #expect(style.border == Border.thin)

        // Alignment
        let alignment = try #require(style.alignment)
        #expect(alignment == Alignment(horizontal: .center, vertical: .center, wrapText: true))
        #expect(alignment.horizontal == .center)
        #expect(alignment.vertical == .center)
        #expect(alignment.wrapText == true)
    }

    // 32. Out-of-range style index -> .general fallback
    @Test("Out of range style index returns general")
    func testOutOfRangeStyleIndexReturnsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 999)
        #expect(style == .general)
    }

    // 33. Negative style index -> .general fallback
    @Test("Negative style index returns general")
    func testNegativeStyleIndexReturnsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: -1)
        #expect(style == .general)
    }

    // MARK: - Round-trip

    // 34. Parse XML generated by StyleSheet.toXML()
    @Test("Round trip with style sheet writer")
    func testRoundTripWithStyleSheetWriter() throws {
        let sheet = StyleSheet()

        // Register a variety of styles
        let boldStyle = CellStyle(font: Font(bold: true))
        let currencyStyle = CellStyle(numberFormat: .currency)
        let dateStyle = CellStyle(numberFormat: .date)
        let filledStyle = CellStyle(fill: .solid("FFFFFF00"))
        let borderedStyle = CellStyle(border: .thin)
        let alignedStyle = CellStyle(alignment: Alignment(horizontal: .center, vertical: .center, wrapText: true))
        let complexStyle = CellStyle(
            font: Font(name: "Arial", size: 14, color: "FFFF0000", bold: true, italic: true),
            border: Border(bottom: Border.BorderEdge(style: .medium, color: "FF0000FF")),
            alignment: Alignment(horizontal: .right, indent: 2),
            numberFormat: .percent,
            fill: .solid("FF00FF00")
        )

        let boldIdx = sheet.register(boldStyle)
        let currIdx = sheet.register(currencyStyle)
        let dateIdx = sheet.register(dateStyle)
        let fillIdx = sheet.register(filledStyle)
        let borderIdx = sheet.register(borderedStyle)
        let alignIdx = sheet.register(alignedStyle)
        let complexIdx = sheet.register(complexStyle)

        // Generate XML and parse it back
        let xml = sheet.toXML()
        let data = Data(xml.utf8)
        let parsed = try StyleSheetParser.parse(data: data)

        // Verify bold style
        let resolvedBold = parsed.resolve(styleIndex: boldIdx)
        #expect(resolvedBold.font.bold)

        // Verify currency
        let resolvedCurrency = parsed.resolve(styleIndex: currIdx)
        #expect(resolvedCurrency.numberFormat == .currency)

        // Verify date
        let resolvedDate = parsed.resolve(styleIndex: dateIdx)
        #expect(resolvedDate.numberFormat == .date)

        // Verify filled
        let resolvedFilled = parsed.resolve(styleIndex: fillIdx)
        #expect(resolvedFilled.fill == .solid("FFFFFF00"))

        // Verify bordered
        let resolvedBordered = parsed.resolve(styleIndex: borderIdx)
        #expect(resolvedBordered.border == Border.thin)
        #expect(resolvedBordered.border?.top == Border.BorderEdge())
        #expect(resolvedBordered.border?.bottom == Border.BorderEdge())
        #expect(resolvedBordered.border?.left == Border.BorderEdge())
        #expect(resolvedBordered.border?.right == Border.BorderEdge())

        // Verify aligned
        let resolvedAligned = parsed.resolve(styleIndex: alignIdx)
        #expect(resolvedAligned.alignment?.horizontal == .center)
        #expect(resolvedAligned.alignment?.vertical == .center)
        #expect(resolvedAligned.alignment?.wrapText == true)

        // Verify complex style
        let resolvedComplex = parsed.resolve(styleIndex: complexIdx)
        #expect(resolvedComplex.font.name == "Arial")
        #expect(resolvedComplex.font.size.isEqual(to: 14))
        #expect(resolvedComplex.font.color == "FFFF0000")
        #expect(resolvedComplex.font.bold)
        #expect(resolvedComplex.font.italic)
        #expect(resolvedComplex.border == Border(bottom: Border.BorderEdge(style: .medium, color: "FF0000FF")))
        #expect(resolvedComplex.border?.bottom?.style == .medium)
        #expect(resolvedComplex.border?.bottom?.color == "FF0000FF")
        #expect(resolvedComplex.alignment?.horizontal == .right)
        #expect(resolvedComplex.alignment?.indent == 2)
        #expect(resolvedComplex.numberFormat == .percent)
        #expect(resolvedComplex.fill == .solid("FF00FF00"))
    }

    // MARK: - Edge cases

    // 35. Multiple custom number formats
    @Test("Multiple custom number formats")
    func testMultipleCustomNumberFormats() throws {
        let data = fullStylesXML(
            numFmts: """
            <numFmts count="3">\
            <numFmt numFmtId="164" formatCode="0.000%"/>\
            <numFmt numFmtId="165" formatCode="#,##0.0000"/>\
            <numFmt numFmtId="166" formatCode="yyyy-mm-dd"/>\
            </numFmts>
            """,
            cellXfs: """
            <cellXfs count="3">\
            <xf numFmtId="164" fontId="0" fillId="0" borderId="0"/>\
            <xf numFmtId="165" fontId="0" fillId="0" borderId="0"/>\
            <xf numFmtId="166" fontId="0" fillId="0" borderId="0"/>\
            </cellXfs>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        #expect(result.resolve(styleIndex: 0).numberFormat == NumberFormat(formatString: "0.000%"))
        #expect(result.resolve(styleIndex: 1).numberFormat == NumberFormat(formatString: "#,##0.0000"))
        #expect(result.resolve(styleIndex: 2).numberFormat == NumberFormat(formatString: "yyyy-mm-dd"))
    }

    // 36. No alignment element -> nil alignment
    @Test("No alignment is nil")
    func testNoAlignmentIsNil() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        #expect(style.alignment == nil)
    }

    // 37. Border with style but no color child (defaults to FF000000)
    @Test("Border style without color defaults to black")
    func testBorderStyleWithoutColorDefaultsToBlack() throws {
        let data = fullStylesXML(
            borders: """
            <borders count="1"><border>\
            <left style="thin"/>\
            <right/><top/><bottom/>\
            </border></borders>
            """
        )
        let result = try StyleSheetParser.parse(data: data)
        let border = try #require(result.borders[0])
        #expect(border == Border(left: Border.BorderEdge(style: .thin, color: "FF000000")))
        #expect(border.left?.style == .thin)
        #expect(border.left?.color == "FF000000")
    }
}
