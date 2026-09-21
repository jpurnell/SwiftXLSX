import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore

/// Reading `<f t="array">` back out of a workbook.
///
/// The reader already recorded each array formula's **anchor and span**, because a member of
/// the span is computed by its anchor rather than independently. This exposes the same fact
/// through ``CellValueProvider``, where the evaluator can reach it: array-entered, a range in
/// a scalar position means the whole range; normally entered, it implicitly intersects.
@Suite
struct ArrayEnteredReadingTests {

    private func workbook() -> Workbook {
        let wb = Workbook()
        let sheet = wb.addSheet(name: "Template")
        // `AF14:AF16` is one array formula; `B2` is an ordinary one.
        sheet.addArrayFormula(anchor: CellRef("AF14"),
                              span: CellRange(from: CellRef("AF14"), to: CellRef("AF16")))
        return wb
    }

    @Test("the anchor of an array formula is array-entered")
    func readsTheAnchor() {
        let provider = WorkbookValueProvider(workbook: workbook(), currentSheet: "Template")
        #expect(provider.isArrayEntered(at: CellRef("AF14"), inSheet: "Template"))
    }

    /// **Members count too.** They are filled by the anchor's one evaluation, so they are as
    /// array-entered as it is — containment is the test rather than identity.
    @Test("so is every cell of its span")
    func readsTheSpan() {
        let provider = WorkbookValueProvider(workbook: workbook(), currentSheet: "Template")
        #expect(provider.isArrayEntered(at: CellRef("AF15"), inSheet: "Template"))
        #expect(provider.isArrayEntered(at: CellRef("AF16"), inSheet: "Template"))
    }

    @Test("an ordinary formula cell is not")
    func readsAnOrdinaryCell() {
        let provider = WorkbookValueProvider(workbook: workbook(), currentSheet: "Template")
        #expect(!provider.isArrayEntered(at: CellRef("AF17"), inSheet: "Template"))
        #expect(!provider.isArrayEntered(at: CellRef("B2"), inSheet: "Template"))
    }

    @Test("a sheet the workbook does not have is not array-entered")
    func handlesAMissingSheet() {
        let provider = WorkbookValueProvider(workbook: workbook(), currentSheet: "Template")
        #expect(!provider.isArrayEntered(at: CellRef("AF14"), inSheet: "Nowhere"))
    }
}
