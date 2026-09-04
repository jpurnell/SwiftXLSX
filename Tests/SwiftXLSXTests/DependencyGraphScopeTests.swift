import XCTest
@testable import SwiftXLSX

/// Building a dependency graph over part of a workbook.
///
/// ``DependencyGraph/init(workbook:)`` answers the question a spreadsheet
/// *evaluator* asks: in what order must I visit every cell? For that, every cell
/// belongs in the graph — labels included, and a referenced-but-empty cell too,
/// because you still have to visit it to know it is zero.
///
/// A caller trying to recover a *model* from a sheet is asking something else:
/// which quantities depend on which. There, a title in `A1` is not a node, and a
/// reference to an empty cell is not an input. Reading the whole-workbook graph
/// and filtering afterwards does not work — the counts are already wrong, and the
/// topological order and cycle set were computed over the unfiltered set.
///
/// So the scope has to be given before the graph is built, which is what these
/// initializers are for.
final class DependencyGraphScopeTests: XCTestCase {

    /// Two sheets. On `Model`: a title, two numbers, a formula reading them, and
    /// a formula reading a cell that holds nothing. On `Other`: one number, so a
    /// cross-sheet reference has somewhere to point.
    private func workbook() -> Workbook {
        let book = Workbook()

        let model = book.addSheet(name: "Model")
        model.write("Quarterly Plan", to: "A1")
        model.write(100.0, to: "B2")
        model.write(0.4, to: "B3")
        model.write(FormulaAST.multiply(.cellRef(CellRef("B2")), .cellRef(CellRef("B3"))),
                    to: "B4")
        // B9 holds nothing at all.
        model.write(FormulaAST.add(.cellRef(CellRef("B4")), .cellRef(CellRef("B9"))), to: "B5")

        let other = book.addSheet(name: "Other")
        other.write(7.0, to: "C1")

        return book
    }

    private func numeric(_ value: CellValue) -> Bool {
        switch value.resolved {
        case .number, .blank: return true
        default: return value.isFormula
        }
    }

    // MARK: - Scoping to a sheet

    func testASheetScopedGraphHoldsOnlyThatSheetsCells() {
        let book = workbook()
        let sheet = book.sheets[0]
        let graph = DependencyGraph(sheet: sheet)

        XCTAssertTrue(
            graph.allCells.allSatisfy { $0.sheet == "Model" },
            "Got: \(graph.allCells.map(\.sheet).sorted())")
    }

    /// A formula reaching into another sheet has a precedent the scope excludes.
    /// The edge goes with it, rather than pulling a foreign cell into the graph.
    func testACrossSheetReferenceIsNotPulledIn() {
        let book = workbook()
        book.sheets[0].write(
            FormulaAST.cellRef(CellRef("C1")), to: "B6")   // resolves within Model
        book.sheets[0].write(
            FormulaAST.sheetRef(SheetReference(sheet: "Other", cell: CellRef("C1"))), to: "B7")

        let graph = DependencyGraph(sheet: book.sheets[0])

        XCTAssertFalse(
            graph.allCells.contains { $0.sheet == "Other" },
            "the scope is the sheet, so a reference out of it is out of the graph")
        XCTAssertTrue(graph.allCells.contains(CellAddress(sheet: "Model", ref: "B7")))
    }

    // MARK: - Scoping by content

    /// A title is not a quantity. Nothing depends on `A1`, and it depends on
    /// nothing — it is in the sheet, not in the model.
    func testAContentFilterExcludesLabels() {
        let graph = DependencyGraph(sheet: workbook().sheets[0], including: numeric)

        XCTAssertFalse(
            graph.allCells.contains(CellAddress(sheet: "Model", ref: "A1")),
            "Got: \(graph.allCells.map(\.cell.reference).sorted())")
        XCTAssertTrue(graph.allCells.contains(CellAddress(sheet: "Model", ref: "B2")))
        XCTAssertTrue(graph.allCells.contains(CellAddress(sheet: "Model", ref: "B4")))
    }

    /// The unfiltered graph registers every referenced address, so a formula
    /// pointing at an empty cell mints a node with no value — which then appears
    /// among the inputs, reading as data the model was given. It is not.
    func testAnEmptyReferencedCellIsNotAnInput() {
        let book = workbook()

        let everything = DependencyGraph(sheet: book.sheets[0])
        XCTAssertTrue(
            everything.allCells.contains(CellAddress(sheet: "Model", ref: "B9")),
            "today's behaviour, and right for evaluation: you visit it to learn it is zero")

        let model = DependencyGraph(sheet: book.sheets[0], including: numeric)
        XCTAssertFalse(
            model.allCells.contains(CellAddress(sheet: "Model", ref: "B9")),
            "but it is not a quantity the model was given")
    }

    // MARK: - The graph still works

    func testTheScopedGraphSortsAndReportsAsUsual() throws {
        let graph = DependencyGraph(sheet: workbook().sheets[0], including: numeric)

        XCTAssertTrue(graph.isAcyclic)
        XCTAssertEqual(
            Set(graph.inputs.map(\.cell.reference)), ["B2", "B3"],
            "the two numbers, and nothing else")
        XCTAssertEqual(
            Set(graph.outputs.map(\.cell.reference)), ["B5"],
            "nothing reads B5")

        let order = graph.evaluationOrder.map(\.cell.reference)
        let b4 = try XCTUnwrap(order.firstIndex(of: "B4"))
        let b2 = try XCTUnwrap(order.firstIndex(of: "B2"))
        XCTAssertLessThan(b2, b4, "a cell comes after what it reads")

        XCTAssertEqual(graph.precedents(of: CellAddress(sheet: "Model", ref: "B4")).count, 2)
        XCTAssertEqual(
            graph.precedents(of: CellAddress(sheet: "Model", ref: "B5")).map(\.cell.reference),
            ["B4"],
            "the reference to the empty B9 is dropped with the node")
    }

    /// A cycle inside the scope is still found.
    func testACycleWithinTheScopeIsStillDetected() {
        let book = Workbook()
        let sheet = book.addSheet(name: "Model")
        sheet.write("Circular", to: "A1")
        sheet.write(FormulaAST.add(.cellRef(CellRef("B2")), .number(1)), to: "B1")
        sheet.write(FormulaAST.add(.cellRef(CellRef("B1")), .number(1)), to: "B2")

        let graph = DependencyGraph(sheet: sheet, including: numeric)
        XCTAssertFalse(graph.isAcyclic)
        XCTAssertEqual(graph.cycles.count, 1)
    }

    // MARK: - The existing initializer is untouched

    func testTheWorkbookInitializerIsUnchanged() {
        let book = workbook()
        let whole = DependencyGraph(workbook: book)

        XCTAssertTrue(
            whole.allCells.contains(CellAddress(sheet: "Model", ref: "A1")),
            "labels still counted")
        XCTAssertTrue(
            whole.allCells.contains(CellAddress(sheet: "Other", ref: "C1")),
            "every sheet still walked")
        XCTAssertTrue(
            whole.allCells.contains(CellAddress(sheet: "Model", ref: "B9")),
            "and a referenced empty cell is still a node")
    }
}
