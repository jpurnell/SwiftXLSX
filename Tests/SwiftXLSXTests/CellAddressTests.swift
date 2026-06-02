import XCTest
@testable import SwiftXLSX

final class CellAddressTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithSheetAndCellRef() {
        let ref = CellRef("B5")
        let addr = CellAddress(sheet: "Sheet1", cell: ref)

        XCTAssertEqual(addr.sheet, "Sheet1")
        XCTAssertEqual(addr.cell, ref)
        XCTAssertEqual(addr.cell.column, 2)
        XCTAssertEqual(addr.cell.row, 5)
    }

    func testConvenienceInitParsesRefString() {
        let addr = CellAddress(sheet: "Data", ref: "A1")

        XCTAssertEqual(addr.sheet, "Data")
        XCTAssertEqual(addr.cell.column, 1)
        XCTAssertEqual(addr.cell.row, 1)
    }

    func testConvenienceInitParsesAbsoluteRef() {
        let addr = CellAddress(sheet: "Summary", ref: "$C$10")

        XCTAssertEqual(addr.sheet, "Summary")
        XCTAssertEqual(addr.cell.column, 3)
        XCTAssertEqual(addr.cell.row, 10)
        XCTAssertTrue(addr.cell.absoluteColumn)
        XCTAssertTrue(addr.cell.absoluteRow)
    }

    func testConvenienceInitParsesMultiLetterColumn() {
        let addr = CellAddress(sheet: "Sheet1", ref: "AA100")

        XCTAssertEqual(addr.cell.column, 27)
        XCTAssertEqual(addr.cell.row, 100)
    }

    // MARK: - Equality

    func testEqualAddresses() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet1", cell: CellRef("A1"))

        XCTAssertEqual(a, b)
    }

    func testDifferentSheetNotEqual() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet2", ref: "A1")

        XCTAssertNotEqual(a, b)
    }

    func testDifferentCellNotEqual() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet1", ref: "B2")

        XCTAssertNotEqual(a, b)
    }

    func testDifferentSheetAndCellNotEqual() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet2", ref: "B2")

        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashing

    func testEqualAddressesHaveSameHash() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet1", cell: CellRef("A1"))

        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testCanBeUsedAsSetElement() {
        let a = CellAddress(sheet: "Sheet1", ref: "A1")
        let b = CellAddress(sheet: "Sheet1", ref: "A1")
        let c = CellAddress(sheet: "Sheet1", ref: "B2")

        let set: Set<CellAddress> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }

    func testCanBeUsedAsDictionaryKey() {
        let addr = CellAddress(sheet: "Sheet1", ref: "A1")
        var dict: [CellAddress: String] = [:]
        dict[addr] = "hello"

        XCTAssertEqual(dict[CellAddress(sheet: "Sheet1", ref: "A1")], "hello")
    }

    // MARK: - Edge Cases

    func testEmptySheetName() {
        let addr = CellAddress(sheet: "", ref: "A1")

        XCTAssertEqual(addr.sheet, "")
        XCTAssertEqual(addr.cell.column, 1)
        XCTAssertEqual(addr.cell.row, 1)
    }

    func testSheetNameWithSpaces() {
        let addr = CellAddress(sheet: "My Sheet", ref: "A1")

        XCTAssertEqual(addr.sheet, "My Sheet")
    }

    func testSheetNameWithSpecialCharacters() {
        let addr = CellAddress(sheet: "Q1'24 Data", ref: "Z99")

        XCTAssertEqual(addr.sheet, "Q1'24 Data")
        XCTAssertEqual(addr.cell.column, 26)
        XCTAssertEqual(addr.cell.row, 99)
    }
}
