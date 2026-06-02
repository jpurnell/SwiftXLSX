import XCTest
@testable import SwiftXLSX

final class CellStyleTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInit() {
        let style = CellStyle()
        XCTAssertEqual(style.font, Font())
        XCTAssertNil(style.border)
        XCTAssertNil(style.alignment)
        XCTAssertEqual(style.numberFormat, .general)
        XCTAssertNil(style.fill)
    }

    // MARK: - Custom Init

    func testCustomInit() {
        let font = Font(name: "Arial", size: 14, bold: true)
        let border = Border.thin
        let alignment = Alignment(horizontal: .center)
        let fill = Fill.solid("FFFF0000")
        let style = CellStyle(font: font, border: border, alignment: alignment,
                              numberFormat: .currency, fill: fill)
        XCTAssertEqual(style.font, font)
        XCTAssertEqual(style.border, border)
        XCTAssertEqual(style.alignment, alignment)
        XCTAssertEqual(style.numberFormat, .currency)
        XCTAssertEqual(style.fill, fill)
    }

    // MARK: - Presets

    func testGeneralPreset() {
        let style = CellStyle.general
        XCTAssertEqual(style.font, Font())
        XCTAssertNil(style.border)
        XCTAssertEqual(style.numberFormat, .general)
        XCTAssertNil(style.fill)
    }

    func testHeaderPreset() {
        let style = CellStyle.header
        XCTAssertTrue(style.font.bold)
        XCTAssertEqual(style.font.name, "Calibri")
        XCTAssertEqual(style.font.size, 11)
    }

    func testCurrencyPreset() {
        XCTAssertEqual(CellStyle.currency.numberFormat, .currency)
    }

    func testPercentPreset() {
        XCTAssertEqual(CellStyle.percent.numberFormat, .percent)
    }

    func testDatePreset() {
        XCTAssertEqual(CellStyle.date.numberFormat, .date)
    }

    func testIntegerPreset() {
        XCTAssertEqual(CellStyle.integer.numberFormat, .integer)
    }

    func testInputPreset() {
        XCTAssertEqual(CellStyle.input.fill, .solid("FFFFFF00"))
    }

    func testTitlePreset() {
        XCTAssertEqual(CellStyle.title.font.size, 18)
        XCTAssertTrue(CellStyle.title.font.bold)
    }

    // MARK: - Builder Pattern

    func testWithFont() {
        let original = CellStyle.general
        let modified = original.with(font: Font(name: "Arial", size: 14))
        XCTAssertEqual(modified.font.name, "Arial")
        XCTAssertEqual(modified.font.size, 14)
        XCTAssertEqual(original.font, Font())
    }

    func testWithBorder() {
        let modified = CellStyle.general.with(border: .thin)
        XCTAssertEqual(modified.border, .thin)
        XCTAssertNil(CellStyle.general.border)
    }

    func testWithAlignment() {
        let alignment = Alignment(horizontal: .center, vertical: .bottom, wrapText: true)
        let modified = CellStyle.general.with(alignment: alignment)
        XCTAssertEqual(modified.alignment, alignment)
    }

    func testWithNumberFormat() {
        let modified = CellStyle.general.with(numberFormat: .currency)
        XCTAssertEqual(modified.numberFormat, .currency)
    }

    func testWithFill() {
        let modified = CellStyle.general.with(fill: .solid("FFFF0000"))
        XCTAssertEqual(modified.fill, .solid("FFFF0000"))
    }

    func testWithNilBorder() {
        let styled = CellStyle(border: .thin)
        let cleared = styled.with(border: nil)
        XCTAssertNil(cleared.border)
    }

    func testWithChaining() {
        let style = CellStyle.general
            .with(font: Font(bold: true))
            .with(border: .bottom)
            .with(numberFormat: .currency)
            .with(fill: .solid("FFFFFF00"))
        XCTAssertTrue(style.font.bold)
        XCTAssertEqual(style.border, .bottom)
        XCTAssertEqual(style.numberFormat, .currency)
        XCTAssertEqual(style.fill, .solid("FFFFFF00"))
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = CellStyle(font: Font(bold: true), numberFormat: .currency)
        let b = CellStyle(font: Font(bold: true), numberFormat: .currency)
        XCTAssertEqual(a, b)
    }

    func testNotEqual() {
        XCTAssertNotEqual(CellStyle.general, CellStyle.header)
        XCTAssertNotEqual(CellStyle.currency, CellStyle.percent)
        XCTAssertNotEqual(CellStyle.general, CellStyle.input)
    }

    // MARK: - Hashable

    func testHashable() {
        let set: Set<CellStyle> = [.general, .header, .general, .currency]
        XCTAssertEqual(set.count, 3)
    }

    // MARK: - Sendable

    func testSendable() {
        let _: any Sendable = CellStyle.general
    }
}
