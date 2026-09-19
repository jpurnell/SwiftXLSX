import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct NumberFormatTests {

    // MARK: - Custom Init

    @Test("Custom init stores format string")
    func testCustomInitStoresFormatString() {
        let format = NumberFormat(formatString: "0.000")
        #expect(format.formatString == "0.000")
    }

    @Test("Custom init with conditional format")
    func testCustomInitWithConditionalFormat() {
        let format = NumberFormat(formatString: "#,##0.00;[Red]-#,##0.00")
        #expect(format.formatString == "#,##0.00;[Red]-#,##0.00")
    }

    // MARK: - Presets

    @Test("General preset")
    func testGeneralPreset() {
        #expect(NumberFormat.general.formatString == "General")
    }

    @Test("Currency preset")
    func testCurrencyPreset() {
        #expect(NumberFormat.currency.formatString == "$#,##0.00")
    }

    @Test("Percent preset")
    func testPercentPreset() {
        #expect(NumberFormat.percent.formatString == "0.00%")
    }

    @Test("Date preset")
    func testDatePreset() {
        #expect(NumberFormat.date.formatString == "mm/dd/yyyy")
    }

    @Test("Integer preset")
    func testIntegerPreset() {
        #expect(NumberFormat.integer.formatString == "#,##0")
    }

    @Test("Accounting preset")
    func testAccountingPreset() {
        #expect(NumberFormat.accounting.formatString == "_($* #,##0.00_)")
    }

    // MARK: - Equatable

    @Test("Equal formats are equal")
    func testEqualFormatsAreEqual() {
        let a = NumberFormat(formatString: "0.00%")
        let b = NumberFormat(formatString: "0.00%")
        #expect(a == b)
    }

    @Test("Different formats are not equal")
    func testDifferentFormatsAreNotEqual() {
        let a = NumberFormat(formatString: "0.00%")
        let b = NumberFormat(formatString: "#,##0")
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Set deduplication")
    func testSetDeduplication() {
        let a = NumberFormat(formatString: "#,##0.00")
        let b = NumberFormat(formatString: "#,##0.00")
        let set: Set<NumberFormat> = [a, b]
        #expect(set.count == 1)
    }

    @Test("Dictionary key")
    func testDictionaryKey() {
        let format = NumberFormat(formatString: "mm/dd/yyyy")
        let dict: [NumberFormat: Int] = [format: 14]
        #expect(dict[format] == 14)
    }

    // MARK: - Sendable

    @Test("Sendable conformance")
    func testSendableConformance() async {
        let format = NumberFormat.general
        let _: any Sendable = format
        let received = await Task { format }.value
        #expect(received == NumberFormat.general)
        #expect(received.formatString == "General")
    }
}
