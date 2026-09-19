import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FontTests {

    // MARK: - Default Init

    @Test("Default init name")
    func testDefaultInitName() {
        let font = Font()
        #expect(font.name == "Calibri")
    }

    @Test("Default init size")
    func testDefaultInitSize() {
        let font = Font()
        #expect(font.size.isEqual(to: 11))
    }

    @Test("Default init color is nil")
    func testDefaultInitColorIsNil() {
        let font = Font()
        #expect(font.color == nil)
    }

    @Test("Default init bold is false")
    func testDefaultInitBoldIsFalse() {
        let font = Font()
        #expect(!(font.bold))
    }

    @Test("Default init italic is false")
    func testDefaultInitItalicIsFalse() {
        let font = Font()
        #expect(!(font.italic))
    }

    @Test("Default init underline is false")
    func testDefaultInitUnderlineIsFalse() {
        let font = Font()
        #expect(!(font.underline))
    }

    // MARK: - Custom Init

    @Test("Custom init with all parameters")
    func testCustomInitWithAllParameters() {
        let font = Font(name: "SF Mono", size: 14, color: "FF0000FF",
                        bold: true, italic: true, underline: true)
        #expect(font.name == "SF Mono")
        #expect(font.size.isEqual(to: 14))
        #expect(font.color == "FF0000FF")
        #expect(font.bold)
        #expect(font.italic)
        #expect(font.underline)
    }

    // MARK: - Equatable

    @Test("Equal fonts are equal")
    func testEqualFontsAreEqual() {
        let a = Font(name: "Arial", size: 12, color: "FF000000", bold: true,
                     italic: false, underline: false)
        let b = Font(name: "Arial", size: 12, color: "FF000000", bold: true,
                     italic: false, underline: false)
        #expect(a == b)
    }

    @Test("Different name is not equal")
    func testDifferentNameIsNotEqual() {
        let a = Font(name: "Arial", size: 12)
        let b = Font(name: "Helvetica", size: 12)
        #expect(a != b)
    }

    @Test("Different size is not equal")
    func testDifferentSizeIsNotEqual() {
        let a = Font(size: 11)
        let b = Font(size: 14)
        #expect(a != b)
    }

    @Test("Different color is not equal")
    func testDifferentColorIsNotEqual() {
        let a = Font(color: "FF000000")
        let b = Font(color: "FFFF0000")
        #expect(a != b)
    }

    @Test("Different bold is not equal")
    func testDifferentBoldIsNotEqual() {
        let a = Font(bold: false)
        let b = Font(bold: true)
        #expect(a != b)
    }

    @Test("Different italic is not equal")
    func testDifferentItalicIsNotEqual() {
        let a = Font(italic: false)
        let b = Font(italic: true)
        #expect(a != b)
    }

    @Test("Different underline is not equal")
    func testDifferentUnderlineIsNotEqual() {
        let a = Font(underline: false)
        let b = Font(underline: true)
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Same font has same hash")
    func testSameFontHasSameHash() {
        let a = Font(name: "Courier", size: 10, bold: true)
        let b = Font(name: "Courier", size: 10, bold: true)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Font can be used as set element")
    func testFontCanBeUsedAsSetElement() {
        let font = Font(name: "SF Pro Display", size: 13)
        var set: Set<Font> = []
        set.insert(font)
        #expect(set.contains(font))
        #expect(set.count == 1)
    }

    @Test("Font can be used as dictionary key")
    func testFontCanBeUsedAsDictionaryKey() {
        let font = Font(name: "Menlo", size: 12, bold: true)
        let dict: [Font: Int] = [font: 42]
        #expect(dict[font] == 42)
    }

    // MARK: - Sendable

    @Test("Sendable conformance")
    func testSendableConformance() async {
        let font = Font()
        let _: any Sendable = font
        let received = await Task { font }.value
        #expect(received == font)
        #expect(received.name == "Calibri")
        #expect(received.size.isEqual(to: 11))
    }

    // MARK: - All Options Enabled

    @Test("All options enabled")
    func testAllOptionsEnabled() {
        let font = Font(name: "SF Mono", size: 16, color: "FFFF0000",
                        bold: true, italic: true, underline: true)
        #expect(font.name == "SF Mono")
        #expect(font.size.isEqual(to: 16))
        #expect(font.color == "FFFF0000")
        #expect(font.bold)
        #expect(font.italic)
        #expect(font.underline)
    }
}
