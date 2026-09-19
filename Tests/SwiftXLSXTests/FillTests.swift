import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct FillTests {

    // MARK: - Default Init

    @Test("Default init pattern type is none")
    func testDefaultInitPatternTypeIsNone() {
        let fill = Fill()
        #expect(fill.patternType == .none)
    }

    @Test("Default init foreground color is nil")
    func testDefaultInitForegroundColorIsNil() {
        let fill = Fill()
        #expect(fill.foregroundColor == nil)
    }

    // MARK: - Static Factory

    @Test("Solid yellow")
    func testSolidYellow() {
        let fill = Fill.solid("FFFFFF00")
        #expect(fill.patternType == .solid)
        #expect(fill.foregroundColor == "FFFFFF00")
    }

    @Test("Solid red")
    func testSolidRed() {
        let fill = Fill.solid("FFFF0000")
        #expect(fill.patternType == .solid)
        #expect(fill.foregroundColor == "FFFF0000")
    }

    // MARK: - PatternType Raw Values

    @Test("Pattern type none raw value")
    func testPatternTypeNoneRawValue() {
        #expect(Fill.PatternType.none.rawValue == "none")
    }

    @Test("Pattern type solid raw value")
    func testPatternTypeSolidRawValue() {
        #expect(Fill.PatternType.solid.rawValue == "solid")
    }

    @Test("Pattern type gray125 raw value")
    func testPatternTypeGray125RawValue() {
        #expect(Fill.PatternType.gray125.rawValue == "gray125")
    }

    // MARK: - Equatable

    @Test("Equal fills are equal")
    func testEqualFillsAreEqual() {
        let a = Fill(patternType: .solid, foregroundColor: "FF0000FF")
        let b = Fill(patternType: .solid, foregroundColor: "FF0000FF")
        #expect(a == b)
    }

    @Test("Different pattern is not equal")
    func testDifferentPatternIsNotEqual() {
        let a = Fill(patternType: .none)
        let b = Fill(patternType: .solid)
        #expect(a != b)
    }

    @Test("Different color is not equal")
    func testDifferentColorIsNotEqual() {
        let a = Fill(patternType: .solid, foregroundColor: "FF000000")
        let b = Fill(patternType: .solid, foregroundColor: "FFFFFFFF")
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Set deduplication")
    func testSetDeduplication() {
        let fill = Fill.solid("FFFFFF00")
        var set: Set<Fill> = [fill, fill]
        set.insert(Fill.solid("FFFFFF00"))
        #expect(set.count == 1)
    }

    // MARK: - Custom Init

    @Test("Custom init gray125 with no color")
    func testCustomInitGray125WithNoColor() {
        let fill = Fill(patternType: .gray125)
        #expect(fill.patternType == .gray125)
        #expect(fill.foregroundColor == nil)
    }
}
