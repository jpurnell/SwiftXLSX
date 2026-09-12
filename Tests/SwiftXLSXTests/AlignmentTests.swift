import XCTest
@testable import SwiftXLSX

final class AlignmentTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInit() {
        let alignment = Alignment()
        XCTAssertNil(alignment.horizontal)
        XCTAssertNil(alignment.vertical)
        XCTAssertFalse(alignment.wrapText)
        XCTAssertEqual(alignment.indent, 0)
    }

    // MARK: - Custom Init

    func testCustomInitAllParameters() {
        let alignment = Alignment(horizontal: .right, vertical: .top, wrapText: true, indent: 3)
        XCTAssertEqual(alignment.horizontal, .right)
        XCTAssertEqual(alignment.vertical, .top)
        XCTAssertTrue(alignment.wrapText)
        XCTAssertEqual(alignment.indent, 3)
    }

    // MARK: - Horizontal Raw Values

    func testHorizontalLeftRawValue() {
        XCTAssertEqual(Alignment.Horizontal.left.rawValue, "left")
    }

    func testHorizontalCenterRawValue() {
        XCTAssertEqual(Alignment.Horizontal.center.rawValue, "center")
    }

    func testHorizontalRightRawValue() {
        XCTAssertEqual(Alignment.Horizontal.right.rawValue, "right")
    }

    // MARK: - Vertical Raw Values

    func testVerticalTopRawValue() {
        XCTAssertEqual(Alignment.Vertical.top.rawValue, "top")
    }

    func testVerticalCenterRawValue() {
        XCTAssertEqual(Alignment.Vertical.center.rawValue, "center")
    }

    func testVerticalBottomRawValue() {
        XCTAssertEqual(Alignment.Vertical.bottom.rawValue, "bottom")
    }

    // MARK: - WrapText

    func testWrapTextTrue() {
        let alignment = Alignment(wrapText: true)
        XCTAssertTrue(alignment.wrapText)
    }

    // MARK: - Indent

    func testIndentGreaterThanZero() {
        let alignment = Alignment(indent: 5)
        XCTAssertEqual(alignment.indent, 5)
    }

    // MARK: - Equatable

    func testEqualAlignments() {
        let a = Alignment(horizontal: .center, vertical: .bottom, wrapText: true, indent: 2)
        let b = Alignment(horizontal: .center, vertical: .bottom, wrapText: true, indent: 2)
        XCTAssertEqual(a, b)
    }

    func testUnequalAlignments() {
        let a = Alignment(horizontal: .left)
        let b = Alignment(horizontal: .right)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testHashableDeduplication() {
        let a = Alignment(horizontal: .center, vertical: .top, wrapText: false, indent: 1)
        let b = Alignment(horizontal: .center, vertical: .top, wrapText: false, indent: 1)
        let c = Alignment(horizontal: .left)
        let set: Set<Alignment> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Combined

    func testCombinedAllProperties() {
        var alignment = Alignment()
        alignment.horizontal = .right
        alignment.vertical = .center
        alignment.wrapText = true
        alignment.indent = 4
        XCTAssertEqual(alignment.horizontal, .right)
        XCTAssertEqual(alignment.vertical, .center)
        XCTAssertTrue(alignment.wrapText)
        XCTAssertEqual(alignment.indent, 4)
    }
}
