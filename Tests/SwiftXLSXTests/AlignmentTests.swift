import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct AlignmentTests {

    // MARK: - Default Init

    @Test("Default init")
    func testDefaultInit() {
        let alignment = Alignment()
        #expect(alignment.horizontal == nil)
        #expect(alignment.vertical == nil)
        #expect(!(alignment.wrapText))
        #expect(alignment.indent == 0)
    }

    // MARK: - Custom Init

    @Test("Custom init all parameters")
    func testCustomInitAllParameters() {
        let alignment = Alignment(horizontal: .right, vertical: .top, wrapText: true, indent: 3)
        #expect(alignment.horizontal == .right)
        #expect(alignment.vertical == .top)
        #expect(alignment.wrapText)
        #expect(alignment.indent == 3)
    }

    // MARK: - Horizontal Raw Values

    @Test("Horizontal left raw value")
    func testHorizontalLeftRawValue() {
        #expect(Alignment.Horizontal.left.rawValue == "left")
    }

    @Test("Horizontal center raw value")
    func testHorizontalCenterRawValue() {
        #expect(Alignment.Horizontal.center.rawValue == "center")
    }

    @Test("Horizontal right raw value")
    func testHorizontalRightRawValue() {
        #expect(Alignment.Horizontal.right.rawValue == "right")
    }

    // MARK: - Vertical Raw Values

    @Test("Vertical top raw value")
    func testVerticalTopRawValue() {
        #expect(Alignment.Vertical.top.rawValue == "top")
    }

    @Test("Vertical center raw value")
    func testVerticalCenterRawValue() {
        #expect(Alignment.Vertical.center.rawValue == "center")
    }

    @Test("Vertical bottom raw value")
    func testVerticalBottomRawValue() {
        #expect(Alignment.Vertical.bottom.rawValue == "bottom")
    }

    // MARK: - WrapText

    @Test("Wrap text true")
    func testWrapTextTrue() {
        let alignment = Alignment(wrapText: true)
        #expect(alignment.wrapText)
    }

    // MARK: - Indent

    @Test("Indent greater than zero")
    func testIndentGreaterThanZero() {
        let alignment = Alignment(indent: 5)
        #expect(alignment.indent == 5)
    }

    // MARK: - Equatable

    @Test("Equal alignments")
    func testEqualAlignments() {
        let a = Alignment(horizontal: .center, vertical: .bottom, wrapText: true, indent: 2)
        let b = Alignment(horizontal: .center, vertical: .bottom, wrapText: true, indent: 2)
        #expect(a == b)
    }

    @Test("Unequal alignments")
    func testUnequalAlignments() {
        let a = Alignment(horizontal: .left)
        let b = Alignment(horizontal: .right)
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Hashable deduplication")
    func testHashableDeduplication() {
        let a = Alignment(horizontal: .center, vertical: .top, wrapText: false, indent: 1)
        let b = Alignment(horizontal: .center, vertical: .top, wrapText: false, indent: 1)
        let c = Alignment(horizontal: .left)
        let set: Set<Alignment> = [a, b, c]
        #expect(set.count == 2)
    }

    // MARK: - Combined

    @Test("Combined all properties")
    func testCombinedAllProperties() {
        var alignment = Alignment()
        alignment.horizontal = .right
        alignment.vertical = .center
        alignment.wrapText = true
        alignment.indent = 4
        #expect(alignment.horizontal == .right)
        #expect(alignment.vertical == .center)
        #expect(alignment.wrapText)
        #expect(alignment.indent == 4)
    }
}
