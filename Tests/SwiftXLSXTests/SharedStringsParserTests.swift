import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct SharedStringsParserTests {

    // MARK: - Helpers

    private func xmlData(_ body: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\(body)</sst>
        """
        return Data(xml.utf8)
    }

    // MARK: - Furigana

    /// **A phonetic run is not part of the value.** A Japanese workbook stores the reading
    /// of a name in an `<rPh>` sibling of the text runs, with `sb`/`eb` marking which
    /// characters it applies to. It is annotation, not content — the cell says 山田, and
    /// ヤマダ is how to pronounce it.
    ///
    /// A parser that accumulates every `<t>` inside `<si>` returns 山田ヤマダ, which is not a
    /// missing feature but a corrupted value: it is wrong for every function that reads the
    /// cell, not only for `PHONETIC`, and it is invisible to a reader who cannot tell the
    /// two scripts apart.
    @Test("Phonetic run is not concatenated into the value")
    func testPhoneticRunIsNotConcatenatedIntoTheValue() throws {
        let data = xmlData("""
        <si>\
        <r><t>山田</t></r>\
        <rPh sb="0" eb="2"><t>ヤマダ</t></rPh>\
        <phoneticPr fontId="1"/>\
        </si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["山田"])
    }

    /// Several runs each with their own reading — the value is still only the runs.
    @Test("Several phonetic runs are all excluded")
    func testSeveralPhoneticRunsAreAllExcluded() throws {
        let data = xmlData("""
        <si>\
        <r><t>山田</t></r>\
        <rPh sb="0" eb="2"><t>ヤマダ</t></rPh>\
        <r><t>太郎</t></r>\
        <rPh sb="2" eb="4"><t>タロウ</t></rPh>\
        </si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["山田太郎"])
    }

    /// A plain rich-text string with no furigana still concatenates its runs, which is the
    /// behaviour the fix must not disturb.
    @Test("Ordinary rich text still concatenates")
    func testOrdinaryRichTextStillConcatenates() throws {
        let data = xmlData("<si><r><t>Hello </t></r><r><t>world</t></r></si>")
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["Hello world"])
    }

    /// The reading is now kept rather than dropped, paired with the value it annotates.
    @Test("Phonetic is captured alongside the value")
    func testPhoneticIsCapturedAlongsideTheValue() throws {
        let data = xmlData("""
        <si>\
        <r><t>山田</t></r>\
        <rPh sb="0" eb="2"><t>ヤマダ</t></rPh>\
        </si>
        """)
        let entries = try SharedStringsParser.parseEntries(data: data)
        #expect(entries == [.init(text: "山田", phonetic: "ヤマダ")])
    }

    /// Several readings for one value concatenate, in document order, as the runs do.
    @Test("Several readings concatenate")
    func testSeveralReadingsConcatenate() throws {
        let data = xmlData("""
        <si>\
        <r><t>山田</t></r>\
        <rPh sb="0" eb="2"><t>ヤマダ</t></rPh>\
        <r><t>太郎</t></r>\
        <rPh sb="2" eb="4"><t>タロウ</t></rPh>\
        </si>
        """)
        let entries = try SharedStringsParser.parseEntries(data: data)
        #expect(entries == [.init(text: "山田太郎", phonetic: "ヤマダタロウ")])
    }

    /// **No reading is `nil`, not the empty string.** A caller asking for a phonetic wants
    /// to distinguish "this cell has no reading" from "its reading is blank", and every
    /// non-Japanese workbook is the first case.
    @Test("Absent reading is nil")
    func testAbsentReadingIsNil() throws {
        let entries = try SharedStringsParser.parseEntries(data: xmlData("<si><t>Hello</t></si>"))
        #expect(entries == [.init(text: "Hello", phonetic: nil)])
    }

    // MARK: - 1. Empty data

    @Test("Empty data returns empty array")
    func testEmptyDataReturnsEmptyArray() throws {
        let result = try SharedStringsParser.parse(data: Data())
        #expect(result == [])
    }

    // MARK: - 2. Single string

    @Test("Single string")
    func testSingleString() throws {
        let data = xmlData("<si><t>Hello</t></si>")
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["Hello"])
    }

    // MARK: - 3. Multiple strings (order preserved)

    @Test("Multiple strings preserve order")
    func testMultipleStringsPreserveOrder() throws {
        let data = xmlData("""
        <si><t>Alpha</t></si>\
        <si><t>Beta</t></si>\
        <si><t>Gamma</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - 4. Empty string entry

    @Test("Empty string entry")
    func testEmptyStringEntry() throws {
        let data = xmlData("<si><t></t></si>")
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == [""])
    }

    // MARK: - 5. Unicode strings

    @Test("Unicode strings")
    func testUnicodeStrings() throws {
        let data = xmlData("""
        <si><t>caf\u{00E9}</t></si>\
        <si><t>\u{4F60}\u{597D}</t></si>\
        <si><t>\u{1F600}</t></si>\
        <si><t>\u{00FC}\u{00F6}\u{00E4}</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result.count == 4)
        #expect(result[0] == "caf\u{00E9}")   // accented
        #expect(result[1] == "\u{4F60}\u{597D}") // CJK
        #expect(result[2] == "\u{1F600}")       // emoji
        #expect(result[3] == "\u{00FC}\u{00F6}\u{00E4}") // umlauts
    }

    // MARK: - 6. Rich text (formatting ignored, text concatenated)

    @Test("Rich text concatenates runs")
    func testRichTextConcatenatesRuns() throws {
        let data = xmlData("""
        <si>\
        <r><rPr><b/></rPr><t>Bold</t></r>\
        <r><rPr><sz val="11"/></rPr><t> Normal</t></r>\
        </si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["Bold Normal"])
    }

    // MARK: - 7. Multiple rich text runs

    @Test("Multiple rich text runs")
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
        #expect(result == ["One Two Three Four"])
    }

    // MARK: - 8. Mixed simple and rich text entries

    @Test("Mixed simple and rich text")
    func testMixedSimpleAndRichText() throws {
        let data = xmlData("""
        <si><t>Simple</t></si>\
        <si><r><t>Rich</t></r><r><t> Text</t></r></si>\
        <si><t>Plain</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == ["Simple", "Rich Text", "Plain"])
    }

    // MARK: - 9. Preserved whitespace

    @Test("Preserved whitespace")
    func testPreservedWhitespace() throws {
        let data = xmlData("""
        <si><t xml:space="preserve"> padded </t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result == [" padded "])
    }

    // MARK: - 10. Large table (1000 strings)

    @Test("Large table")
    func testLargeTable() throws {
        var body = ""
        for i in 0..<1000 {
            body += "<si><t>String_\(i)</t></si>"
        }
        let data = xmlData(body)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result.count == 1000)
        #expect(result[0] == "String_0")
        #expect(result[42] == "String_42")
        #expect(result[500] == "String_500")
        #expect(result[999] == "String_999")
    }

    // MARK: - 11. Special XML characters (entity references)

    @Test("Special XML characters")
    func testSpecialXMLCharacters() throws {
        let data = xmlData("""
        <si><t>A &amp; B</t></si>\
        <si><t>x &lt; y</t></si>\
        <si><t>y &gt; x</t></si>\
        <si><t>&quot;quoted&quot;</t></si>\
        <si><t>it&apos;s</t></si>
        """)
        let result = try SharedStringsParser.parse(data: data)
        #expect(result[0] == "A & B")
        #expect(result[1] == "x < y")
        #expect(result[2] == "y > x")
        #expect(result[3] == "\"quoted\"")
        #expect(result[4] == "it's")
    }

    // MARK: - 12. Round-trip with SharedStrings.toXML()

    @Test("Round trip with shared strings writer")
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

        #expect(parsed.count == 5)
        #expect(parsed[0] == "Revenue")
        #expect(parsed[1] == "Expenses")
        #expect(parsed[2] == "Net Income")
        #expect(parsed[3] == "Q1 & Q2")
        #expect(parsed[4] == "\"Total\"")
    }
}
