import XCTest
@testable import SwiftXLSX

final class StyleSheetParserTests: XCTestCase {

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

    func testEmptyDataReturnsEmptyStyleSheet() throws {
        let result = try StyleSheetParser.parse(data: Data())
        XCTAssertTrue(result.fonts.isEmpty)
        XCTAssertTrue(result.fills.isEmpty)
        XCTAssertTrue(result.borders.isEmpty)
        XCTAssertTrue(result.cellFormats.isEmpty)
        XCTAssertTrue(result.numberFormats.isEmpty)
    }

    // MARK: - Number Formats

    // 2. Built-in format ID 0 -> .general
    func testBuiltinFormatId0IsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, .general)
    }

    // 3. Built-in format ID 4 -> "$#,##0.00"
    func testBuiltinFormatId4IsCurrency() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"4\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, NumberFormat(formatString: "$#,##0.00"))
    }

    // 4. Built-in format ID 10 -> "0.00%"
    func testBuiltinFormatId10IsPercent() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"10\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, .percent)
    }

    // 5. Built-in format ID 14 -> "mm/dd/yyyy"
    func testBuiltinFormatId14IsDate() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"14\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, .date)
    }

    // 6. Custom format (ID 164+)
    func testCustomNumberFormat() throws {
        let data = fullStylesXML(
            numFmts: "<numFmts count=\"1\"><numFmt numFmtId=\"164\" formatCode=\"0.000%\"/></numFmts>",
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, NumberFormat(formatString: "0.000%"))
    }

    // 7. Unknown format ID -> .general fallback
    func testUnknownFormatIdFallsBackToGeneral() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"999\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.numberFormat, .general)
    }

    // MARK: - Fonts

    // 8. Default font (Calibri 11pt)
    func testDefaultFont() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.fonts.count, 1)
        XCTAssertEqual(result.fonts[0].name, "Calibri")
        XCTAssertEqual(result.fonts[0].size, 11)
        XCTAssertFalse(result.fonts[0].bold)
        XCTAssertFalse(result.fonts[0].italic)
        XCTAssertFalse(result.fonts[0].underline)
        XCTAssertNil(result.fonts[0].color)
    }

    // 9. Bold font
    func testBoldFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.fonts.count, 1)
        XCTAssertTrue(result.fonts[0].bold)
    }

    // 10. Italic font
    func testItalicFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><i/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertTrue(result.fonts[0].italic)
    }

    // 11. Underline font
    func testUnderlineFont() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><u/><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertTrue(result.fonts[0].underline)
    }

    // 12. Font with color
    func testFontWithColor() throws {
        let data = fullStylesXML(
            fonts: "<fonts count=\"1\"><font><sz val=\"11\"/><color rgb=\"FFFF0000\"/><name val=\"Calibri\"/></font></fonts>"
        )
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.fonts[0].color, "FFFF0000")
    }

    // 13. Font with all properties
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
        XCTAssertEqual(font.name, "SF Mono")
        XCTAssertEqual(font.size, 14.5)
        XCTAssertEqual(font.color, "FF0000FF")
        XCTAssertTrue(font.bold)
        XCTAssertTrue(font.italic)
        XCTAssertTrue(font.underline)
    }

    // 14. Multiple fonts (verify fontId indexing)
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
        XCTAssertEqual(result.fonts.count, 3)
        // Index 0: default
        XCTAssertFalse(result.fonts[0].bold)
        // Index 1: bold
        XCTAssertTrue(result.fonts[1].bold)
        // Index 2: large Arial
        XCTAssertEqual(result.fonts[2].name, "Arial")
        XCTAssertEqual(result.fonts[2].size, 18)
        // Resolve style index 1 -> bold font
        let style1 = result.resolve(styleIndex: 1)
        XCTAssertTrue(style1.font.bold)
        // Resolve style index 2 -> large Arial
        let style2 = result.resolve(styleIndex: 2)
        XCTAssertEqual(style2.font.name, "Arial")
    }

    // MARK: - Fills

    // 15. None fill (patternType="none")
    func testNoneFill() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        // First fill is always "none" -> stored as nil
        XCTAssertNil(result.fills[0])
    }

    // 16. Gray125 fill
    func testGray125Fill() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.fills.count, 2)
        // Second fill is always gray125
        XCTAssertEqual(result.fills[1], Fill(patternType: .gray125))
    }

    // 17. Solid fill with foreground color
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
        XCTAssertEqual(result.fills.count, 3)
        XCTAssertEqual(result.fills[2], Fill(patternType: .solid, foregroundColor: "FFFFFF00"))
        // Resolve produces correct fill
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.fill, .solid("FFFFFF00"))
    }

    // 18. First two fills always none + gray125
    func testFirstTwoFillsAreStandard() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.fills.count, 2)
        XCTAssertNil(result.fills[0])
        XCTAssertEqual(result.fills[1], Fill(patternType: .gray125))
    }

    // MARK: - Borders

    // 19. Empty border (no styled edges)
    func testEmptyBorder() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        XCTAssertEqual(result.borders.count, 1)
        // Empty border elements with no style -> nil
        XCTAssertNil(result.borders[0])
    }

    // 20. Thin border all sides
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
        XCTAssertEqual(result.borders.count, 1)
        let border = result.borders[0]
        XCTAssertNotNil(border)
        XCTAssertEqual(border?.top, Border.BorderEdge(style: .thin, color: "FF000000"))
        XCTAssertEqual(border?.bottom, Border.BorderEdge(style: .thin, color: "FF000000"))
        XCTAssertEqual(border?.left, Border.BorderEdge(style: .thin, color: "FF000000"))
        XCTAssertEqual(border?.right, Border.BorderEdge(style: .thin, color: "FF000000"))
    }

    // 21. Bottom-only border
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
        let border = result.borders[0]
        XCTAssertNotNil(border)
        XCTAssertNil(border?.top)
        XCTAssertNil(border?.left)
        XCTAssertNil(border?.right)
        XCTAssertEqual(border?.bottom, Border.BorderEdge(style: .thin, color: "FF000000"))
    }

    // 22. Border with custom color
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
        let border = result.borders[0]
        XCTAssertNotNil(border)
        XCTAssertEqual(border?.left?.color, "FF0000FF")
        XCTAssertEqual(border?.left?.style, .thin)
    }

    // 23. Mixed border styles (thin bottom, medium top)
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
        let border = result.borders[0]
        XCTAssertNotNil(border)
        XCTAssertEqual(border?.top?.style, .medium)
        XCTAssertEqual(border?.bottom?.style, .thin)
        XCTAssertNil(border?.left)
        XCTAssertNil(border?.right)
    }

    // MARK: - Alignment

    // 24. Horizontal alignment (center)
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
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.horizontal, .center)
        XCTAssertNil(style.alignment?.vertical)
    }

    // 25. Vertical alignment (center)
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
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.vertical, .center)
    }

    // 26. Wrap text
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
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.wrapText, true)
    }

    // 27. Indent
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
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.indent, 3)
    }

    // 28. Combined alignment properties
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
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.horizontal, .right)
        XCTAssertEqual(style.alignment?.vertical, .top)
        XCTAssertEqual(style.alignment?.wrapText, true)
        XCTAssertEqual(style.alignment?.indent, 2)
    }

    // MARK: - CellXfs (combined resolution)

    // 29. Style index 0 -> default/general
    func testStyleIndex0IsDefault() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertEqual(style.font, Font())
        XCTAssertEqual(style.numberFormat, .general)
        XCTAssertNil(style.border)
        XCTAssertNil(style.fill)
        XCTAssertNil(style.alignment)
    }

    // 30. Bold header style (fontId=1 with bold font)
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
        XCTAssertTrue(style.font.bold)
        XCTAssertEqual(style.font.name, "Calibri")
        XCTAssertEqual(style.font.size, 11)
    }

    // 31. Fully styled cell (custom numfmt + fill + border + alignment)
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
        XCTAssertTrue(style.font.bold)
        XCTAssertTrue(style.font.italic)
        XCTAssertEqual(style.font.size, 12)
        XCTAssertEqual(style.font.color, "FFFF0000")
        XCTAssertEqual(style.font.name, "Arial")

        // Number format
        XCTAssertEqual(style.numberFormat, NumberFormat(formatString: "0.000%"))

        // Fill
        XCTAssertEqual(style.fill, .solid("FFFFFF00"))

        // Border
        XCTAssertNotNil(style.border)
        XCTAssertEqual(style.border, Border.thin)

        // Alignment
        XCTAssertNotNil(style.alignment)
        XCTAssertEqual(style.alignment?.horizontal, .center)
        XCTAssertEqual(style.alignment?.vertical, .center)
        XCTAssertEqual(style.alignment?.wrapText, true)
    }

    // 32. Out-of-range style index -> .general fallback
    func testOutOfRangeStyleIndexReturnsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 999)
        XCTAssertEqual(style, .general)
    }

    // 33. Negative style index -> .general fallback
    func testNegativeStyleIndexReturnsGeneral() throws {
        let data = fullStylesXML()
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: -1)
        XCTAssertEqual(style, .general)
    }

    // MARK: - Round-trip

    // 34. Parse XML generated by StyleSheet.toXML()
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
        XCTAssertTrue(resolvedBold.font.bold)

        // Verify currency
        let resolvedCurrency = parsed.resolve(styleIndex: currIdx)
        XCTAssertEqual(resolvedCurrency.numberFormat, .currency)

        // Verify date
        let resolvedDate = parsed.resolve(styleIndex: dateIdx)
        XCTAssertEqual(resolvedDate.numberFormat, .date)

        // Verify filled
        let resolvedFilled = parsed.resolve(styleIndex: fillIdx)
        XCTAssertEqual(resolvedFilled.fill, .solid("FFFFFF00"))

        // Verify bordered
        let resolvedBordered = parsed.resolve(styleIndex: borderIdx)
        XCTAssertNotNil(resolvedBordered.border)
        XCTAssertEqual(resolvedBordered.border?.top, Border.BorderEdge())
        XCTAssertEqual(resolvedBordered.border?.bottom, Border.BorderEdge())
        XCTAssertEqual(resolvedBordered.border?.left, Border.BorderEdge())
        XCTAssertEqual(resolvedBordered.border?.right, Border.BorderEdge())

        // Verify aligned
        let resolvedAligned = parsed.resolve(styleIndex: alignIdx)
        XCTAssertEqual(resolvedAligned.alignment?.horizontal, .center)
        XCTAssertEqual(resolvedAligned.alignment?.vertical, .center)
        XCTAssertEqual(resolvedAligned.alignment?.wrapText, true)

        // Verify complex style
        let resolvedComplex = parsed.resolve(styleIndex: complexIdx)
        XCTAssertEqual(resolvedComplex.font.name, "Arial")
        XCTAssertEqual(resolvedComplex.font.size, 14)
        XCTAssertEqual(resolvedComplex.font.color, "FFFF0000")
        XCTAssertTrue(resolvedComplex.font.bold)
        XCTAssertTrue(resolvedComplex.font.italic)
        XCTAssertNotNil(resolvedComplex.border)
        XCTAssertEqual(resolvedComplex.border?.bottom?.style, .medium)
        XCTAssertEqual(resolvedComplex.border?.bottom?.color, "FF0000FF")
        XCTAssertEqual(resolvedComplex.alignment?.horizontal, .right)
        XCTAssertEqual(resolvedComplex.alignment?.indent, 2)
        XCTAssertEqual(resolvedComplex.numberFormat, .percent)
        XCTAssertEqual(resolvedComplex.fill, .solid("FF00FF00"))
    }

    // MARK: - Edge cases

    // 35. Multiple custom number formats
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
        XCTAssertEqual(result.resolve(styleIndex: 0).numberFormat,
                       NumberFormat(formatString: "0.000%"))
        XCTAssertEqual(result.resolve(styleIndex: 1).numberFormat,
                       NumberFormat(formatString: "#,##0.0000"))
        XCTAssertEqual(result.resolve(styleIndex: 2).numberFormat,
                       NumberFormat(formatString: "yyyy-mm-dd"))
    }

    // 36. No alignment element -> nil alignment
    func testNoAlignmentIsNil() throws {
        let data = fullStylesXML(
            cellXfs: "<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs>"
        )
        let result = try StyleSheetParser.parse(data: data)
        let style = result.resolve(styleIndex: 0)
        XCTAssertNil(style.alignment)
    }

    // 37. Border with style but no color child (defaults to FF000000)
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
        let border = result.borders[0]
        XCTAssertNotNil(border)
        XCTAssertEqual(border?.left?.style, .thin)
        XCTAssertEqual(border?.left?.color, "FF000000")
    }
}
