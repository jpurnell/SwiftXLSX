import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct DesignBundleTests {

    @Test("Default body font")
    func testDefaultBodyFont() {
        let bundle = DesignBundle.default
        #expect(bundle.bodyFont.name == "SF Mono")
        #expect(bundle.bodyFont.size.isEqual(to: 11))
        #expect(!(bundle.bodyFont.bold))
    }

    @Test("Default title font")
    func testDefaultTitleFont() {
        let bundle = DesignBundle.default
        #expect(bundle.titleFont.name == "SF Pro Display")
        #expect(bundle.titleFont.size.isEqual(to: 18))
        #expect(bundle.titleFont.bold)
    }

    @Test("Default label font")
    func testDefaultLabelFont() {
        let bundle = DesignBundle.default
        #expect(bundle.labelFont.name == "SF Mono")
        #expect(bundle.labelFont.size.isEqual(to: 11))
        #expect(bundle.labelFont.bold)
    }

    @Test("Default gutter columns")
    func testDefaultGutterColumns() {
        let bundle = DesignBundle.default
        #expect(bundle.gutterColumnCount == 2)
        #expect(bundle.gutterColumnWidth.isEqual(to: 2.85))
    }

    @Test("Default data column width")
    func testDefaultDataColumnWidth() {
        #expect(DesignBundle.default.dataColumnWidth.isEqual(to: 14.28))
    }

    @Test("Default title row height")
    func testDefaultTitleRowHeight() {
        #expect(DesignBundle.default.titleRowHeight.isEqual(to: 40.0))
    }

    @Test("Default sheet names")
    func testDefaultSheetNames() {
        let names = DesignBundle.default.defaultSheetNames
        #expect(names.count == 9)
        #expect(names.first == "Definitions")
        #expect(names[1] == "Sheet 1")
        #expect(names.last == "Sheet 8")
    }

    @Test("Custom bundle")
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
        #expect(bundle.bodyFont.name == "Courier")
        #expect(bundle.gutterColumnCount == 1)
        #expect(bundle.defaultSheetNames.count == 2)
    }

    @Test("Equatable")
    func testEquatable() {
        #expect(DesignBundle.default == DesignBundle.default)
        let custom = DesignBundle(gutterColumnCount: 3)
        #expect(custom != .default)
    }

    @Test("Sendable")
    func testSendable() async {
        let bundle = DesignBundle.default
        let _: any Sendable = bundle
        let received = await Task { bundle }.value
        #expect(received == DesignBundle.default)
        #expect(received.gutterColumnCount == 2)
    }
}
