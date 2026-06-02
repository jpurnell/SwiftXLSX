import Testing
@testable import SwiftXLSX

@Suite("CellRef Tests")
struct CellRefTests {

    // MARK: - Simple Parsing

    @Test("Parse simple ref A1")
    func parseA1() {
        let ref = CellRef("A1")
        #expect(ref.column == 1)
        #expect(ref.row == 1)
    }

    @Test("Parse simple ref B5")
    func parseB5() {
        let ref = CellRef("B5")
        #expect(ref.column == 2)
        #expect(ref.row == 5)
    }

    @Test("Parse simple ref Z26")
    func parseZ26() {
        let ref = CellRef("Z26")
        #expect(ref.column == 26)
        #expect(ref.row == 26)
    }

    // MARK: - Multi-Letter Columns

    @Test("Parse AA1 -> column 27")
    func parseAA1() {
        let ref = CellRef("AA1")
        #expect(ref.column == 27)
        #expect(ref.row == 1)
    }

    @Test("Parse AZ1 -> column 52")
    func parseAZ1() {
        let ref = CellRef("AZ1")
        #expect(ref.column == 52)
        #expect(ref.row == 1)
    }

    @Test("Parse BA1 -> column 53")
    func parseBA1() {
        let ref = CellRef("BA1")
        #expect(ref.column == 53)
        #expect(ref.row == 1)
    }

    @Test("Parse XFD1 -> column 16384 (Excel max)")
    func parseXFD1() {
        let ref = CellRef("XFD1")
        #expect(ref.column == 16384)
        #expect(ref.row == 1)
    }

    // MARK: - Absolute References ($ Parsing)

    @Test("Parse $A$1 -> both absolute")
    func parseDollarADollar1() {
        let ref = CellRef("$A$1")
        #expect(ref.column == 1)
        #expect(ref.row == 1)
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
    }

    @Test("Parse A$1 -> only row absolute")
    func parseADollar1() {
        let ref = CellRef("A$1")
        #expect(ref.column == 1)
        #expect(ref.row == 1)
        #expect(ref.absoluteColumn == false)
        #expect(ref.absoluteRow == true)
    }

    @Test("Parse $A1 -> only column absolute")
    func parseDollarA1() {
        let ref = CellRef("$A1")
        #expect(ref.column == 1)
        #expect(ref.row == 1)
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == false)
    }

    @Test("Parse A1 -> neither absolute")
    func parseA1NoAbsolute() {
        let ref = CellRef("A1")
        #expect(ref.absoluteColumn == false)
        #expect(ref.absoluteRow == false)
    }

    @Test("Parse $AA$100 -> both absolute, multi-letter column")
    func parseDollarAADollar100() {
        let ref = CellRef("$AA$100")
        #expect(ref.column == 27)
        #expect(ref.row == 100)
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
    }

    // MARK: - Round-Trip: String -> CellRef -> String

    @Test("Round-trip $B$5")
    func roundTripDollarB5() {
        let ref = CellRef("$B$5")
        #expect(ref.reference == "$B$5")
    }

    @Test("Round-trip A1")
    func roundTripA1() {
        let ref = CellRef("A1")
        #expect(ref.reference == "A1")
    }

    @Test("Round-trip $A1")
    func roundTripDollarA1() {
        let ref = CellRef("$A1")
        #expect(ref.reference == "$A1")
    }

    @Test("Round-trip A$1")
    func roundTripADollar1() {
        let ref = CellRef("A$1")
        #expect(ref.reference == "A$1")
    }

    @Test("Round-trip AA100")
    func roundTripAA100() {
        let ref = CellRef("AA100")
        #expect(ref.reference == "AA100")
    }

    // MARK: - Round-Trip: init(column:row:) -> reference

    @Test("init(column:3, row:7) -> C7")
    func initColumnRow() {
        let ref = CellRef(column: 3, row: 7)
        #expect(ref.reference == "C7")
        #expect(ref.column == 3)
        #expect(ref.row == 7)
    }

    @Test("init(column:3, row:7, absoluteColumn:true, absoluteRow:true) -> $C$7")
    func initColumnRowAbsolute() {
        let ref = CellRef(column: 3, row: 7, absoluteColumn: true, absoluteRow: true)
        #expect(ref.reference == "$C$7")
        #expect(ref.column == 3)
        #expect(ref.row == 7)
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
    }

    @Test("init(column:1, row:1) -> A1")
    func initColumn1Row1() {
        let ref = CellRef(column: 1, row: 1)
        #expect(ref.reference == "A1")
        #expect(ref.absoluteColumn == false)
        #expect(ref.absoluteRow == false)
    }

    @Test("init(column:26, row:1) -> Z1")
    func initColumn26() {
        let ref = CellRef(column: 26, row: 1)
        #expect(ref.reference == "Z1")
    }

    @Test("init(column:27, row:1) -> AA1")
    func initColumn27() {
        let ref = CellRef(column: 27, row: 1)
        #expect(ref.reference == "AA1")
    }

    @Test("init(column:52, row:1) -> AZ1")
    func initColumn52() {
        let ref = CellRef(column: 52, row: 1)
        #expect(ref.reference == "AZ1")
    }

    @Test("init(column:16384, row:1) -> XFD1")
    func initColumn16384() {
        let ref = CellRef(column: 16384, row: 1)
        #expect(ref.reference == "XFD1")
    }

    // MARK: - absolute() Method

    @Test("absolute() returns both flags true")
    func absoluteMethod() {
        let ref = CellRef("A1").absolute()
        #expect(ref.reference == "$A$1")
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
        #expect(ref.column == 1)
        #expect(ref.row == 1)
    }

    @Test("absolute() on already-absolute ref stays absolute")
    func absoluteOnAbsolute() {
        let ref = CellRef("$B$5").absolute()
        #expect(ref.reference == "$B$5")
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
    }

    @Test("absolute() on mixed ref becomes fully absolute")
    func absoluteOnMixed() {
        let ref = CellRef("$A1").absolute()
        #expect(ref.reference == "$A$1")
        #expect(ref.absoluteColumn == true)
        #expect(ref.absoluteRow == true)
    }

    // MARK: - Equatable

    @Test("CellRef(\"A1\") == CellRef(column:1, row:1)")
    func equatableStringVsInit() {
        let a = CellRef("A1")
        let b = CellRef(column: 1, row: 1)
        #expect(a == b)
    }

    @Test("Different cells are not equal")
    func notEqual() {
        let a = CellRef("A1")
        let b = CellRef("B1")
        #expect(a != b)
    }

    @Test("Equatable considers absolute flags")
    func equatableWithAbsoluteFlags() {
        let a = CellRef("A1")
        let b = CellRef("$A$1")
        #expect(a != b)
    }

    // MARK: - Hashable

    @Test("Can be used as dictionary key")
    func hashableDictionaryKey() {
        let ref1 = CellRef("A1")
        let ref2 = CellRef(column: 1, row: 1)
        var dict: [CellRef: String] = [:]
        dict[ref1] = "hello"
        #expect(dict[ref2] == "hello")
    }

    @Test("Different refs produce different hash buckets (usually)")
    func hashableDistinctKeys() {
        let ref1 = CellRef("A1")
        let ref2 = CellRef("B2")
        var dict: [CellRef: Int] = [:]
        dict[ref1] = 1
        dict[ref2] = 2
        #expect(dict.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Column edge case: column 1 is A")
    func columnEdge1() {
        let ref = CellRef(column: 1, row: 1)
        #expect(ref.reference == "A1")
    }

    @Test("Column edge case: column 26 is Z")
    func columnEdge26() {
        let ref = CellRef(column: 26, row: 1)
        #expect(ref.reference == "Z1")
    }

    @Test("Column edge case: column 27 is AA")
    func columnEdge27() {
        let ref = CellRef(column: 27, row: 1)
        #expect(ref.reference == "AA1")
    }

    @Test("Large row number")
    func largeRow() {
        let ref = CellRef("A1048576")
        #expect(ref.column == 1)
        #expect(ref.row == 1048576)
    }

    @Test("Round-trip large column XFD")
    func roundTripLargeColumn() {
        let ref = CellRef("XFD1")
        let ref2 = CellRef(column: ref.column, row: ref.row)
        #expect(ref2.reference == "XFD1")
        #expect(ref.column == 16384)
    }
}
