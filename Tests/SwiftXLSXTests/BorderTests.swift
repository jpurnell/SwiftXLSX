import XCTest
@testable import SwiftXLSX

final class BorderTests: XCTestCase {

    // MARK: - Default Init

    func testDefaultInitProducesAllNilEdges() {
        let border = Border()
        XCTAssertNil(border.top)
        XCTAssertNil(border.bottom)
        XCTAssertNil(border.left)
        XCTAssertNil(border.right)
    }

    // MARK: - Custom Init

    func testCustomInitWithSpecificEdges() {
        let edge = Border.BorderEdge(style: .medium, color: "FFFF0000")
        let border = Border(top: edge, right: edge)
        XCTAssertEqual(border.top, edge)
        XCTAssertNil(border.bottom)
        XCTAssertNil(border.left)
        XCTAssertEqual(border.right, edge)
    }

    func testCustomInitAllEdges() {
        let topEdge = Border.BorderEdge(style: .thick, color: "FF00FF00")
        let bottomEdge = Border.BorderEdge(style: .dashed, color: "FF0000FF")
        let leftEdge = Border.BorderEdge(style: .dotted, color: "FFFFFFFF")
        let rightEdge = Border.BorderEdge(style: .double, color: "FF808080")
        let border = Border(top: topEdge, bottom: bottomEdge, left: leftEdge, right: rightEdge)
        XCTAssertEqual(border.top, topEdge)
        XCTAssertEqual(border.bottom, bottomEdge)
        XCTAssertEqual(border.left, leftEdge)
        XCTAssertEqual(border.right, rightEdge)
    }

    // MARK: - Thin Preset

    func testThinPresetHasAllFourEdges() {
        let border = Border.thin
        XCTAssertNotNil(border.top)
        XCTAssertNotNil(border.bottom)
        XCTAssertNotNil(border.left)
        XCTAssertNotNil(border.right)
    }

    func testThinPresetEdgesAreThinBlack() {
        let border = Border.thin
        let expected = Border.BorderEdge(style: .thin, color: "FF000000")
        XCTAssertEqual(border.top, expected)
        XCTAssertEqual(border.bottom, expected)
        XCTAssertEqual(border.left, expected)
        XCTAssertEqual(border.right, expected)
    }

    // MARK: - Bottom Preset

    func testBottomPresetHasOnlyBottomEdge() {
        let border = Border.bottom
        XCTAssertNil(border.top)
        XCTAssertNotNil(border.bottom)
        XCTAssertNil(border.left)
        XCTAssertNil(border.right)
    }

    func testBottomPresetEdgeIsThinBlack() {
        let border = Border.bottom
        let expected = Border.BorderEdge(style: .thin, color: "FF000000")
        XCTAssertEqual(border.bottom, expected)
    }

    // MARK: - BorderEdge Defaults

    func testBorderEdgeDefaultInit() {
        let edge = Border.BorderEdge()
        XCTAssertEqual(edge.style, .thin)
        XCTAssertEqual(edge.color, "FF000000")
    }

    func testBorderEdgeCustomStyleAndColor() {
        let edge = Border.BorderEdge(style: .thick, color: "FFAABBCC")
        XCTAssertEqual(edge.style, .thick)
        XCTAssertEqual(edge.color, "FFAABBCC")
    }

    // MARK: - BorderEdge.Style Cases

    func testAllBorderEdgeStyleCasesExist() {
        let styles: [Border.BorderEdge.Style] = [.thin, .medium, .thick, .double, .dashed, .dotted]
        XCTAssertEqual(styles.count, 6)

        XCTAssertEqual(Border.BorderEdge.Style.thin.rawValue, "thin")
        XCTAssertEqual(Border.BorderEdge.Style.medium.rawValue, "medium")
        XCTAssertEqual(Border.BorderEdge.Style.thick.rawValue, "thick")
        XCTAssertEqual(Border.BorderEdge.Style.double.rawValue, "double")
        XCTAssertEqual(Border.BorderEdge.Style.dashed.rawValue, "dashed")
        XCTAssertEqual(Border.BorderEdge.Style.dotted.rawValue, "dotted")
    }

    // MARK: - Equatable

    func testEqualBordersAreEqual() {
        let edge = Border.BorderEdge(style: .medium, color: "FF112233")
        let a = Border(top: edge, bottom: edge)
        let b = Border(top: edge, bottom: edge)
        XCTAssertEqual(a, b)
    }

    func testDifferentBordersAreNotEqual() {
        let edgeA = Border.BorderEdge(style: .thin, color: "FF000000")
        let edgeB = Border.BorderEdge(style: .thick, color: "FF000000")
        let a = Border(top: edgeA)
        let b = Border(top: edgeB)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testHashableDeduplication() {
        let border = Border.thin
        let set: Set<Border> = [border, border, Border.thin]
        XCTAssertEqual(set.count, 1)
    }

    func testHashableDifferentBordersInSet() {
        let set: Set<Border> = [Border.thin, Border.bottom, Border()]
        XCTAssertEqual(set.count, 3)
    }

    // MARK: - Mixed Edges

    func testMixedEdgesSomeNilSomeSet() {
        let thick = Border.BorderEdge(style: .thick, color: "FFFF0000")
        let dashed = Border.BorderEdge(style: .dashed, color: "FF00FF00")
        var border = Border(top: thick, left: dashed)
        XCTAssertEqual(border.top?.style, .thick)
        XCTAssertNil(border.bottom)
        XCTAssertEqual(border.left?.style, .dashed)
        XCTAssertNil(border.right)

        border.bottom = Border.BorderEdge(style: .dotted, color: "FF0000FF")
        XCTAssertNotNil(border.bottom)
        XCTAssertEqual(border.bottom?.style, .dotted)
    }
}
