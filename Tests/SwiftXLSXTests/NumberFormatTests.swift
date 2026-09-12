import XCTest
@testable import SwiftXLSX

final class NumberFormatTests: XCTestCase {

    // MARK: - Custom Init

    func testCustomInitStoresFormatString() {
        let format = NumberFormat(formatString: "0.000")
        XCTAssertEqual(format.formatString, "0.000")
    }

    func testCustomInitWithConditionalFormat() {
        let format = NumberFormat(formatString: "#,##0.00;[Red]-#,##0.00")
        XCTAssertEqual(format.formatString, "#,##0.00;[Red]-#,##0.00")
    }

    // MARK: - Presets

    func testGeneralPreset() {
        XCTAssertEqual(NumberFormat.general.formatString, "General")
    }

    func testCurrencyPreset() {
        XCTAssertEqual(NumberFormat.currency.formatString, "$#,##0.00")
    }

    func testPercentPreset() {
        XCTAssertEqual(NumberFormat.percent.formatString, "0.00%")
    }

    func testDatePreset() {
        XCTAssertEqual(NumberFormat.date.formatString, "mm/dd/yyyy")
    }

    func testIntegerPreset() {
        XCTAssertEqual(NumberFormat.integer.formatString, "#,##0")
    }

    func testAccountingPreset() {
        XCTAssertEqual(NumberFormat.accounting.formatString, "_($* #,##0.00_)")
    }

    // MARK: - Equatable

    func testEqualFormatsAreEqual() {
        let a = NumberFormat(formatString: "0.00%")
        let b = NumberFormat(formatString: "0.00%")
        XCTAssertEqual(a, b)
    }

    func testDifferentFormatsAreNotEqual() {
        let a = NumberFormat(formatString: "0.00%")
        let b = NumberFormat(formatString: "#,##0")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testSetDeduplication() {
        let a = NumberFormat(formatString: "#,##0.00")
        let b = NumberFormat(formatString: "#,##0.00")
        let set: Set<NumberFormat> = [a, b]
        XCTAssertEqual(set.count, 1)
    }

    func testDictionaryKey() {
        let format = NumberFormat(formatString: "mm/dd/yyyy")
        let dict: [NumberFormat: Int] = [format: 14]
        XCTAssertEqual(dict[format], 14)
    }

    // MARK: - Sendable

    func testSendableConformance() {
        let format = NumberFormat.general
        let _: any Sendable = format
    }
}
