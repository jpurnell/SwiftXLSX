import XCTest
@testable import SwiftXLSX

final class DesignBundleTests: XCTestCase {

    func testDefaultBodyFont() {
        let bundle = DesignBundle.default
        XCTAssertEqual(bundle.bodyFont.name, "SF Mono")
        XCTAssertEqual(bundle.bodyFont.size, 11)
        XCTAssertFalse(bundle.bodyFont.bold)
    }

    func testDefaultTitleFont() {
        let bundle = DesignBundle.default
        XCTAssertEqual(bundle.titleFont.name, "SF Pro Display")
        XCTAssertEqual(bundle.titleFont.size, 18)
        XCTAssertTrue(bundle.titleFont.bold)
    }

    func testDefaultLabelFont() {
        let bundle = DesignBundle.default
        XCTAssertEqual(bundle.labelFont.name, "SF Mono")
        XCTAssertEqual(bundle.labelFont.size, 11)
        XCTAssertTrue(bundle.labelFont.bold)
    }

    func testDefaultGutterColumns() {
        let bundle = DesignBundle.default
        XCTAssertEqual(bundle.gutterColumnCount, 2)
        XCTAssertEqual(bundle.gutterColumnWidth, 2.85)
    }

    func testDefaultDataColumnWidth() {
        XCTAssertEqual(DesignBundle.default.dataColumnWidth, 14.28)
    }

    func testDefaultTitleRowHeight() {
        XCTAssertEqual(DesignBundle.default.titleRowHeight, 40.0)
    }

    func testDefaultSheetNames() {
        let names = DesignBundle.default.defaultSheetNames
        XCTAssertEqual(names.count, 9)
        XCTAssertEqual(names.first, "Definitions")
        XCTAssertEqual(names[1], "Sheet 1")
        XCTAssertEqual(names.last, "Sheet 8")
    }

    func testCustomBundle() {
        let bundle = DesignBundle(
            bodyFont: Font(name: "Courier", size: 12),
            titleFont: Font(name: "Helvetica", size: 24, bold: true),
            labelFont: Font(name: "Courier", size: 12, bold: true),
            gutterColumnCount: 1,
            gutterColumnWidth: 3.0,
            dataColumnWidth: 12.0,
            titleRowHeight: 30.0,
            defaultSheetNames: ["Data", "Summary"]
        )
        XCTAssertEqual(bundle.bodyFont.name, "Courier")
        XCTAssertEqual(bundle.gutterColumnCount, 1)
        XCTAssertEqual(bundle.defaultSheetNames.count, 2)
    }

    func testEquatable() {
        XCTAssertEqual(DesignBundle.default, DesignBundle.default)
        let custom = DesignBundle(gutterColumnCount: 3)
        XCTAssertNotEqual(custom, .default)
    }

    func testSendable() {
        let _: any Sendable = DesignBundle.default
    }
}
