import XCTest
@testable import SwiftXLSX

final class FontTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInitName() {
        let font = Font()
        XCTAssertEqual(font.name, "Calibri")
    }

    func testDefaultInitSize() {
        let font = Font()
        XCTAssertEqual(font.size, 11)
    }

    func testDefaultInitColorIsNil() {
        let font = Font()
        XCTAssertNil(font.color)
    }

    func testDefaultInitBoldIsFalse() {
        let font = Font()
        XCTAssertFalse(font.bold)
    }

    func testDefaultInitItalicIsFalse() {
        let font = Font()
        XCTAssertFalse(font.italic)
    }

    func testDefaultInitUnderlineIsFalse() {
        let font = Font()
        XCTAssertFalse(font.underline)
    }

    // MARK: - Custom Init

    func testCustomInitWithAllParameters() {
        let font = Font(name: "SF Mono", size: 14, color: "FF0000FF",
                        bold: true, italic: true, underline: true)
        XCTAssertEqual(font.name, "SF Mono")
        XCTAssertEqual(font.size, 14)
        XCTAssertEqual(font.color, "FF0000FF")
        XCTAssertTrue(font.bold)
        XCTAssertTrue(font.italic)
        XCTAssertTrue(font.underline)
    }

    // MARK: - Equatable

    func testEqualFontsAreEqual() {
        let a = Font(name: "Arial", size: 12, color: "FF000000", bold: true,
                     italic: false, underline: false)
        let b = Font(name: "Arial", size: 12, color: "FF000000", bold: true,
                     italic: false, underline: false)
        XCTAssertEqual(a, b)
    }

    func testDifferentNameIsNotEqual() {
        let a = Font(name: "Arial", size: 12)
        let b = Font(name: "Helvetica", size: 12)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentSizeIsNotEqual() {
        let a = Font(size: 11)
        let b = Font(size: 14)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentColorIsNotEqual() {
        let a = Font(color: "FF000000")
        let b = Font(color: "FFFF0000")
        XCTAssertNotEqual(a, b)
    }

    func testDifferentBoldIsNotEqual() {
        let a = Font(bold: false)
        let b = Font(bold: true)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentItalicIsNotEqual() {
        let a = Font(italic: false)
        let b = Font(italic: true)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentUnderlineIsNotEqual() {
        let a = Font(underline: false)
        let b = Font(underline: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testSameFontHasSameHash() {
        let a = Font(name: "Courier", size: 10, bold: true)
        let b = Font(name: "Courier", size: 10, bold: true)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFontCanBeUsedAsSetElement() {
        let font = Font(name: "SF Pro Display", size: 13)
        var set: Set<Font> = []
        set.insert(font)
        XCTAssertTrue(set.contains(font))
        XCTAssertEqual(set.count, 1)
    }

    func testFontCanBeUsedAsDictionaryKey() {
        let font = Font(name: "Menlo", size: 12, bold: true)
        let dict: [Font: Int] = [font: 42]
        XCTAssertEqual(dict[font], 42)
    }

    // MARK: - Sendable

    func testSendableConformance() {
        let font = Font()
        let _: any Sendable = font
    }

    // MARK: - All Options Enabled

    func testAllOptionsEnabled() {
        let font = Font(name: "SF Mono", size: 16, color: "FFFF0000",
                        bold: true, italic: true, underline: true)
        XCTAssertEqual(font.name, "SF Mono")
        XCTAssertEqual(font.size, 16)
        XCTAssertEqual(font.color, "FFFF0000")
        XCTAssertTrue(font.bold)
        XCTAssertTrue(font.italic)
        XCTAssertTrue(font.underline)
    }
}
