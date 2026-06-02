import XCTest
@testable import SwiftXLSX
import Foundation

final class CellValueTests: XCTestCase {

    // MARK: - Basic Values: resolved returns self

    func testNumberResolved() {
        let value = CellValue.number(42)
        XCTAssertEqual(value.resolved, .number(42))
    }

    func testTextResolved() {
        let value = CellValue.text("hello")
        XCTAssertEqual(value.resolved, .text("hello"))
    }

    func testBoolTrueResolved() {
        let value = CellValue.bool(true)
        XCTAssertEqual(value.resolved, .bool(true))
    }

    func testBoolFalseResolved() {
        let value = CellValue.bool(false)
        XCTAssertEqual(value.resolved, .bool(false))
    }

    func testErrorResolved() {
        let value = CellValue.error(.div0)
        XCTAssertEqual(value.resolved, .error(.div0))
    }

    func testBlankResolved() {
        let value = CellValue.blank
        XCTAssertEqual(value.resolved, .blank)
    }

    func testDateResolved() {
        let date = Date()
        let value = CellValue.date(date)
        XCTAssertEqual(value.resolved, .date(date))
    }

    // MARK: - Formula: isFormula, formulaAST, resolved

    func testFormulaIsFormula() {
        let ast = FormulaAST.number(42)
        let value = CellValue.formula(ast, cached: nil)
        XCTAssertTrue(value.isFormula)
    }

    func testFormulaASTExtraction() {
        let ast = FormulaAST.number(42)
        let value = CellValue.formula(ast, cached: nil)
        XCTAssertEqual(value.formulaAST, ast)
    }

    func testFormulaResolvedNilCache() {
        let ast = FormulaAST.number(42)
        let value = CellValue.formula(ast, cached: nil)
        XCTAssertEqual(value.resolved, .blank)
    }

    func testFormulaResolvedCachedNumber() {
        let ast = FormulaAST.number(42)
        let value = CellValue.formula(ast, cached: .number(42))
        XCTAssertEqual(value.resolved, .number(42))
    }

    func testFormulaResolvedCachedText() {
        let ast = FormulaAST.number(0)
        let value = CellValue.formula(ast, cached: .text("result"))
        XCTAssertEqual(value.resolved, .text("result"))
    }

    func testFormulaResolvedCachedError() {
        let ast = FormulaAST.number(0)
        let value = CellValue.formula(ast, cached: .error(.value))
        XCTAssertEqual(value.resolved, .error(.value))
    }

    // MARK: - Non-formula: isFormula / formulaAST

    func testNumberIsNotFormula() {
        XCTAssertFalse(CellValue.number(42).isFormula)
    }

    func testTextFormulaASTIsNil() {
        XCTAssertNil(CellValue.text("hi").formulaAST)
    }

    func testBlankIsNotFormula() {
        XCTAssertFalse(CellValue.blank.isFormula)
    }

    func testBoolIsNotFormula() {
        XCTAssertFalse(CellValue.bool(true).isFormula)
    }

    func testErrorIsNotFormula() {
        XCTAssertFalse(CellValue.error(.ref).isFormula)
    }

    func testDateIsNotFormula() {
        XCTAssertFalse(CellValue.date(Date()).isFormula)
    }

    func testNumberFormulaASTIsNil() {
        XCTAssertNil(CellValue.number(99).formulaAST)
    }

    func testBlankFormulaASTIsNil() {
        XCTAssertNil(CellValue.blank.formulaAST)
    }

    // MARK: - Array values

    func testArrayResolved() {
        let value = CellValue.array([.number(1), .number(2), .number(3)])
        XCTAssertEqual(value.resolved, .array([.number(1), .number(2), .number(3)]))
    }

    func testEmptyArrayResolved() {
        let value = CellValue.array([])
        XCTAssertEqual(value.resolved, .array([]))
    }

    func testMixedArray() {
        let value = CellValue.array([.number(1), .text("a"), .bool(true)])
        XCTAssertEqual(value.resolved, .array([.number(1), .text("a"), .bool(true)]))
    }

    func testArrayIsNotFormula() {
        XCTAssertFalse(CellValue.array([.number(1)]).isFormula)
    }

    func testArrayFormulaASTIsNil() {
        XCTAssertNil(CellValue.array([]).formulaAST)
    }

    // MARK: - Equatable

    func testNumberEquality() {
        XCTAssertEqual(CellValue.number(42), CellValue.number(42))
    }

    func testNumberInequality() {
        XCTAssertNotEqual(CellValue.number(42), CellValue.number(43))
    }

    func testTextEquality() {
        XCTAssertEqual(CellValue.text("a"), CellValue.text("a"))
    }

    func testTextInequality() {
        XCTAssertNotEqual(CellValue.text("a"), CellValue.text("b"))
    }

    func testFormulaEquality() {
        let ast = FormulaAST.number(1)
        XCTAssertEqual(
            CellValue.formula(ast, cached: .number(1)),
            CellValue.formula(ast, cached: .number(1))
        )
    }

    func testFormulaInequalityCachedDiffers() {
        let ast = FormulaAST.number(1)
        XCTAssertNotEqual(
            CellValue.formula(ast, cached: .number(1)),
            CellValue.formula(ast, cached: .number(2))
        )
    }

    func testFormulaInequalityASTDiffers() {
        let ast1 = FormulaAST.number(1)
        let ast2 = FormulaAST.number(2)
        XCTAssertNotEqual(
            CellValue.formula(ast1, cached: nil),
            CellValue.formula(ast2, cached: nil)
        )
    }

    func testBlankEquality() {
        XCTAssertEqual(CellValue.blank, CellValue.blank)
    }

    func testCrossTypeInequality() {
        XCTAssertNotEqual(CellValue.number(42), CellValue.text("42"))
    }

    func testBoolEquality() {
        XCTAssertEqual(CellValue.bool(true), CellValue.bool(true))
    }

    func testBoolInequality() {
        XCTAssertNotEqual(CellValue.bool(true), CellValue.bool(false))
    }

    func testErrorEquality() {
        XCTAssertEqual(CellValue.error(.div0), CellValue.error(.div0))
    }

    func testErrorInequality() {
        XCTAssertNotEqual(CellValue.error(.div0), CellValue.error(.value))
    }

    // MARK: - Hashable

    func testHashableAsDictionaryKey() {
        var dict: [CellValue: String] = [:]
        dict[.number(42)] = "forty-two"
        dict[.text("hello")] = "greeting"
        dict[.blank] = "empty"
        XCTAssertEqual(dict[.number(42)], "forty-two")
        XCTAssertEqual(dict[.text("hello")], "greeting")
        XCTAssertEqual(dict[.blank], "empty")
    }

    func testHashableInSet() {
        var set: Set<CellValue> = []
        set.insert(.number(42))
        set.insert(.number(42))
        set.insert(.text("hello"))
        XCTAssertEqual(set.count, 2)
    }

    func testSameValuesProduceSameHash() {
        let a = CellValue.number(42)
        let b = CellValue.number(42)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testSameTextProducesSameHash() {
        let a = CellValue.text("hello")
        let b = CellValue.text("hello")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testSameFormulaProducesSameHash() {
        let ast = FormulaAST.number(1)
        let a = CellValue.formula(ast, cached: .number(1))
        let b = CellValue.formula(ast, cached: .number(1))
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - Integration (backward compatibility)

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
