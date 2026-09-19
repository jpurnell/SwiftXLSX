import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct CellStyleTests {

    // MARK: - Default Init

    @Test("Default init")
    func testDefaultInit() {
        let style = CellStyle()
        #expect(style.font == Font())
        #expect(style.border == nil)
        #expect(style.alignment == nil)
        #expect(style.numberFormat == .general)
        #expect(style.fill == nil)
    }

    // MARK: - Custom Init

    @Test("Custom init")
    func testCustomInit() {
        let font = Font(name: "Arial", size: 14, bold: true)
        let border = Border.thin
        let alignment = Alignment(horizontal: .center)
        let fill = Fill.solid("FFFF0000")
        let style = CellStyle(font: font, border: border, alignment: alignment,
                              numberFormat: .currency, fill: fill)
        #expect(style.font == font)
        #expect(style.border == border)
        #expect(style.alignment == alignment)
        #expect(style.numberFormat == .currency)
        #expect(style.fill == fill)
    }

    // MARK: - Presets

    @Test("General preset")
    func testGeneralPreset() {
        let style = CellStyle.general
        #expect(style.font == Font())
        #expect(style.border == nil)
        #expect(style.numberFormat == .general)
        #expect(style.fill == nil)
    }

    @Test("Header preset")
    func testHeaderPreset() {
        let style = CellStyle.header
        #expect(style.font.bold)
        #expect(style.font.name == "Calibri")
        #expect(style.font.size.isEqual(to: 11))
    }

    @Test("Currency preset")
    func testCurrencyPreset() {
        #expect(CellStyle.currency.numberFormat == .currency)
    }

    @Test("Percent preset")
    func testPercentPreset() {
        #expect(CellStyle.percent.numberFormat == .percent)
    }

    @Test("Date preset")
    func testDatePreset() {
        #expect(CellStyle.date.numberFormat == .date)
    }

    @Test("Integer preset")
    func testIntegerPreset() {
        #expect(CellStyle.integer.numberFormat == .integer)
    }

    @Test("Input preset")
    func testInputPreset() {
        #expect(CellStyle.input.fill == .solid("FFFFFF00"))
    }

    @Test("Title preset")
    func testTitlePreset() {
        #expect(CellStyle.title.font.size.isEqual(to: 18))
        #expect(CellStyle.title.font.bold)
    }

    // MARK: - Builder Pattern

    @Test("With font")
    func testWithFont() {
        let original = CellStyle.general
        let modified = original.with(font: Font(name: "Arial", size: 14))
        #expect(modified.font.name == "Arial")
        #expect(modified.font.size.isEqual(to: 14))
        #expect(original.font == Font())
    }

    @Test("With border")
    func testWithBorder() {
        let modified = CellStyle.general.with(border: .thin)
        #expect(modified.border == .thin)
        #expect(CellStyle.general.border == nil)
    }

    @Test("With alignment")
    func testWithAlignment() {
        let alignment = Alignment(horizontal: .center, vertical: .bottom, wrapText: true)
        let modified = CellStyle.general.with(alignment: alignment)
        #expect(modified.alignment == alignment)
    }

    @Test("With number format")
    func testWithNumberFormat() {
        let modified = CellStyle.general.with(numberFormat: .currency)
        #expect(modified.numberFormat == .currency)
    }

    @Test("With fill")
    func testWithFill() {
        let modified = CellStyle.general.with(fill: .solid("FFFF0000"))
        #expect(modified.fill == .solid("FFFF0000"))
    }

    @Test("With nil border")
    func testWithNilBorder() {
        let styled = CellStyle(border: .thin)
        let cleared = styled.with(border: nil)
        #expect(cleared.border == nil)
    }

    @Test("With chaining")
    func testWithChaining() {
        let style = CellStyle.general
            .with(font: Font(bold: true))
            .with(border: .bottom)
            .with(numberFormat: .currency)
            .with(fill: .solid("FFFFFF00"))
        #expect(style.font.bold)
        #expect(style.border == .bottom)
        #expect(style.numberFormat == .currency)
        #expect(style.fill == .solid("FFFFFF00"))
    }

    // MARK: - Equatable

    @Test("Equatable")
    func testEquatable() {
        let a = CellStyle(font: Font(bold: true), numberFormat: .currency)
        let b = CellStyle(font: Font(bold: true), numberFormat: .currency)
        #expect(a == b)
    }

    @Test("Not equal")
    func testNotEqual() {
        #expect(CellStyle.general != CellStyle.header)
        #expect(CellStyle.currency != CellStyle.percent)
        #expect(CellStyle.general != CellStyle.input)
    }

    // MARK: - Hashable

    @Test("Hashable")
    func testHashable() {
        let set: Set<CellStyle> = [.general, .header, .general, .currency]
        #expect(set.count == 3)
    }

    // MARK: - Sendable

    @Test("Sendable")
    func testSendable() async {
        let style = CellStyle.general
        let _: any Sendable = style
        let received = await Task { style }.value
        #expect(received == CellStyle.general)
        #expect(received.numberFormat == .general)
    }
}
