import Testing
import Foundation
@testable import SwiftXLSX
import SwiftExcelCore

/// Reading the **field names** out of a pivot cache definition, and nothing else.
///
/// ## Why the cache is opened at all
///
/// It was not, for the two-argument `GETPIVOTDATA`, and the note on ``PivotTableParser`` still
/// says so correctly for that form. Field/item pairs change it: **field identity in a pivot
/// table definition is positional**. `<field x="4"/>`, `fld="11"`, `<pageField fld="9"/>` —
/// indices, every one, and nothing in `xl/pivotTables/` says index 4 is `Scenario`.
///
/// The distinction that keeps the original insight intact is **definitions versus records**:
///
/// | part | in the corpus workbook | read |
/// |---|---|---|
/// | `pivotCacheDefinition*.xml` | 7 parts, 0.8–12 KB | the `<cacheField name>` list, nothing more |
/// | `pivotCacheRecords*.xml` | 2 parts, 32 KB | never |
///
/// Nothing is aggregated and no record is ever touched. One corpus workbook carries 76 cache
/// parts; this opens the definitions among them to read a list of names.
@Suite
struct PivotCacheFieldsTests {

    /// `pivotCacheDefinition3.xml` from `Dot Com YTD Performance Report 6 20.xlsx`, trimmed.
    ///
    /// The cache behind `pivotTable8`, whose `rowFields` are `4 0 7 16` and whose data field
    /// is `fld="11"` — so this list is what turns those into `Scenario`, `Region`,
    /// `LOBMix_noXH`, `BP/IP` and `Subs`.
    private static let definition = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <pivotCacheDefinition xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
    recordCount="12300">
    <cacheSource type="worksheet"><worksheetSource ref="A1:R12301" sheet="data"/></cacheSource>
    <cacheFields count="18">
    <cacheField name="Region" numFmtId="0"><sharedItems count="5"/></cacheField>
    <cacheField name="FME_Calc" numFmtId="14"><sharedItems containsDate="1"/></cacheField>
    <cacheField name="week ending" numFmtId="14"><sharedItems/></cacheField>
    <cacheField name="Fiber" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="Scenario" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="Activity" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="ActivityDetail" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="LOBMix_noXH" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="LOBMix" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="SalesChannelRollUp" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="Channel_wCallCtr" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="Subs" numFmtId="0"><sharedItems containsSemiMixedTypes="0"/></cacheField>
    <cacheField name="B1" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="HSI" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="CDV" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="XH" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="BP/IP" numFmtId="0"><sharedItems/></cacheField>
    <cacheField name="KeystoneEW" numFmtId="0"><sharedItems/></cacheField>
    </cacheFields>
    </pivotCacheDefinition>
    """

    @Test("the field names, in the order the cache lists them")
    func readsTheFieldNames() {
        let names = PivotCacheParser.fieldNames(data: Data(Self.definition.utf8))
        #expect(names.count == 18)
        #expect(names[0] == "Region")
        #expect(names[4] == "Scenario", "<field x=\"4\"/> on the row axis")
        #expect(names[11] == "Subs", "the data field's fld=\"11\"")
        #expect(names[16] == "BP/IP", "a name with a slash in it, unescaped")
        #expect(names[9] == "SalesChannelRollUp", "a page field")
    }

    /// **The case is the cache's, not the formula's.**
    ///
    /// Field 2 is spelled `week ending` here and every corpus formula writes `"Week Ending"`.
    /// The name is stored as written and matched case-insensitively later, rather than
    /// normalised on the way in — normalising would lose the spelling this workbook uses when
    /// anything ever has to render it back.
    @Test("a name is stored exactly as the cache spells it")
    func keepsTheCachesOwnSpelling() {
        let names = PivotCacheParser.fieldNames(data: Data(Self.definition.utf8))
        #expect(names[2] == "week ending")
    }

    @Test("bytes that are not XML yield no names rather than a half-read list")
    func refusesUnreadableBytes() {
        #expect(PivotCacheParser.fieldNames(data: Data([0xFF, 0xFE, 0x00])).isEmpty)
    }

    /// A definition with no `cacheFields` is legal and yields nothing, which leaves every
    /// index unresolved and every pair refused — honest, and not a crash.
    @Test("a definition with no fields yields none")
    func handlesADefinitionWithNoFields() {
        let xml = "<pivotCacheDefinition recordCount=\"0\"/>"
        #expect(PivotCacheParser.fieldNames(data: Data(xml.utf8)).isEmpty)
    }

    /// **Only `cacheField` counts.** A `<cacheHierarchy name="…"/>` sits in the same part and
    /// naming it would shift every index by one, which is the quietest possible way to answer
    /// from the wrong column.
    @Test("other named elements in the part are not fields")
    func ignoresOtherNamedElements() {
        let xml = """
        <pivotCacheDefinition>
        <cacheFields count="2">
        <cacheField name="Region"/><cacheField name="Subs"/>
        </cacheFields>
        <cacheHierarchies count="1"><cacheHierarchy name="Not A Field"/></cacheHierarchies>
        </pivotCacheDefinition>
        """
        #expect(PivotCacheParser.fieldNames(data: Data(xml.utf8)) == ["Region", "Subs"])
    }
}
