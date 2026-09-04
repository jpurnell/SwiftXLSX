import XCTest
@testable import SwiftXLSX
import SwiftExcelCore

/// Writing values through a worksheet.
///
/// Separated from `CellValueTests` when `CellValue` moved to SwiftExcelCore.
/// These three assert what a `Worksheet` stores and hands back, which is
/// storage behaviour — the value type itself is tested in Core, where it lives.
final class CellValueWriteTests: XCTestCase {

    func testWorksheetWriteStringProducesText() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write("Hello", to: "A1")
        let value = sheet.cell(at: "A1")
        XCTAssertEqual(value, .text("Hello"))
    }

    func testWorksheetWriteNumberWorks() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(1_000.0, to: "B1")
        let value = sheet.cell(at: "B1")
        XCTAssertEqual(value, .number(1_000))
    }

    func testWorksheetWriteIntegerWorks() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Test")
        sheet.write(42, to: "C1")
        let value = sheet.cell(at: "C1")
        XCTAssertEqual(value, .number(42))
    }
}
