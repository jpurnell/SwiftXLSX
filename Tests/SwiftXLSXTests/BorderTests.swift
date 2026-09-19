import Testing
import Foundation
@testable import SwiftXLSX

@Suite
struct BorderTests {

    // MARK: - Default Init

    @Test("Default init produces all nil edges")
    func testDefaultInitProducesAllNilEdges() {
        let border = Border()
        #expect(border.top == nil)
        #expect(border.bottom == nil)
        #expect(border.left == nil)
        #expect(border.right == nil)
    }

    // MARK: - Custom Init

    @Test("Custom init with specific edges")
    func testCustomInitWithSpecificEdges() {
        let edge = Border.BorderEdge(style: .medium, color: "FFFF0000")
        let border = Border(top: edge, right: edge)
        #expect(border.top == edge)
        #expect(border.bottom == nil)
        #expect(border.left == nil)
        #expect(border.right == edge)
    }

    @Test("Custom init all edges")
    func testCustomInitAllEdges() {
        let topEdge = Border.BorderEdge(style: .thick, color: "FF00FF00")
        let bottomEdge = Border.BorderEdge(style: .dashed, color: "FF0000FF")
        let leftEdge = Border.BorderEdge(style: .dotted, color: "FFFFFFFF")
        let rightEdge = Border.BorderEdge(style: .double, color: "FF808080")
        let border = Border(top: topEdge, bottom: bottomEdge, left: leftEdge, right: rightEdge)
        #expect(border.top == topEdge)
        #expect(border.bottom == bottomEdge)
        #expect(border.left == leftEdge)
        #expect(border.right == rightEdge)
    }

    // MARK: - Thin Preset

    @Test("Thin preset has all four edges")
    func testThinPresetHasAllFourEdges() {
        let border = Border.thin
        #expect(border.top?.style == .thin)
        #expect(border.bottom?.style == .thin)
        #expect(border.left?.style == .thin)
        #expect(border.right?.style == .thin)
    }

    @Test("Thin preset edges are thin black")
    func testThinPresetEdgesAreThinBlack() {
        let border = Border.thin
        let expected = Border.BorderEdge(style: .thin, color: "FF000000")
        #expect(border.top == expected)
        #expect(border.bottom == expected)
        #expect(border.left == expected)
        #expect(border.right == expected)
    }

    // MARK: - Bottom Preset

    @Test("Bottom preset has only bottom edge")
    func testBottomPresetHasOnlyBottomEdge() {
        let border = Border.bottom
        #expect(border.top == nil)
        #expect(border.bottom?.style == .thin)
        #expect(border.left == nil)
        #expect(border.right == nil)
    }

    @Test("Bottom preset edge is thin black")
    func testBottomPresetEdgeIsThinBlack() {
        let border = Border.bottom
        let expected = Border.BorderEdge(style: .thin, color: "FF000000")
        #expect(border.bottom == expected)
    }

    // MARK: - BorderEdge Defaults

    @Test("Border edge default init")
    func testBorderEdgeDefaultInit() {
        let edge = Border.BorderEdge()
        #expect(edge.style == .thin)
        #expect(edge.color == "FF000000")
    }

    @Test("Border edge custom style and color")
    func testBorderEdgeCustomStyleAndColor() {
        let edge = Border.BorderEdge(style: .thick, color: "FFAABBCC")
        #expect(edge.style == .thick)
        #expect(edge.color == "FFAABBCC")
    }

    // MARK: - BorderEdge.Style Cases

    @Test("All border edge style cases exist")
    func testAllBorderEdgeStyleCasesExist() {
        let styles: [Border.BorderEdge.Style] = [.thin, .medium, .thick, .double, .dashed, .dotted]
        #expect(styles.count == 6)

        #expect(Border.BorderEdge.Style.thin.rawValue == "thin")
        #expect(Border.BorderEdge.Style.medium.rawValue == "medium")
        #expect(Border.BorderEdge.Style.thick.rawValue == "thick")
        #expect(Border.BorderEdge.Style.double.rawValue == "double")
        #expect(Border.BorderEdge.Style.dashed.rawValue == "dashed")
        #expect(Border.BorderEdge.Style.dotted.rawValue == "dotted")
    }

    // MARK: - Equatable

    @Test("Equal borders are equal")
    func testEqualBordersAreEqual() {
        let edge = Border.BorderEdge(style: .medium, color: "FF112233")
        let a = Border(top: edge, bottom: edge)
        let b = Border(top: edge, bottom: edge)
        #expect(a == b)
    }

    @Test("Different borders are not equal")
    func testDifferentBordersAreNotEqual() {
        let edgeA = Border.BorderEdge(style: .thin, color: "FF000000")
        let edgeB = Border.BorderEdge(style: .thick, color: "FF000000")
        let a = Border(top: edgeA)
        let b = Border(top: edgeB)
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Hashable deduplication")
    func testHashableDeduplication() {
        let border = Border.thin
        let set: Set<Border> = [border, border, Border.thin]
        #expect(set.count == 1)
    }

    @Test("Hashable different borders in set")
    func testHashableDifferentBordersInSet() {
        let set: Set<Border> = [Border.thin, Border.bottom, Border()]
        #expect(set.count == 3)
    }

    // MARK: - Mixed Edges

    @Test("Mixed edges some nil some set")
    func testMixedEdgesSomeNilSomeSet() {
        let thick = Border.BorderEdge(style: .thick, color: "FFFF0000")
        let dashed = Border.BorderEdge(style: .dashed, color: "FF00FF00")
        var border = Border(top: thick, left: dashed)
        #expect(border.top?.style == .thick)
        #expect(border.bottom == nil)
        #expect(border.left?.style == .dashed)
        #expect(border.right == nil)

        border.bottom = Border.BorderEdge(style: .dotted, color: "FF0000FF")
        #expect(border.bottom?.color == "FF0000FF")
        #expect(border.bottom?.style == .dotted)
    }
}
