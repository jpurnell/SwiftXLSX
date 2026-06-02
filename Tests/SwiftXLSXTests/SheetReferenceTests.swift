import XCTest
@testable import SwiftXLSX

final class SheetReferenceTests: XCTestCase {

    // MARK: - Simple Sheet Name (single cell)

    func testSimpleSheetNameSingleCell() {
        let ref = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'Sheet1'!A1")
    }

    // MARK: - Sheet Name with Spaces

    func testSheetNameWithSpaces() {
        let ref = SheetReference(sheet: "My Sheet", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'My Sheet'!A1")
    }

    // MARK: - Sheet Name with Apostrophe

    func testSheetNameWithApostrophe() {
        let ref = SheetReference(sheet: "John's", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'John''s'!A1")
    }

    func testSheetNameWithMultipleApostrophes() {
        let ref = SheetReference(sheet: "John's Data's", cell: CellRef("B2"))
        XCTAssertEqual(ref.reference, "'John''s Data''s'!B2")
    }

    // MARK: - Range Reference

    func testRangeReference() {
        let range = CellRange(from: CellRef("A1"), to: CellRef("B10"))
        let ref = SheetReference(sheet: "Data", range: range)
        XCTAssertEqual(ref.reference, "'Data'!A1:B10")
    }

    func testRangeReferenceFromString() {
        let range = CellRange("A1:B10")
        let ref = SheetReference(sheet: "Data", range: range)
        XCTAssertEqual(ref.reference, "'Data'!A1:B10")
    }

    // MARK: - Single Cell via cell init (1x1 range)

    func testCellInitCreatesRange() {
        let ref = SheetReference(sheet: "Sheet1", cell: CellRef("C5"))
        XCTAssertEqual(ref.range.start.reference, "C5")
        XCTAssertEqual(ref.range.end.reference, "C5")
    }

    func testSingleCellReferenceDoesNotShowRange() {
        let ref = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'Sheet1'!A1")
        XCTAssertFalse(ref.reference.contains(":"))
    }

    // MARK: - Equatable

    func testEquatableSameConstruction() {
        let ref1 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let ref2 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        XCTAssertEqual(ref1, ref2)
    }

    func testEquatableDifferentConstruction() {
        let cellRef = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let range = CellRange(from: CellRef("A1"), to: CellRef("A1"))
        let rangeRef = SheetReference(sheet: "Sheet1", range: range)
        XCTAssertEqual(cellRef, rangeRef)
    }

    func testNotEqualDifferentSheet() {
        let ref1 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let ref2 = SheetReference(sheet: "Sheet2", cell: CellRef("A1"))
        XCTAssertNotEqual(ref1, ref2)
    }

    func testNotEqualDifferentCell() {
        let ref1 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let ref2 = SheetReference(sheet: "Sheet1", cell: CellRef("B2"))
        XCTAssertNotEqual(ref1, ref2)
    }

    // MARK: - Hashable

    func testHashableInSet() {
        let ref1 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let ref2 = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        let ref3 = SheetReference(sheet: "Sheet2", cell: CellRef("A1"))

        var set = Set<SheetReference>()
        set.insert(ref1)
        set.insert(ref2)
        set.insert(ref3)

        XCTAssertEqual(set.count, 2)
    }

    func testHashableDifferentConstructionSameHash() {
        let cellRef = SheetReference(sheet: "Data", cell: CellRef("A1"))
        let range = CellRange(from: CellRef("A1"), to: CellRef("A1"))
        let rangeRef = SheetReference(sheet: "Data", range: range)

        var set = Set<SheetReference>()
        set.insert(cellRef)
        set.insert(rangeRef)

        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Stored Properties

    func testSheetNameStored() {
        let ref = SheetReference(sheet: "My Sheet", cell: CellRef("A1"))
        XCTAssertEqual(ref.sheetName, "My Sheet")
    }

    func testRangeStored() {
        let range = CellRange(from: CellRef("A1"), to: CellRef("D10"))
        let ref = SheetReference(sheet: "Data", range: range)
        XCTAssertEqual(ref.range.start.reference, "A1")
        XCTAssertEqual(ref.range.end.reference, "D10")
    }

    // MARK: - Edge Cases

    func testSheetNameStartingWithDigit() {
        let ref = SheetReference(sheet: "2024 Data", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'2024 Data'!A1")
    }

    func testSheetNameWithSpecialChars() {
        let ref = SheetReference(sheet: "Revenue & Costs", cell: CellRef("A1"))
        XCTAssertEqual(ref.reference, "'Revenue & Costs'!A1")
    }

    func testMultiColumnRange() {
        let range = CellRange(from: CellRef("AA1"), to: CellRef("AZ100"))
        let ref = SheetReference(sheet: "Wide", range: range)
        XCTAssertEqual(ref.reference, "'Wide'!AA1:AZ100")
    }
}
