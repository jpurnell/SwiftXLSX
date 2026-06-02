import XCTest
@testable import SwiftXLSX

final class DependencyGraphTests: XCTestCase {

    // MARK: - Helper

    /// Creates a CellAddress for convenience.
    private func addr(_ sheet: String, _ ref: String) -> CellAddress {
        CellAddress(sheet: sheet, ref: ref)
    }

    // MARK: - Linear Chain

    func testLinearChainEvaluationOrder() {
        // A1 = 10, B1 = A1+1, C1 = B1+1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")

        let graph = DependencyGraph(workbook: wb)

        let order = graph.evaluationOrder
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")

        // A1 must come before B1, B1 before C1
        if let idxA = order.firstIndex(of: a1),
           let idxB = order.firstIndex(of: b1),
           let idxC = order.firstIndex(of: c1) {
            XCTAssertLessThan(idxA, idxB, "A1 must be evaluated before B1")
            XCTAssertLessThan(idxB, idxC, "B1 must be evaluated before C1")
        } else {
            XCTFail("All cells should appear in evaluation order")
        }
    }

    func testLinearChainInputsOutputs() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let c1 = addr("Sheet1", "C1")

        XCTAssertTrue(graph.inputs.contains(a1), "A1 should be an input (no formula)")
        XCTAssertTrue(graph.outputs.contains(c1), "C1 should be an output (no dependents)")
        XCTAssertFalse(graph.outputs.contains(a1), "A1 is not an output (has dependents)")
    }

    func testLinearChainPrecedents() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")

        XCTAssertEqual(graph.precedents(of: c1), [b1], "C1 depends on B1")
        XCTAssertEqual(graph.precedents(of: b1), [a1], "B1 depends on A1")
        XCTAssertTrue(graph.precedents(of: a1).isEmpty, "A1 has no precedents")
    }

    func testLinearChainDependents() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")

        XCTAssertEqual(graph.dependents(of: a1), [b1], "A1 is used by B1")
        XCTAssertEqual(graph.dependents(of: b1), [c1], "B1 is used by C1")
        XCTAssertTrue(graph.dependents(of: c1).isEmpty, "C1 has no dependents")
    }

    // MARK: - Diamond

    func testDiamondEvaluationOrder() {
        // A1=10, B1=A1*2, C1=A1*3, D1=B1+C1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(2)), to: "B1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(3)), to: "C1")
        sheet.write(.add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))), to: "D1")

        let graph = DependencyGraph(workbook: wb)

        let order = graph.evaluationOrder
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")
        let d1 = addr("Sheet1", "D1")

        guard let idxA = order.firstIndex(of: a1),
              let idxB = order.firstIndex(of: b1),
              let idxC = order.firstIndex(of: c1),
              let idxD = order.firstIndex(of: d1) else {
            XCTFail("All cells should appear in evaluation order")
            return
        }

        XCTAssertLessThan(idxA, idxB, "A1 must come before B1")
        XCTAssertLessThan(idxA, idxC, "A1 must come before C1")
        XCTAssertLessThan(idxB, idxD, "B1 must come before D1")
        XCTAssertLessThan(idxC, idxD, "C1 must come before D1")
    }

    func testDiamondInputsOutputs() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(2)), to: "B1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(3)), to: "C1")
        sheet.write(.add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))), to: "D1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let d1 = addr("Sheet1", "D1")

        XCTAssertEqual(graph.inputs, [a1], "A1 is the only input")
        XCTAssertEqual(graph.outputs, [d1], "D1 is the only output")
    }

    func testDiamondAllDependents() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(2)), to: "B1")
        sheet.write(.multiply(.cellRef(CellRef("A1")), .number(3)), to: "C1")
        sheet.write(.add(.cellRef(CellRef("B1")), .cellRef(CellRef("C1"))), to: "D1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")
        let d1 = addr("Sheet1", "D1")

        let allDeps = graph.allDependents(of: a1)
        XCTAssertEqual(allDeps, Set([b1, c1, d1]))
    }

    // MARK: - Multi-Sheet

    func testMultiSheetDependency() {
        // Sheet1!A1=10, Sheet2!A1=Sheet1!A1*2
        let wb = Workbook()
        let s1 = wb.addSheet(name: "Sheet1")
        s1.write(10.0, to: "A1")

        let s2 = wb.addSheet(name: "Sheet2")
        let crossRef = SheetReference(sheet: "Sheet1", cell: CellRef("A1"))
        s2.write(.multiply(.sheetRef(crossRef), .number(2)), to: "A1")

        let graph = DependencyGraph(workbook: wb)

        let s1a1 = addr("Sheet1", "A1")
        let s2a1 = addr("Sheet2", "A1")

        XCTAssertEqual(graph.precedents(of: s2a1), [s1a1])
        XCTAssertEqual(graph.dependents(of: s1a1), [s2a1])

        let order = graph.evaluationOrder
        guard let idx1 = order.firstIndex(of: s1a1),
              let idx2 = order.firstIndex(of: s2a1) else {
            XCTFail("Both cells should appear in evaluation order")
            return
        }
        XCTAssertLessThan(idx1, idx2, "Sheet1!A1 must be evaluated before Sheet2!A1")
    }

    // MARK: - Circular Reference

    func testCircularReferenceDetected() {
        // A1=B1+1, B1=A1+1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")

        let graph = DependencyGraph(workbook: wb)

        XCTAssertFalse(graph.isAcyclic)
        XCTAssertFalse(graph.cycles.isEmpty, "Should detect at least one cycle")

        // The cycle should involve A1 and B1
        let cycleAddresses = graph.cycles.flatMap { $0 }
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        XCTAssertTrue(cycleAddresses.contains(a1))
        XCTAssertTrue(cycleAddresses.contains(b1))
    }

    // MARK: - No Formulas

    func testNoFormulasWorkbook() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(20.0, to: "B1")
        sheet.write("Hello", to: "C1")

        let graph = DependencyGraph(workbook: wb)

        // All cells are inputs (no formulas)
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")

        let inputSet = Set(graph.inputs)
        XCTAssertTrue(inputSet.contains(a1))
        XCTAssertTrue(inputSet.contains(b1))
        XCTAssertTrue(inputSet.contains(c1))

        // All cells are also outputs (nothing depends on them)
        let outputSet = Set(graph.outputs)
        XCTAssertTrue(outputSet.contains(a1))
        XCTAssertTrue(outputSet.contains(b1))
        XCTAssertTrue(outputSet.contains(c1))

        XCTAssertTrue(graph.isAcyclic)
    }

    // MARK: - Range Dependency

    func testRangeDependency() {
        // B1..B5 have values, A1=SUM(B1:B5)
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        for i in 1...5 {
            sheet.write(Double(i), to: "B\(i)")
        }
        let range = CellRange(from: "B1", to: "B5")
        sheet.write(.sum(.cellRange(range)), to: "A1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let precedentsOfA1 = graph.precedents(of: a1)

        // A1 should depend on B1, B2, B3, B4, B5
        for i in 1...5 {
            let b = addr("Sheet1", "B\(i)")
            XCTAssertTrue(precedentsOfA1.contains(b), "A1 should depend on B\(i)")
        }
        XCTAssertEqual(precedentsOfA1.count, 5)
    }

    // MARK: - Independent Cells

    func testIndependentCells() {
        // A1=10, B1=20, no formulas referencing each other
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(20.0, to: "B1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")

        // Both are inputs and outputs
        XCTAssertTrue(graph.inputs.contains(a1))
        XCTAssertTrue(graph.inputs.contains(b1))
        XCTAssertTrue(graph.outputs.contains(a1))
        XCTAssertTrue(graph.outputs.contains(b1))

        // No dependencies between them
        XCTAssertTrue(graph.dependents(of: a1).isEmpty)
        XCTAssertTrue(graph.dependents(of: b1).isEmpty)
        XCTAssertTrue(graph.precedents(of: a1).isEmpty)
        XCTAssertTrue(graph.precedents(of: b1).isEmpty)

        XCTAssertTrue(graph.isAcyclic)
    }

    // MARK: - Acyclic Property

    func testAcyclicGraph() {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")

        let graph = DependencyGraph(workbook: wb)
        XCTAssertTrue(graph.isAcyclic)
        XCTAssertTrue(graph.cycles.isEmpty)
    }

    // MARK: - Empty Workbook

    func testEmptyWorkbook() {
        let wb = Workbook()
        let graph = DependencyGraph(workbook: wb)
        XCTAssertTrue(graph.evaluationOrder.isEmpty)
        XCTAssertTrue(graph.inputs.isEmpty)
        XCTAssertTrue(graph.outputs.isEmpty)
        XCTAssertTrue(graph.isAcyclic)
        XCTAssertTrue(graph.cycles.isEmpty)
    }

    // MARK: - Complex Formula

    func testNestedFunctionDependency() {
        // A1=10, A2=20, B1=IF(A1>A2, A1, A2)
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(20.0, to: "A2")
        sheet.write(
            .if(
                .greaterThan(.cellRef(CellRef("A1")), .cellRef(CellRef("A2"))),
                then: .cellRef(CellRef("A1")),
                else: .cellRef(CellRef("A2"))
            ),
            to: "B1"
        )

        let graph = DependencyGraph(workbook: wb)
        let b1 = addr("Sheet1", "B1")
        let a1 = addr("Sheet1", "A1")
        let a2 = addr("Sheet1", "A2")

        let precs = Set(graph.precedents(of: b1))
        XCTAssertEqual(precs, Set([a1, a2]))
    }

    // MARK: - Three-Cell Cycle

    func testThreeCellCycleDetected() {
        // A1=C1+1, B1=A1+1, C1=B1+1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(.add(.cellRef(CellRef("C1")), .number(1)), to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")

        let graph = DependencyGraph(workbook: wb)
        XCTAssertFalse(graph.isAcyclic)

        let cycleAddresses = Set(graph.cycles.flatMap { $0 })
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")
        XCTAssertTrue(cycleAddresses.contains(a1))
        XCTAssertTrue(cycleAddresses.contains(b1))
        XCTAssertTrue(cycleAddresses.contains(c1))
    }

    // MARK: - Negate Dependency

    func testNegateDependency() {
        // A1=10, B1=-A1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.negate(.cellRef(CellRef("A1"))), to: "B1")

        let graph = DependencyGraph(workbook: wb)

        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")

        XCTAssertEqual(graph.precedents(of: b1), [a1])
        XCTAssertEqual(graph.dependents(of: a1), [b1])
    }

    // MARK: - Concatenate Dependency

    func testConcatenateDependency() {
        // A1="Hello", B1=" World", C1=A1&B1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write("Hello", to: "A1")
        sheet.write(" World", to: "B1")
        sheet.write(.concatenate(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))), to: "C1")

        let graph = DependencyGraph(workbook: wb)
        let c1 = addr("Sheet1", "C1")
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")

        let precs = Set(graph.precedents(of: c1))
        XCTAssertEqual(precs, Set([a1, b1]))
    }

    // MARK: - Comparison Dependency

    func testComparisonDependencies() {
        // A1=10, B1=20, C1=(A1=B1), D1=(A1<>B1), E1=(A1>B1), F1=(A1<B1), G1=(A1>=B1), H1=(A1<=B1)
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(20.0, to: "B1")
        sheet.write(.equal(.cellRef(CellRef("A1")), .cellRef(CellRef("B1"))), to: "C1")

        let graph = DependencyGraph(workbook: wb)
        let c1 = addr("Sheet1", "C1")
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")

        let precs = Set(graph.precedents(of: c1))
        XCTAssertEqual(precs, Set([a1, b1]))
    }

    // MARK: - SheetRef with Range

    func testSheetRefWithRange() {
        // Sheet1 has B1:B3 with values, Sheet2!A1=SUM(Sheet1!B1:B3)
        let wb = Workbook()
        let s1 = wb.addSheet(name: "Sheet1")
        s1.write(1.0, to: "B1")
        s1.write(2.0, to: "B2")
        s1.write(3.0, to: "B3")

        let s2 = wb.addSheet(name: "Sheet2")
        let crossRange = SheetReference(sheet: "Sheet1", range: CellRange(from: "B1", to: "B3"))
        s2.write(.sum(.sheetRef(crossRange)), to: "A1")

        let graph = DependencyGraph(workbook: wb)
        let s2a1 = addr("Sheet2", "A1")

        let precedentsOfA1 = graph.precedents(of: s2a1)
        for i in 1...3 {
            let b = addr("Sheet1", "B\(i)")
            XCTAssertTrue(precedentsOfA1.contains(b), "Sheet2!A1 should depend on Sheet1!B\(i)")
        }
    }

    // MARK: - allDependents Transitive

    func testAllDependentsTransitive() {
        // A1=10, B1=A1+1, C1=B1+1, D1=C1+1
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Sheet1")
        sheet.write(10.0, to: "A1")
        sheet.write(.add(.cellRef(CellRef("A1")), .number(1)), to: "B1")
        sheet.write(.add(.cellRef(CellRef("B1")), .number(1)), to: "C1")
        sheet.write(.add(.cellRef(CellRef("C1")), .number(1)), to: "D1")

        let graph = DependencyGraph(workbook: wb)
        let a1 = addr("Sheet1", "A1")
        let b1 = addr("Sheet1", "B1")
        let c1 = addr("Sheet1", "C1")
        let d1 = addr("Sheet1", "D1")

        XCTAssertEqual(graph.allDependents(of: a1), Set([b1, c1, d1]))
        XCTAssertEqual(graph.allDependents(of: b1), Set([c1, d1]))
        XCTAssertEqual(graph.allDependents(of: c1), Set([d1]))
        XCTAssertTrue(graph.allDependents(of: d1).isEmpty)
    }
}
