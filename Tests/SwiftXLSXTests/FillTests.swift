import XCTest
@testable import SwiftXLSX

final class FillTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInitPatternTypeIsNone() {
        let fill = Fill()
        XCTAssertEqual(fill.patternType, .none)
    }

    func testDefaultInitForegroundColorIsNil() {
        let fill = Fill()
        XCTAssertNil(fill.foregroundColor)
    }

    // MARK: - Static Factory

    func testSolidYellow() {
        let fill = Fill.solid("FFFFFF00")
        XCTAssertEqual(fill.patternType, .solid)
        XCTAssertEqual(fill.foregroundColor, "FFFFFF00")
    }

    func testSolidRed() {
        let fill = Fill.solid("FFFF0000")
        XCTAssertEqual(fill.patternType, .solid)
        XCTAssertEqual(fill.foregroundColor, "FFFF0000")
    }

    // MARK: - PatternType Raw Values

    func testPatternTypeNoneRawValue() {
        XCTAssertEqual(Fill.PatternType.none.rawValue, "none")
    }

    func testPatternTypeSolidRawValue() {
        XCTAssertEqual(Fill.PatternType.solid.rawValue, "solid")
    }

    func testPatternTypeGray125RawValue() {
        XCTAssertEqual(Fill.PatternType.gray125.rawValue, "gray125")
    }

    // MARK: - Equatable

    func testEqualFillsAreEqual() {
        let a = Fill(patternType: .solid, foregroundColor: "FF0000FF")
        let b = Fill(patternType: .solid, foregroundColor: "FF0000FF")
        XCTAssertEqual(a, b)
    }

    func testDifferentPatternIsNotEqual() {
        let a = Fill(patternType: .none)
        let b = Fill(patternType: .solid)
        XCTAssertNotEqual(a, b)
    }

    func testDifferentColorIsNotEqual() {
        let a = Fill(patternType: .solid, foregroundColor: "FF000000")
        let b = Fill(patternType: .solid, foregroundColor: "FFFFFFFF")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testSetDeduplication() {
        let fill = Fill.solid("FFFFFF00")
        var set: Set<Fill> = [fill, fill]
        set.insert(Fill.solid("FFFFFF00"))
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Custom Init

    func testCustomInitGray125WithNoColor() {
        let fill = Fill(patternType: .gray125)
        XCTAssertEqual(fill.patternType, .gray125)
        XCTAssertNil(fill.foregroundColor)
    }
}
