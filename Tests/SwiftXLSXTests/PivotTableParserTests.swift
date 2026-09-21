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

/// Reading a pivot table's **axes**, which is what field/item pairs need.
///
/// The fixture is `pivotTable8.xml` from `Dot Com YTD Performance Report 6 20.xlsx`, rendered
/// at `C134:L243` on `NED Mix`. 3,574 corpus cells ask about tables of this shape, and the
/// sheet renders it as
///
/// ```
/// 131  SalesChannelRollUp | (All)                                    ← page fields, above
/// 132  ActivityDetail     | Connect
/// 134  Sum of Subs        |        |             |        | FME_Calc ← captions
/// 135  Scenario | Region  | LOBMix_noXH | BP/IP  | 2014-01-21 | …    ← names + column items
/// 136  CY       | GBR     | V           |        | 303        | …
/// ```
@Suite
struct PivotTableAxisParsingTests {

    private static let names = [
        "Region", "FME_Calc", "week ending", "Fiber", "Scenario", "Activity",
        "ActivityDetail", "LOBMix_noXH", "LOBMix", "SalesChannelRollUp",
        "Channel_wCallCtr", "Subs", "B1", "HSI", "CDV", "XH", "BP/IP", "KeystoneEW",
    ]

    /// `pivotTable8.xml`, trimmed to what is read.
    private static let mix = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <pivotTableDefinition xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"     name="PivotTable8" cacheId="8" dataOnRows="1">
    <location ref="C134:L243" firstHeaderRow="1" firstDataRow="2" firstDataCol="4"     rowPageCount="2" colPageCount="1"/>
    <pivotFields count="18"><pivotField axis="axisRow"/></pivotFields>
    <rowFields count="4"><field x="4"/><field x="0"/><field x="7"/><field x="16"/></rowFields>
    <colFields count="1"><field x="1"/></colFields>
    <pageFields count="2"><pageField fld="9" hier="-1"/><pageField fld="6" item="0" hier="-1"/>    </pageFields>
    <dataFields count="1">    <dataField name="Sum of Subs" fld="11" baseField="0" baseItem="0"/></dataFields>
    </pivotTableDefinition>
    """

    private func parse(_ xml: String, fields: [String] = names,
                       sheet: String = "NED Mix") -> PivotTableLayout? {
        PivotTableParser.parse(data: Data(xml.utf8), onSheet: sheet, cacheFields: fields)
    }

    @Test("the row axis, resolved to names, outermost first")
    func readsTheRowAxis() throws {
        let layout = try #require(parse(Self.mix))
        #expect(layout.rowFields == [.field("Scenario"), .field("Region"),
                                     .field("LOBMix_noXH"), .field("BP/IP")])
    }

    @Test("the column and page axes")
    func readsTheOtherAxes() throws {
        let layout = try #require(parse(Self.mix))
        #expect(layout.columnFields == [.field("FME_Calc")])
        #expect(layout.pageFields == ["SalesChannelRollUp", "ActivityDetail"])
        #expect(layout.pageFieldRowCount == 2)
    }

    /// `firstHeaderRow` is read rather than derived — it is `1` here and `0` on the Amazon
    /// fixture, and the caption row differs from the header row whenever it is not zero.
    @Test("firstHeaderRow comes from the file")
    func readsTheHeaderRow() throws {
        let layout = try #require(parse(Self.mix))
        #expect(layout.firstHeaderRow == 1)
        #expect(layout.headerRow == 135)
        #expect(layout.captionRow == 134)
    }

    /// **The source field behind each caption.** `fld="11"` is `Subs`, and the corpus formulas
    /// ask for `"Subs"` rather than for `"Sum of Subs"`.
    @Test("a data field's source name comes from its fld index")
    func resolvesTheDataFieldSource() throws {
        let layout = try #require(parse(Self.mix))
        #expect(layout.dataFields == ["Sum of Subs"])
        #expect(layout.dataFieldSources == ["Subs"])
        #expect(layout.dataFieldIndex(named: "Subs") == 0)
    }

    /// **`<field x="-2"/>` is the values pseudo-field, not index -2 of anything.**
    ///
    /// `pivotTable7`, at `C267:K320` on the same sheet, stacks four data fields down the rows:
    /// column `C` reads `Values`, then ` B1`, ` HSI`, ` CDV`, `Sum of Subs`. Resolving `-2`
    /// through the name list would read off the end of it, or worse, wrap.
    @Test("the values pseudo-field is a case, not an index")
    func readsTheValuesPseudoField() throws {
        let xml = """
        <pivotTableDefinition name="PivotTable7" dataOnRows="1">
        <location ref="C267:K320" firstHeaderRow="1" firstDataRow="2" firstDataCol="3"         rowPageCount="2" colPageCount="1"/>
        <rowFields count="3"><field x="-2"/><field x="4"/><field x="0"/></rowFields>
        <colFields count="1"><field x="1"/></colFields>
        <pageFields count="2"><pageField fld="9"/><pageField fld="6"/></pageFields>
        <dataFields count="4">
        <dataField name=" B1" fld="12"/><dataField name=" HSI" fld="13"/>
        <dataField name=" CDV" fld="14"/><dataField name="Sum of Subs" fld="11"/>
        </dataFields>
        </pivotTableDefinition>
        """
        let layout = try #require(parse(xml))
        #expect(layout.rowFields == [.dataFieldNames, .field("Scenario"), .field("Region")])
        #expect(layout.dataFields == [" B1", " HSI", " CDV", "Sum of Subs"],
                "the leading spaces are the workbook's own and are kept")
        #expect(layout.dataFieldSources == ["B1", "HSI", "CDV", "Subs"])
    }

    // MARK: - Refusing rather than guessing

    /// **An index the cache cannot name is dropped, not invented.**
    ///
    /// A pivot whose cache definition is missing or unreadable leaves every index unresolved.
    /// Naming the field `"field 4"` would let a formula asking for a real field match nothing
    /// while the layout still claimed four row fields, which reads as a table shape that does
    /// not exist.
    @Test("an unresolvable index yields no name")
    func dropsIndicesTheCacheCannotName() throws {
        let layout = try #require(parse(Self.mix, fields: ["Region", "FME_Calc"]))
        #expect(layout.rowFields == [.field("Region")],
                "x=0 resolves; 4, 7 and 16 are past the end and are dropped")
        #expect(layout.dataFieldSources == [""], "fld=11 is past the end, so no source name")
        #expect(layout.dataFieldIndex(named: "Sum of Subs") == 0,
                "the caption still works, which is the two-argument form's only route")
    }

    /// With no cache at all the table still parses: position, captions and totals are enough
    /// for the two-argument form, which is what shipped first.
    @Test("no cache fields still yields a usable two-argument layout")
    func parsesWithoutACache() throws {
        let layout = try #require(parse(Self.mix, fields: []))
        #expect(layout.rowFields.isEmpty)
        #expect(layout.dataFields == ["Sum of Subs"])
        #expect(layout.grandTotalRow == 243)
    }

    /// A negative index that is not `-2` is not the pseudo-field and is not a field either.
    @Test("only -2 is the pseudo-field")
    func refusesOtherNegativeIndices() throws {
        let xml = """
        <pivotTableDefinition name="P">
        <location ref="A1:C9" firstHeaderRow="0" firstDataRow="1" firstDataCol="1"/>
        <rowFields count="2"><field x="-1"/><field x="0"/></rowFields>
        </pivotTableDefinition>
        """
        let layout = try #require(parse(xml))
        #expect(layout.rowFields == [.field("Region")], "-1 is dropped, 0 resolves")
    }
}
