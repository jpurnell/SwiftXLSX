import XCTest
@testable import SwiftXLSX

final class SharedStringsParserTests: XCTestCase {

    // MARK: - Helpers

    private func xmlData(_ body: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\(body)</sst>
        """
        return Data(xml.utf8)
    }

    // MARK: - 1. Empty data

    func testEmptyDataReturnsEmptyArray() throws {
        let result = try SharedStringsParser.parse(data: Data())
        XCTAssertEqual(result, [])
    }

    // MARK: - 2. Single string

    func testSingleString() throws {
        let data = xmlData("<si><t>Hello</t></si>")
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, ["Hello"])
    }

    // MARK: - 3. Multiple strings (order preserved)

    func testMultipleStringsPreserveOrder() throws {
        let data = xmlData("""
        <si><t>Alpha</t></si>\
        <si><t>Beta</t></si>\
        <si><t>Gamma</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - 4. Empty string entry

    func testEmptyStringEntry() throws {
        let data = xmlData("<si><t></t></si>")
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, [""])
    }

    // MARK: - 5. Unicode strings

    func testUnicodeStrings() throws {
        let data = xmlData("""
        <si><t>caf\u{00E9}</t></si>\
        <si><t>\u{4F60}\u{597D}</t></si>\
        <si><t>\u{1F600}</t></si>\
        <si><t>\u{00FC}\u{00F6}\u{00E4}</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], "caf\u{00E9}")   // accented
        XCTAssertEqual(result[1], "\u{4F60}\u{597D}") // CJK
        XCTAssertEqual(result[2], "\u{1F600}")       // emoji
        XCTAssertEqual(result[3], "\u{00FC}\u{00F6}\u{00E4}") // umlauts
    }

    // MARK: - 6. Rich text (formatting ignored, text concatenated)

    func testRichTextConcatenatesRuns() throws {
        let data = xmlData("""
        <si>\
        <r><rPr><b/></rPr><t>Bold</t></r>\
        <r><rPr><sz val="11"/></rPr><t> Normal</t></r>\
        </si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, ["Bold Normal"])
    }

    // MARK: - 7. Multiple rich text runs

    func testMultipleRichTextRuns() throws {
        let data = xmlData("""
        <si>\
        <r><t>One</t></r>\
        <r><t> Two</t></r>\
        <r><t> Three</t></r>\
        <r><t> Four</t></r>\
        </si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, ["One Two Three Four"])
    }

    // MARK: - 8. Mixed simple and rich text entries

    func testMixedSimpleAndRichText() throws {
        let data = xmlData("""
        <si><t>Simple</t></si>\
        <si><r><t>Rich</t></r><r><t> Text</t></r></si>\
        <si><t>Plain</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, ["Simple", "Rich Text", "Plain"])
    }

    // MARK: - 9. Preserved whitespace

    func testPreservedWhitespace() throws {
        let data = xmlData("""
        <si><t xml:space="preserve"> padded </t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result, [" padded "])
    }

    // MARK: - 10. Large table (1000 strings)

    func testLargeTable() throws {
        var body = ""
        for i in 0..<1000 {
            body += "<si><t>String_\(i)</t></si>"
        }
        let data = xmlData(body)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result.count, 1000)
        XCTAssertEqual(result[0], "String_0")
        XCTAssertEqual(result[42], "String_42")
        XCTAssertEqual(result[500], "String_500")
        XCTAssertEqual(result[999], "String_999")
    }

    // MARK: - 11. Special XML characters (entity references)

    func testSpecialXMLCharacters() throws {
        let data = xmlData("""
        <si><t>A &amp; B</t></si>\
        <si><t>x &lt; y</t></si>\
        <si><t>y &gt; x</t></si>\
        <si><t>&quot;quoted&quot;</t></si>\
        <si><t>it&apos;s</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        XCTAssertEqual(result[0], "A & B")
        XCTAssertEqual(result[1], "x < y")
        XCTAssertEqual(result[2], "y > x")
        XCTAssertEqual(result[3], "\"quoted\"")
        XCTAssertEqual(result[4], "it's")
    }

    // MARK: - 12. Round-trip with SharedStrings.toXML()

    func testRoundTripWithSharedStringsWriter() throws {
        let sharedStrings = SharedStrings()
        _ = sharedStrings.index(for: "Revenue")
        _ = sharedStrings.index(for: "Expenses")
        _ = sharedStrings.index(for: "Net Income")
        _ = sharedStrings.index(for: "Q1 & Q2")
        _ = sharedStrings.index(for: "\"Total\"")

        let xml = sharedStrings.toXML()
        let data = Data(xml.utf8)
        let parsed = try SharedStringsParser.parse(data: data)

        XCTAssertEqual(parsed.count, 5)
        XCTAssertEqual(parsed[0], "Revenue")
        XCTAssertEqual(parsed[1], "Expenses")
        XCTAssertEqual(parsed[2], "Net Income")
        XCTAssertEqual(parsed[3], "Q1 & Q2")
        XCTAssertEqual(parsed[4], "\"Total\"")
    }
}
