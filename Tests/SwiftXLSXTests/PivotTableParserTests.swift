import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore

/// Reading the little of a pivot table definition that `GETPIVOTDATA` needs.
///
/// **The fixtures are real.** Every XML fragment below is copied from a corpus workbook rather
/// than invented, because the thing most likely to be wrong here is an assumption about what
/// Excel actually writes — and an invented fixture would encode the assumption twice.
///
/// `GETPIVOTDATA` reads a *rendered* table: the values are already on the worksheet, cached
/// like any other formula result. So the parser takes a location, two offsets, the data field
/// names and two flags, and never opens `xl/pivotCache/` — 76 parts in one corpus file.
@Suite
struct PivotTableParserTests {

    /// `pivotTable24.xml` from `Amazon Reporting thru 05-15-18.xlsx`, trimmed to what is read.
    ///
    /// The pivot `GETPIVOTDATA("Sum of # Minutes Streamed", 'W-E Nov 18'!$M$1)` points at.
    private static let streams = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <pivotTableDefinition xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
    name="PivotTable24" cacheId="24" dataOnRows="0" applyNumberFormats="0">
    <location ref="M1:O253" firstHeaderRow="0" firstDataRow="1" firstDataCol="1"/>
    <dataFields count="2">
    <dataField name="Sum of # Streams" fld="8" baseField="0" baseItem="0"/>
    <dataField name="Sum of # Minutes Streamed" fld="9" baseField="0" baseItem="0"/>
    </dataFields>
    </pivotTableDefinition>
    """

    private func parse(_ xml: String, sheet: String = "W-E Nov 18") -> PivotTableLayout? {
        PivotTableParser.parse(data: Data(xml.utf8), onSheet: sheet)
    }

    @Test("the location, the offsets and the sheet")
    func readsTheLocation() throws {
        let layout = try #require(parse(Self.streams))
        #expect(layout.sheet == "W-E Nov 18")
        #expect(layout.range.start.reference == "M1")
        #expect(layout.range.end.reference == "O253")
        #expect(layout.firstDataRow == 1)
        #expect(layout.firstDataCol == 1)
    }

    /// Order matters: the names are matched against the header row by text, and a data field's
    /// position in the file is its position on the sheet.
    @Test("the data field names, in order")
    func readsTheDataFields() throws {
        let layout = try #require(parse(Self.streams))
        #expect(layout.dataFields == ["Sum of # Streams", "Sum of # Minutes Streamed"])
    }

    /// **Absent means present**, which is the trap in this part of the format.
    ///
    /// `pivotTable24` writes neither attribute and renders both totals — `M253` reads
    /// `"Grand Total"` on the sheet. A reader treating a missing attribute as `false` would
    /// lose the row `GETPIVOTDATA` asks for most often.
    @Test("a missing grand-total attribute means the total is rendered")
    func defaultsGrandTotalsToOn() throws {
        let layout = try #require(parse(Self.streams))
        #expect(layout.hasRowGrandTotals)
        #expect(layout.hasColumnGrandTotals)
        #expect(layout.grandTotalRow == 253)
    }

    /// `pivotTable41.xml` from `Dot Com YTD Performance Report 6 20.xlsx`.
    ///
    /// This is the pivot that settled the rule. Its last populated row reads **`"KEY Total"`**
    /// — a *subtotal* — so a reader looking for a row labelled `"…Total"` would have taken it
    /// for a grand total and returned the wrong number without complaining.
    @Test("rowGrandTotals=0 means there is no grand total row")
    func readsGrandTotalsTurnedOff() throws {
        let xml = """
        <pivotTableDefinition name="PivotTable41" rowGrandTotals="0" colGrandTotals="0">
        <location ref="AD130:AL176" firstHeaderRow="0" firstDataRow="1" firstDataCol="1"/>
        <dataFields count="1"><dataField name="Sum of Visits" fld="3"/></dataFields>
        </pivotTableDefinition>
        """
        let layout = try #require(parse(xml, sheet: "Data"))
        #expect(!layout.hasRowGrandTotals)
        #expect(!layout.hasColumnGrandTotals)
        #expect(layout.grandTotalRow == nil, "the last row is ordinary and must not be read as a total")
    }

    /// The two flags are independent, and one corpus workbook carries 36 pivots set this way.
    @Test("the two grand totals are read separately")
    func readsTheFlagsIndependently() throws {
        let xml = """
        <pivotTableDefinition name="P" colGrandTotals="0">
        <location ref="A1:C9" firstDataRow="1" firstDataCol="1"/>
        <dataFields count="1"><dataField name="Sum of X" fld="1"/></dataFields>
        </pivotTableDefinition>
        """
        let layout = try #require(parse(xml, sheet: "S"))
        #expect(layout.hasRowGrandTotals, "absent, so on")
        #expect(!layout.hasColumnGrandTotals, "written as 0")
    }

    // MARK: - Refusing rather than guessing

    @Test("a part with no location is not a pivot this package can use")
    func refusesAPartWithoutALocation() {
        let xml = "<pivotTableDefinition name=\"P\"><dataFields count=\"0\"/></pivotTableDefinition>"
        #expect(parse(xml, sheet: "S") == nil)
    }

    @Test("bytes that are not XML are refused rather than half-read")
    func refusesUnreadableBytes() {
        #expect(PivotTableParser.parse(data: Data([0xFF, 0xFE, 0x00]), onSheet: "S") == nil)
    }

    /// A pivot with no data fields parses — it is a real shape, and the lookup will refuse it
    /// later for naming a field it does not have, which is a clearer failure than a nil here.
    @Test("a pivot with no data fields is still a pivot")
    func acceptsAPivotWithoutDataFields() throws {
        let xml = """
        <pivotTableDefinition name="P"><location ref="A1:B4" firstDataRow="1" firstDataCol="1"/>
        </pivotTableDefinition>
        """
        let layout = try #require(parse(xml, sheet: "S"))
        #expect(layout.dataFields.isEmpty)
    }
}
