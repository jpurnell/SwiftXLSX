import XCTest
@testable import SwiftXLSX

/// Writing a formula together with the value Excel last computed for it.
///
/// A formula cell in a real workbook carries both: the rule in `<f>` and the last
/// result in `<v>`. The reader has always surfaced both, and the writer could only
/// ever say the first — so a `Workbook` built in code could not be made to look
/// like one read from disk.
///
/// That matters most for tests. Anything exercising the reader's own shapes — a
/// data table, whose body is entirely cached numbers under one marker; a formula
/// whose cached value is the only evidence of what it produced — had no way to
/// construct a fixture without a real file.
final class CachedFormulaWriteTests: XCTestCase {

    func testAFormulaCanCarryItsCachedValue() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Model")
        sheet.write(FormulaAST.multiply(.cellRef(CellRef("A1")), .number(2)), to: "B1",
                    cached: .number(84))

        let value = try XCTUnwrap(sheet.cell(at: "B1"))
        guard case .formula(let ast, let cached) = value else {
            return XCTFail("expected a formula, got \(value)")
        }
        XCTAssertEqual(ast, .multiply(.cellRef(CellRef("A1")), .number(2)))
        XCTAssertEqual(cached, .number(84))
    }

    func testTheFormulaIsStillReachableAsOne() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Model")
        sheet.write(FormulaAST.number(1), to: "B1", cached: .number(1))

        XCTAssertEqual(sheet.formulaAST(at: "B1"), .number(1))
    }

    func testOmittingTheCachedValueIsUnchanged() throws {
        let workbook = Workbook()
        let sheet = workbook.addSheet(name: "Model")
        sheet.write(FormulaAST.number(1), to: "B1")

        guard case .formula(_, let cached)? = sheet.cell(at: "B1") else {
            return XCTFail("expected a formula")
        }
        XCTAssertNil(cached, "the existing overload keeps its behaviour")
    }
}
