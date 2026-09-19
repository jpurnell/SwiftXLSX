import Testing
import Foundation
import SwiftExcelCore
@testable import SwiftXLSX

/// Every number a cell can hold survives being written.
///
/// The writer formatted a number as `n.truncatingRemainder(dividingBy: 1) == 0 ?
/// String(Int(n)) : String(n)`, so that a whole number would be written `3` rather than
/// `3.0`. The test for whole-ness is right and the conversion is not: **every** Double past
/// `Int.max` is integer-valued — the format has no fractional bits left to hold anything
/// else — so the guard sends exactly the numbers `Int` cannot represent down the `Int(n)`
/// path, which traps.
///
/// A corpus round trip found it, at a workbook holding a value around 1e19. The process did
/// not throw and could not be caught; it took `SIGTRAP` in `worksheetXML(sheet:)` and the
/// run died. Five call sites shared the expression.
@Suite
struct NumberWritingTests {

    /// The formatter itself, at the boundary and past it.
    @Test("Whole numbers are written without A point zero")
    func testWholeNumbersAreWrittenWithoutAPointZero() throws {
        #expect(NumberText.of(3) == "3")
        #expect(NumberText.of(-3) == "-3")
        #expect(NumberText.of(0) == "0")
        #expect(NumberText.of(3.5) == "3.5")
    }

    /// Past `Int.max` the short form is unavailable, and the number is still a number.
    ///
    /// `9.3e18` is under `Int.max` (≈9.22e18) only by the width of a rounding error, so the
    /// pair below sits on either side of the boundary that traps.
    @Test("Numbers beyond int are written rather than trapped")
    func testNumbersBeyondIntAreWrittenRatherThanTrapped() throws {
        #expect(NumberText.of(9_000_000_000_000_000_000) == "9000000000000000000")
        let huge = NumberText.of(1e19)
        #expect(!(huge.isEmpty))
        #expect(try #require(Double(huge)).isEqual(to: 1e19), "what is written must read back as the same number")

        let negative = NumberText.of(-1e19)
        #expect(try #require(Double(negative)).isEqual(to: -1e19))

        let vast = NumberText.of(.greatestFiniteMagnitude)
        #expect(Double(vast) == .greatestFiniteMagnitude)
    }

    /// Infinity and NaN are not numbers a spreadsheet can hold, and must not be written as if
    /// they were: `inf` and `nan` are not valid `xsd:double` and Excel reports the file as
    /// damaged rather than showing the cell.
    @Test("Infinity and na N do not produce invalid XML")
    func testInfinityAndNaNDoNotProduceInvalidXML() throws {
        for value in [Double.infinity, -.infinity, .nan] {
            let text = NumberText.of(value)
            let read = try #require(Double(text), "wrote \(text) for \(value), which no reader accepts")
            // The clamp is the whole point: infinity becomes the largest finite Double of the
            // same sign, and NaN — which has no sign to keep — becomes zero.
            let clamped: Double = value.isNaN
                ? 0
                : (value < 0 ? -.greatestFiniteMagnitude : .greatestFiniteMagnitude)
            #expect(read.isEqual(to: clamped), "wrote \(text) for \(value), which is not its clamp")
            #expect(read.isFinite, "wrote \(text) for \(value)")
        }
        // An exponent is a letter and is still a number; `inf` and `nan` are the shapes that
        // must not appear, not every non-digit.
        #expect(Double(NumberText.of(.infinity)) == .greatestFiniteMagnitude)
        #expect(NumberText.of(.nan) == "0")
    }

    /// The whole path: a workbook holding the value that crashed the corpus run saves.
    @Test("A workbook holding A very large number saves")
    func testAWorkbookHoldingAVeryLargeNumberSaves() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(1e19, to: "A1")
        sheet.write(-1e19, to: "A2")
        sheet.write(Double.greatestFiniteMagnitude, to: "A3")
        sheet.write(42.0, to: "A4")

        let reread = try Workbook(xlsxData: try workbook.save())
        let back = try #require(reread.sheets.first { $0.name == "Sheet1" })

        #expect(back.cell(at: "A1") == .number(1e19))
        #expect(back.cell(at: "A2") == .number(-1e19))
        #expect(back.cell(at: "A3") == .number(.greatestFiniteMagnitude))
        #expect(back.cell(at: "A4") == .number(42))
    }

    /// A cached formula result is the same number on the way out.
    @Test("A very large cached result saves")
    func testAVeryLargeCachedResultSaves() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Sheet1")
        sheet.write(FormulaAST.number(1e19), to: "B1", cached: .number(1e19))

        let reread = try Workbook(xlsxData: try workbook.save())
        let back = try #require(reread.sheets.first { $0.name == "Sheet1" })
        guard case .formula(_, let cached)? = back.cell(at: "B1") else {
            Issue.record("expected a formula, got \(String(describing: back.cell(at: "B1")))")
            return
        }
        #expect(cached == .number(1e19))
    }
}
