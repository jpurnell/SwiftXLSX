# Design Proposal: Surgical Save — editing a workbook without destroying it

**Status:** proposal, 2026-09-08. **Step 1 measured 2026-09-24 — see §18.** Ready for RED.
**Phase:** 0 (Design).
**Motivated by:** `SwiftExcelFunctions/project/plans/proposals/PROPOSAL_model_graph_simulation.md`
§12, which needs to write a corrected value back into a real workbook. The defect is SwiftXLSX's
and the fix belongs here, where every consumer gets it.

---

## 1. Objective

**Open an existing `.xlsx`, change some cells, save it, and change nothing else.**

Not "lose little." Nothing. A user who opens their model, accepts one corrected formula, and saves
should find their charts, their theme, their conditional formatting and their macros exactly as
they left them — and should be able to verify that by diffing the archive.

---

## 2. Motivation

Today `Workbook(xlsxData: d).save()` is data loss, and it is silent.

`save()` regenerates the archive from seven part types:

```
[Content_Types].xml   _rels/.rels   xl/workbook.xml
xl/_rels/workbook.xml.rels   xl/worksheets/sheetN.xml
xl/styles.xml   xl/sharedStrings.xml
```

`Workbook(xlsxData:)` retains only `sheets` and `namedRanges`. `WorkbookReader.read(from:)` builds
an `entryMap` of every part in the archive, consumes six of them, and lets the rest fall out of
scope when the function returns.

So a read-modify-write deletes charts, pivot tables and their caches, VBA, drawings, images,
themes, comments, tables, external links, document properties, and every part type Excel adds in
future versions.

**This is correct behaviour for the case it was built for** — a `Workbook()` composed in code and
written out — and it is destruction for the case of opening someone's model. Nothing in the API
distinguishes the two, which is what makes it dangerous rather than merely limited.

### 2.1 The second failure, which is subtler and worse

Preserving foreign parts is necessary and **not sufficient**. A worksheet is a part this library
*owns*, and regenerating one is itself lossy.

Measured, writer against parser:

| In-sheet element | Parser reads | Writer emits |
|---|:---:|:---:|
| `sheetData`, `row`, `c`, `f`, `v` | ✅ | ✅ |
| `cols`, `pane`/`sheetViews` | ✅ | ✅ |
| `autoFilter` | ✅ | ✅ |
| `mergeCell` | ✅ | ✅ |
| `dataValidation` | ✅ | ✅ |
| `conditionalFormatting` | ❌ | ❌ |
| `hyperlinks` | ❌ | ❌ |
| `pageSetup`, `printOptions` | ❌ | ❌ |
| `sheetProtection` | ❌ | ❌ |
| **`drawing`, `legacyDrawing`** | ❌ | ❌ |

The last row is the one that matters most, and it defeats a naive surgical save. A chart lives in
`xl/charts/chart1.xml`, is linked by `xl/worksheets/_rels/sheet1.xml.rels`, and is *anchored* by a
single `<drawing r:id="rId1"/>` element inside `sheet1.xml`. Preserving foreign parts keeps the
chart and keeps the rels — but regenerating the sheet drops the anchor, so the chart part survives
in the archive with nothing pointing at it. **The chart vanishes and the file still opens**, which
is the worst possible failure: no error, no repair dialog, just a missing chart.

The same argument applies to conditional formatting, hyperlinks, print areas and sheet protection.

**Therefore a changed sheet must be edited, not regenerated.** That is §3.2, and it is the
difference between this proposal and the obvious one.

---

## 3. Proposed Architecture

Two levels, and both are needed.

```
  read ──► retain every ZIPEntry ──────────────────────────┐
                                                           │
  edit ──► Worksheet marks changed cells                   │
                                                           ▼
  save ──► foreign parts:  copy bytes, unexamined
           owned, unchanged sheets:  copy bytes, unexamined
           owned, CHANGED sheets:  splice the original XML  ◄── §3.2
           sharedStrings / styles:  append only             ◄── §3.3
           calcChain.xml:  drop                             ◄── §3.3
           workbook.xml:  set fullCalcOnLoad                ◄── §3.3
```

### 3.1 Provenance selects the strategy

```swift
/// The archive this workbook was read from, if it was read from one.
internal private(set) var origin: [ZIPEntry]?
```

A `Workbook()` composed in code has no origin and saves exactly as it does today. A workbook read
from a file has one and saves surgically. **The strategy follows from provenance, not from a
flag**, so the destructive path cannot be reached by forgetting an argument.

### 3.2 Splicing a changed sheet

For a sheet with changed cells, parse the *original* `sheetN.xml`, replace only the `<c>` elements
whose cells changed, and re-serialise everything else byte-for-byte — including elements this
library has never heard of.

The operations needed:

- **Replace** a `<c>`'s `<f>` and `<v>` children, preserving its `s=` style index and `t=` type
  attribute unless the new value's type demands otherwise.
- **Insert** a `<c>` in column order within its `<row>`, or a whole `<row>` in row order, when the
  edit writes to a previously empty cell.
- **Remove** a `<c>` when a cell is cleared.
- **Widen `<dimension>`** if the used range grew.
- **Touch nothing else.** Every other element, attribute, namespace declaration and whitespace run
  passes through.

This is an XML edit, not a model round-trip, and that distinction is the proposal. It also means
the fidelity of the change is bounded by the cells the caller actually touched, which is a far
smaller surface to get right than "reproduce an arbitrary worksheet."

### 3.3 The three archive-level traps

**Shared-string and style indices are positional.** A cell reads `<c t="s"><v>7</v></c>` — index 7
into `sharedStrings.xml`. Sheets copied through unspliced still hold indices into that table, so
on a surgical save it is **append-only**: existing entries keep their positions, new strings go on
the end, and the table is never compacted or reordered. Same rule for `styles.xml`.

**`xl/calcChain.xml` goes stale.** It records the order Excel last evaluated formulas in; edit a
formula and it can be wrong, and a wrong calc chain makes Excel repair the file on open. It is a
regenerable cache, so **drop it** — along with its content-type override — whenever a formula
changed. Excel rebuilds it.

**Cached values go stale.** Every formula cell carries the value Excel last computed. Change a
precedent and its dependents' caches are lies. This library's own oracle tests treat those caches
as ground truth, so writing stale ones would poison a test corpus. Set `fullCalcOnLoad="1"` on
`<calcPr>` in `xl/workbook.xml`, which makes the file honest without this library recalculating
anything.

### 3.4 Write to a copy

`save(to:)` onto an existing path, for a workbook with an origin, requires explicit overwrite
permission. Losing an unbacked-up model to a bug in this feature is the outcome that would make
the feature not worth having.

**Done 2026-09-26.** `save(to:strategy:overwriting:)`, throwing `destinationExists(_:)`. Two
things the implementation added to the design:

- The check runs **before anything is generated**, not at the write. A guard that fires after
  truncating the file destroys the model *and* reports an error, and the caller then believes
  nothing happened. There is a test for exactly that: the bytes on disk after a refused save
  must equal the bytes before it.
- The write is **atomic** regardless of the guard, for every workbook. `Data.write(to:)`
  without `.atomic` leaves a truncated file if anything fails partway, which is the same loss
  the guard exists to prevent arriving by a different route.

Checked against the consumers before landing: every `save(to:)` call site in the sibling
repositories composes its workbook in code, so none of them is affected.

---

## 4. API Surface

```swift
extension Workbook {

    /// How `save()` builds the archive.
    public enum SaveStrategy: Sendable, Equatable {
        /// Emit only the parts this library models, from its in-memory model.
        /// Correct for a workbook composed in code; destructive for one that was read.
        case generated

        /// Preserve every part of the source archive, splicing only changed cells
        /// into the sheets that contain them. Requires a workbook read from a file.
        case surgical
    }

    /// `.surgical` if this workbook was read from an archive, `.generated` if it was
    /// composed in code.
    public var defaultSaveStrategy: SaveStrategy { get }

    /// What a save would do to each part, without writing anything.
    ///
    /// Public because a caller about to overwrite someone's model should be able to
    /// show them what will happen to it first.
    public func saveManifest(strategy: SaveStrategy? = nil) throws -> SaveManifest

    public func save(strategy: SaveStrategy? = nil) throws -> Data

    /// - Parameter overwriting: required to replace an existing file when this workbook
    ///   was read from an archive. Defaults to `false`.
    public func save(
        to url: URL,
        strategy: SaveStrategy? = nil,
        overwriting: Bool = false
    ) throws
}

/// What a save will do, part by part.
public struct SaveManifest: Sendable, Equatable {
    /// Sheets whose XML will be spliced, with the cells changed in each.
    public let spliced: [(part: String, cells: [CellRef])]
    /// Parts regenerated wholesale — `sharedStrings`, `styles`, `workbook.xml`.
    public let rewritten: [String]
    /// Parts copied through byte for byte. Everything else.
    public let preserved: [String]
    /// Parts deliberately removed. `xl/calcChain.xml` and nothing else, today.
    public let dropped: [String]
    /// True if any cell changed, which is what forces `fullCalcOnLoad`.
    public let forcesRecalculation: Bool
}

extension Worksheet {
    /// Cells written since this worksheet was read, in write order.
    ///
    /// Empty for a sheet that was read and not modified, which is what lets §3.2 copy
    /// it through untouched rather than splicing it.
    public var changedCells: [CellRef] { get }

    /// True if any cell changed.
    public var hasUnsavedChanges: Bool { get }
}

public enum SaveError: Error, Sendable, Equatable {
    /// `.surgical` requested for a workbook composed in code.
    case noOriginArchive
    /// The destination exists and `overwriting` was not set.
    case destinationExists(URL)
    /// A sheet was added, removed or reordered. §13 explains why this throws.
    case structuralChangeUnsupported(reason: String)
    /// The source sheet XML could not be spliced — malformed, or a shape not handled.
    /// Carries the part path so the caller can report which sheet.
    case spliceFailed(part: String, reason: String)
}
```

---

## 5. MCP Schema

Not applicable. This is a file-format library with no MCP surface.

---

## 6. Constraints & Compliance

| Rule | Compliance |
|---|---|
| No force unwraps, `try!`, `as!` | Splicing parses attacker-shaped XML; every lookup is a `guard` returning `spliceFailed` |
| Guard-clause validation, early return | Throughout |
| Swift 6 strict concurrency | `SaveStrategy`, `SaveManifest`, `SaveError` are `Sendable`; `origin` is immutable after read |
| Division safety | Not reached |
| DocC on all public API | Required for the seven new public symbols |
| No overrides to silence the gate | The XML splicer is the one place tempted toward a suppression; it must not be |

**Memory.** Holding the origin archive doubles peak usage. A 100MB workbook costs 200MB. Acceptable
to start, noted in §14.

---

## 7. Source & API Compatibility

**This is a behaviour change to a released library, and it is the section that most needed
writing.** An earlier draft of this proposal omitted it.

| Change | Kind | Impact |
|---|---|---|
| `save()` gains a defaulted parameter | Source compatible | Existing call sites compile |
| **`save()` on a read workbook now preserves parts** | **Behavioural** | Output bytes differ from before |
| `save(to:)` gains `overwriting:`, default `false` | **Behavioural** | Overwriting a file that a read workbook came from now **throws** where it previously succeeded |
| `Worksheet.changedCells` | Additive | None |

Two of these can break a caller:

**Callers who relied on regeneration.** Someone reading a workbook and saving it to get a
*normalised* archive now gets a preserving one. That is the bug being fixed, but it is a change,
and anyone depending on it should pass `.generated` explicitly.

**Callers who overwrite in place.** `save(to: sameURL)` on a read workbook throws
`destinationExists` unless `overwriting: true`. This is deliberate — §3.4 — and it is the one
change that turns working code into a thrown error. It must be in the release notes, not
discovered.

**Version:** minor bump, not patch. The behavioural change is a fix, but it is visible.

---

## 8. Backend Abstraction

Not applicable. No compute backend; no GPU or platform-specific path.

---

## 9. Dependencies

No new external dependencies. Uses `SwiftZIP` (already a dependency) for reading and writing
entries, and the existing XML parsing in `Reader/`.

**One internal dependency is new:** the splicer needs to *write* XML at a finer grain than the
current writer, which builds strings wholesale. Whether that is a new small component or an
extension of `WorksheetParser` into a rewriter is Open Question 15.2.

---

## 10. Test Strategy

**The fidelity test, which is the whole feature.** Read a workbook with charts, a pivot table and
a macro; change nothing; save surgically; assert **every** entry is byte-identical to the source —
including parts this library has never heard of.

```swift
func testSurgicalSaveWithNoEditIsByteIdentical() throws {
    let original = try Data(contentsOf: fixture)
    let book = try Workbook(xlsxData: original)
    let saved = try book.save(strategy: .surgical)

    let before = try ZIPReader.read(from: original).keyedByPath()
    let after  = try ZIPReader.read(from: saved).keyedByPath()

    XCTAssertEqual(Set(before.keys), Set(after.keys), "part set changed")
    for (path, data) in before {
        XCTAssertEqual(after[path], data, "\(path) was not preserved byte-for-byte")
    }
}
```

**The splice test — §2.1's failure, caught directly.** Read a sheet carrying
`<drawing r:id="rId1"/>` and a `<conditionalFormatting>` block. Change one cell. Assert the saved
sheet still contains both elements, and that every element other than the changed `<c>` is
unchanged. This is the test that fails under the obvious design and passes under §3.2, so it is
the one that justifies the whole proposal.

**Shared-string append-only.** Read a workbook where sheet 2 uses string index 5. Edit only sheet
1, introducing a new string. Assert sheet 2's index 5 still resolves to the same text. No
round-trip-without-edit test can catch this, because it only manifests when the table grows.

**Insert and remove.** Write to a previously empty cell and assert the `<c>` lands in column order
within its `<row>`, and the `<row>` in row order — Excel rejects out-of-order children. Clear a
cell and assert the `<c>` is gone and the rest of the row intact.

**Corpus fidelity.** Round-trip a sample of the 2,236-workbook oracle corpus with no edit,
asserting byte-identity across all of them. This finds the part types nobody listed, which is the
point: §3's default is "preserve," and this proves the default holds on files nobody has seen.

**Excel opens it.** The one thing no unit test proves. A per-release manual checklist: charts
render, the pivot refreshes, the macro runs, no repair dialog. Recorded as a checklist rather than
pretended to be automated.

**Regression.** Every existing `save()` test passes unchanged — `Workbook()` still has no origin
and still takes `.generated`.

---

## 11. Architecture Decision Review

**Decision: splice changed sheets rather than regenerate them.** The alternative — regenerate
sheets from the parsed model, preserve only foreign parts — is simpler and is what a first pass
would build. It fails on §2.1: the writer emits no `<drawing>`, `<conditionalFormatting>`,
`<hyperlinks>`, `<pageSetup>` or `<sheetProtection>`, so any sheet carrying them loses them
silently while the file still opens. Splicing bounds the risk to the cells actually edited.

**Decision: provenance selects strategy.** A `strategy:` parameter defaulting to `.generated`
would preserve source compatibility perfectly and leave the destructive path as the default for
read workbooks — the exact bug, still reachable, now with a knob nobody sets.

**Decision: refuse rather than approximate.** Structural change throws. A fallback to
`.generated` on any unhandled case would be the data-loss path wearing a success return.

**Decision: append-only tables.** Costs archive size over many saves. Compacting would require
rewriting every sheet's indices, including sheets being copied through unparsed — which is
precisely what cannot be done.

---

## 12. Adversarial Review

*Where this breaks, argued against itself.*

**"The splicer is a second XML writer, and now you have two."** True and unavoidable. Mitigation:
the splicer's contract is far narrower — it never constructs a worksheet, only edits `<c>`
elements within one — and the §10 splice test pins it against real files. But this is real added
surface and it should be one component, not logic scattered through `Workbook`.

**"Byte-identity is too strong a bar; ZIP metadata will defeat it."** Likely. Compression level,
entry order, and timestamps may differ even when content matches. §10's tests compare *entry
content* keyed by path, not archive bytes, which sidesteps it. If entry order turns out to matter
to Excel, it becomes a fourth trap.

**"An edit that changes a value's type breaks the `t=` attribute."** Yes — writing text into a
cell that held a number must update `t=` and may add a shared string. Handled in §3.2, and it is
the most likely source of a `spliceFailed` in practice.

**"Preserving `origin` doubles memory."** Yes. §6 and §14.

**"Corpus fidelity will fail on day one."** Probably, and that is the test earning its keep. The
failures are the work list.

**"The user asked for theme and labels; this proposal is mostly about charts."** The mechanism is
the same. A theme is a foreign part and is preserved by §3.1. Labels are cell text in a sheet, so
they are preserved by §3.2 — and would have been *lost* on any sheet carrying an unmodelled
element under the simpler design. The chart is the sharpest demonstration, not the only case.

---

## 13. Alternatives Considered

**Regenerate sheets, preserve only foreign parts.** Rejected; §2.1, §11. Silent loss of charts and
conditional formatting on any edited sheet.

**Extend the parser and writer to model every in-sheet element.** Rejected as the *primary*
approach. It is unbounded — every Excel version adds elements — and it makes fidelity depend on
keeping pace with a moving format. Splicing is bounded by what the caller edits and degrades
gracefully on elements nobody has modelled. Worth doing incrementally for elements callers want to
*manipulate*; not a prerequisite for saving safely.

**Support structural change (add/remove sheets).** Deferred, not rejected. Relationships, content
types and the sheet-path mapping all move together while unparsed parts still reference them.
Doing it properly means understanding every part that can name a sheet. Throws for now; §14.

**A `strategy:` parameter with no provenance default.** Rejected; §11.

**Delegate to a third-party OOXML library.** No mature Swift one exists, and adopting a C library
would put a non-Swift dependency in a package whose value is being pure Swift.

---

## 14. Future Directions

- **Structural change** — sheet add, remove, reorder. Needs a map of every part that can reference
  a sheet by index or relationship id.
- **Streaming** — avoid holding the origin archive in memory for very large workbooks.
- **Modelling more in-sheet elements** — conditional formatting and hyperlinks are the two callers
  will ask to *edit* rather than merely preserve.
- **Chart source ranges** — if this library ever moves cells, charts pointing at them go stale.
  Explicitly not addressed here; the moment it edits a chart it owns charts.

---

## 15. Open Questions

1. ~~**Is `ownedPartPaths` derivable rather than listed?** A hardcoded list rots. Better if the
   reader records which paths it consumed and the writer regenerates exactly those, so the two
   cannot drift.~~ **Answered 2026-09-26: derivable, but from the *writer*, not the reader.**
   `generatedParts()` is the one place that knows, and it is the same code that builds the
   archive. The reader was the wrong source and would have lost data: it reads
   `xl/pivotTables/…`, `xl/pivotCache/…` and each sheet's `_rels`, none of which the writer
   emits, so "what the reader consumed" would have marked those as rewritten and dropped them.
2. ~~**Where does the splicer live?** A new `Writer/WorksheetSplicer.swift`, or an extension of
   the existing reader into a rewriter that retains source offsets?~~ **Answered 2026-09-26: a
   separate `Writer/WorksheetSplicer.swift`.** The whole claim of this feature is "it changed
   nothing else", and the test that says so is a string comparison against the original with one
   substitution applied. Being able to write that test beat being faster.
3. ~~**Does `Worksheet` track changes today?** §4 needs `changedCells` and there is no dirty flag
   now.~~ **Answered 2026-09-26: it did not, and it does now.** The catch was that the parser
   and a caller's `write` share one funnel (`store(_:_:)`), so recording had to start *after*
   the read or every cell of every opened workbook would arrive dirty —
   `beginRecordingChanges()`, called once by `init(xlsxData:)`. A workbook composed in code
   never records, so that path costs one `Bool` test per write.
4. **Does entry order in the ZIP matter to Excel?** §12. If it does, the origin's order must be
   preserved too, not just its contents.
5. ~~**What does a corpus fidelity run actually fail on?** Unknown until run, and it is the most
   informative number in this proposal. Run it before step 3.~~ **Answered 2026-09-24, §18.**
   57% of all parts, 98% of workbooks — and, unexpectedly, the sheet model is lossy too.

---

## 16. Documentation Strategy

DocC on all seven new public symbols. Beyond the reference:

- **"Saving a workbook you did not create"** — the strategy split, what is preserved, what is
  spliced, and the `overwriting:` requirement. The article a caller reads before their first
  write-back.
- **"What a surgical save cannot do"** — structural change, chart source ranges, and the honest
  statement that elements nobody has modelled are preserved but not *understood*, so this library
  will not help you edit them.
- **Release notes** — §7's two behavioural changes stated prominently. The `overwriting:` throw is
  the one that turns working code into an error.

---

## 17. Sequencing

| # | Deliverable | Ends when |
|---|---|---|
| **1** | Corpus fidelity harness, run against today's `save()` | Open Question 15.5 has a number; the failure list is the work list |
| **2** | Retain `origin`; `SaveStrategy`, `SaveManifest`, `Worksheet.changedCells` | The manifest is right on a real workbook. Nothing saves differently yet |
| **3** | Surgical save, foreign parts byte-for-byte, unchanged sheets copied through | §10's no-edit fidelity test passes |
| **4** | The splicer — replace, insert, remove, `<dimension>` | §10's splice test passes: a chart and its conditional formatting survive an edit |
| **5** | The three archive traps: append-only tables, drop `calcChain`, `fullCalcOnLoad` | The shared-string test passes |
| **6** | Corpus fidelity green + the manual Excel checklist | A real model with charts, a pivot and a macro survives an edit |

Step 1 is a measurement, not a build, and it tells you how bad the problem is before you design
around a guess.

---

**Next action:** step 1. Round-trip a corpus sample through today's `save()` and count what
changes. That number is the argument for everything above it.

---

## 18. Step 1: what the round trip actually loses

**Measured 2026-09-24.** Fifty workbooks from the `~/Documents` corpus, each read with
`Workbook(xlsxData:)` and written straight back with `save()`, the two archives compared. The
corpus is private, so only shapes and counts are recorded here — no paths, no content.

### 18.1 Parts

| | |
|---|---|
| workbooks losing at least one part | **49 of 50 (98%)** |
| parts in / parts out | 1,440 → 624 |
| parts lost | **816 (57% of everything in the archives)** |

By kind:

```
128  worksheet rels      95  charts          43  xl (misc)
123  pivotCache          84  pivotTables     18  externalLinks
112  drawings            48  tables          14  chartsheets
 97  docProps            46  theme           12  printerSettings, 3 media
```

The single workbook that lost nothing had nothing to lose: no charts, no pivots, no theme.

### 18.2 Workbook-level elements

Regenerating `xl/workbook.xml` drops what the writer does not model, whether or not the parts
it points at survive:

| element | present in | survived |
|---|---:|---:|
| `<calcPr>` | 50 | **0** |
| `<externalReference>` | 2 | **0** |
| `<definedName>` | 26 | 26 |

`externalReferences` is the sharpest case and the one that motivated this measurement. A model
whose price deck is linked as `'[2]Oil&Gas'!AZ3` keeps the formula *text* through a round trip
and loses the table that says what `[2]` is. The formula survives as a reference to nothing.

### 18.3 The finding that was not anticipated — **and 18.3 as first written was wrong**

**Retracted 2026-09-26.** This section originally reported that the sheet model was lossy:
cell counts moving by −12,975, −113 and +9,185 and formula counts by −97. Every one of those
was an artefact of the harness, not a defect in the library. Step 2a was added to the plan on
the strength of them, which is the cost of publishing a number without auditing the instrument
that produced it.

What was wrong, in the order it was found:

| reported | actual cause |
|---|---|
| −12,975, −113, −3 cells | All bare `<c r="X"/>` — no style, type, value or formula. They carry nothing and dropping one is not a loss. 13,100 across the sample |
| −97, −3 formulas | The counter matched `<f`, which also prefixes `<filter>`, `<filters>` and `<filterColumn>` — autoFilter criteria, not formulas |
| +9,185 cells | The counter matched `<c r=`, assuming `r` comes first. OOXML fixes no attribute order and a Google Sheets export writes `<c t="s" s="12" r="A1">`. One input was undercounted by 6,904 cells and the writer was blamed for inventing them |

Re-measured with the instrument fixed, over the same fifty workbooks:

| | |
|---|---|
| workbooks losing a meaningful cell | **0 of 50** |
| workbooks whose formula count changed | 3 of 50, all **gains** |

So the sheet model round-trips its cells faithfully, as §2.1 assumed. **Step 2a is withdrawn.**

### 18.3a What was under it: array-formula members were written as `<f/>`

Chasing the smallest surviving delta — +13 formulas in a 322-cell workbook — found a real
defect, and a narrow one. The sheet holds

```
<c r="E4" s="10"><f t="array" ref="E4:K5">TRANSPOSE(O3:P9)</f><v>0.818…</v></c>
<c r="F4" s="13"><v>0.912…</v></c>
```

`E4:K5` is fourteen cells; Excel writes the formula once at the anchor and gives the other
thirteen a cached value and nothing else. Thirteen was the delta exactly.

The reader is right about these: it marks each member `_ARRAY(anchor, span)` — *computed by
its anchor* — rather than copying the formula onto all fourteen. The writer had a branch for
that sentinel which emitted an **empty `<f/>`**, with a comment asserting that is what Excel
does.

It is not. Measured over every array master in the corpus sample — **32,826 member cells** —
all of them carry no `<f>` element and **not one** carries an empty `<f/>`.

Fixed 2026-09-26: a member is written as its cached value alone, and self-closing when it has
none. The anchor keeps `t="array" ref=`, which is what a reader rebuilds the span from, so a
round trip still reports every member as array-entered. `ArrayFormulaWriteBackTests` covers
the emptiness, the members, the anchor, the re-read, and the `_DATATABLE` sentinel beside it.
On the workbook that produced the finding, the formula count now matches the source exactly —
139 in, 139 out, zero empty `<f/>`.

### 18.3b Two losses the corrected instrument did find

| | present in | survived |
|---|---:|---:|
| **chartsheets** | 7 parts, 5 workbooks | **0** |
| **autoFilter criteria** (`<filter>`) | 1 workbook | **0** |

The chartsheet case is the more serious and is not in §2.1's table. A chart sheet is a
`<sheet>` entry in `workbook.xml` pointing at `xl/chartsheets/sheetN.xml`. The reader takes
the entry and cannot parse the part, so the sheet arrives empty; the writer then emits it as
`xl/worksheets/sheetN.xml`. **A chart tab comes back as a blank grid**, and every part number
after it shifts by one. Seen in the corpus as `Monthy Subs Chart`, the first tab of a
54-sheet workbook.

autoFilter criteria are smaller but the same shape: §2.1 records `autoFilter` as read and
written, and only its *range* is — the `<filterColumn>`/`<filters>`/`<filter>` children that
say what is actually filtered are dropped.

### 18.4 Two amendments to the design

**§3.2 must handle shared formulas, and they are not rare.** A shared formula is written
`<f t="shared" si="47"/>` — self-closing, its text held by a master cell elsewhere in the sheet.
Two consequences the splicer cannot ignore:

- Any regex or parser that matches only `<f>…</f>` silently skips every follower. Applying cached
  values to `DNREARN.xls` hit exactly this: the write-back stalled on the first shared-formula
  cell in the dependency cone and iterated twenty rounds without converging, because the values
  were computed, reported, and never written. One sheet in that model has 4,063 of them.
- Splicing a cell that is the **master** of a shared range breaks every follower that refers to
  its `si`. The splicer must either expand the range first or refuse, and `SaveError` needs a case
  for it.

**§3.3's `fullCalcOnLoad` rule is right for honesty and wrong for legibility, and the workbook
should choose.** Setting it makes Excel discard the cache and recalculate, which is correct when
every function in the file is one Excel knows. It is destructive when the file contains add-in
calls: a Risk Solver model opened without the add-in recalculates `_xll.PsiNormal(…)` to `#NAME?`
and cascades that through everything downstream. The stale cache was more useful than the honest
recalculation.

The better answer is now available: **recalculate with `SwiftExcelFunctions` and write the values
in**, leaving `<calcPr>` alone. That was done by hand for `DNREARN` — iterate the oracle, write
back every cell where we produce a clean number the cache disagrees with, repeat to a fixed point
(19 rounds) — and it ended with the workbook's finding set identical to the untouched original.
That argues for a third option alongside `.generated` and `.surgical`, or a parameter on
`.surgical`:

```swift
/// What to do about cached values that an edit invalidated.
public enum StaleValuePolicy: Sendable, Equatable {
    /// Set `fullCalcOnLoad`, and let Excel sort it out. Honest; unreadable if the
    /// workbook calls functions Excel cannot resolve on its own.
    case markForRecalculation
    /// Recompute and write the values in. Needs an evaluator, so it cannot live here.
    case recomputed
    /// Leave the cache alone. For a caller who knows the edit changed nothing downstream.
    case untouched
}
```

**Built 2026-09-26, and simpler than this sketch.** `.recomputed` turned out not to be a case
at all: a caller who has an evaluator writes the recomputed values in as ordinary cell edits,
and the splice puts them where they belong. No closure, no dependency on an evaluator this
package does not have. Two cases, `.markForRecalculation` and `.untouched`, and the default is
the first.

The implementation handles three shapes of `<calcPr>`: add the attribute to an existing
element keeping its `calcId`; correct an explicit `fullCalcOnLoad="0"`, which an edit has just
made wrong; and create the element where there is none — **before `<extLst>`**, because the
schema fixes the order of a workbook's children and Excel repairs a file that gets it wrong by
deleting what it could not place.

### 18.5 What this does to the sequencing

§17 step 1 is done. Its output is a work list, and it reorders what follows:

| # | was | now |
|---|---|---|
| 1 | corpus fidelity harness | ✅ done, §18 |
| 2 | retain `origin`, manifest | ✅ **done 2026-09-26.** `SaveStrategy`, `SaveManifest`, `SaveError`, `defaultSaveStrategy`, `saveManifest(strategy:)`, `Worksheet.changedCells`/`hasUnsavedChanges`. `save()` unchanged. Open question 15.1 answered: the owned set comes from the writer, because the reader consumes more than the writer emits |
| ~~2a~~ | — | ~~diagnose the negative cell deltas~~ **withdrawn — the deltas were the harness's, §18.3. It produced one real fix (§18.3a, shipped) and two new losses to carry into steps 3 and 4 (§18.3b)** |
| 3 | surgical save, parts byte-for-byte | unchanged — §18.1 says this alone recovers 57% of the archive |
| 4 | the splicer | **add shared-formula handling (§18.4)** |
| 5 | the three archive traps | **add `StaleValuePolicy` (§18.4)** |
| 6 | corpus fidelity green | re-run this harness; it is the pass/fail |

**Next action:** none. Every step of this proposal is done — see §20 for what is deliberately
still not supported.

---

## 20. What a surgical save still cannot do

Recorded 2026-09-26, once steps 1–6 were done, because "preserved but not understood" is the
honest description of most of this and the article §16 promises should say so.

**Structural change is refused.** Adding, removing or reordering sheets moves part paths that
preserved relationships, the content types and every unspliced sheet still point at.
`SaveError.structuralChangeUnsupported`.

**A chart sheet cannot be edited.** The reader has no parser for `xl/chartsheets/sheetN.xml`, so
one arrives looking like an ordinary empty worksheet — and arrives *first* in the corpus
workbook this was found in, which is what `sheets.first` reaches for. Writing worksheet XML over
that part would put a blank grid where a chart was, so it throws.

**A shared formula's master and an array formula's anchor cannot be edited.** Their text and
`ref` are what every follower or member depends on, and replacing one would break cells the
caller never touched. Expanding the group first would lift this; refusing is what it does now.

**Nothing understands what it preserves.** Conditional formatting, page setup, pivot caches,
`dxfs`, theme colours and the rest come through byte for byte and cannot be *edited* through
this library — it will not help you change a chart's source range or a pivot's field list.

**A chart's source range does not follow an insert.** Writing past the end of a sheet widens
`<dimension>`; it does not update a chart, a pivot cache or a defined name that referred to the
old extent.

Steps 1–4 are done, 2a is withdrawn, and step 5 is two-thirds done. What is left is the one
thing §18.4 amended rather than inherited: `fullCalcOnLoad` is honest and wrong for a workbook
whose formulas Excel cannot resolve alone, and the alternative — recompute and write the values
in — needs an evaluator this package does not have. It is a closure the caller supplies.

Also outstanding and not yet scheduled:

- **The style table.** The reader parses `xl/styles.xml` into `ParsedStyleSheet` and never fills
  the workbook's `StyleSheet`, which is why a styled new cell is refused. Loading it would lift
  that, and is the same defect shape as the shared strings fixed in step 4.
- **Old step 4 note, now obsolete:** autoFilter criteria needed nothing — an unchanged sheet is
  copied byte for byte, and a spliced one keeps everything it did not touch. Steps 1, 2 and 3 are done; 2a is withdrawn (§18.3).

Both of §18.3b's losses turned out to be fixed by step 3 rather than needing work of their own:
preserving the original parts keeps chartsheets as chartsheets, and an unchanged sheet copied
through byte for byte keeps its autoFilter criteria along with everything else in it. What step
3 left is narrower than the proposal expected: **an edit still costs the unmodelled elements of
the one sheet it touched**, because that sheet is regenerated. That is exactly what §3.2 is for.

Three things step 3 learned that step 4 should carry:

1. **Shared formulas** (§18.4). `<f t="shared" si="47"/>` is self-closing, and splicing a
   *master* breaks every follower pointing at its `si`. `SaveError` needs a case for it.
2. **A tab is not always a worksheet.** A chart sheet arrives looking like an empty worksheet
   and is first in the tab order in the corpus workbook this was found in. Step 3 refuses to
   write worksheet XML over `xl/chartsheets/…`; the splicer inherits that guard.
3. **The index tables.** Regenerating a sheet forces `sharedStrings.xml` and `styles.xml` out
   with it. A splice touches neither, which is §3.3's append-only rule getting easier rather
   than harder — and is most of why step 4 is worth doing.


---

## 19. Step 6: the corpus, with an edit applied

**Measured 2026-09-26.** Every figure quoted for steps 3 and 4 until now was either the
*unedited* case over fifty workbooks or the edited case over *one*. This is the run that covers
the gap: open each workbook, write one cell, save, and check what it cost.

Two passes, because replacing a cell and inserting one exercise different halves of the splicer
and mixing them would make a failure impossible to attribute.

### 19.1 Replacing the sheet's first populated cell

| | |
|---|---:|
| workbooks | 50 |
| refused or threw | **0** |
| re-readable after saving | **50 / 50** |
| the edit reads back correctly | **50 / 50** |
| every *other* sheet byte-identical | **50 / 50** |
| unmodelled in-sheet elements preserved | **50 / 50** |
| cell count unchanged | **50 / 50** |
| formula count unchanged | **50 / 50** |

Sheet XML byte delta: median **0**, maximum **17**. Parts touched per edit: one for the
fourteen workbooks with no calculation chain, three for the thirty-six with one — the sheet, the
chain, and the content types that declared it.

**The median of zero is a coincidence of the test value, not a no-op**, and it is worth writing
down because it looked like one. The first populated cell of most sheets is a text header:
`<c r="A1" s="3" t="s"><v>0</v></c>` becomes `<c r="A1" s="3"><v>123.456</v></c>`, which drops
`t="s"` (six bytes) and grows the value from `0` to `123.456` (six bytes). Confirmed by hand on
one workbook — one part changed, and the sheet is identical apart from `A1`.

### 19.2 Inserting a cell past the end of the sheet

Two columns and three rows beyond `lastPopulatedCell`, so a `<row>` has to be created and the
`<dimension>` widened.

| | |
|---|---:|
| refused or threw | **0** |
| re-readable, and the edit reads back | **50 / 50** |
| every other sheet byte-identical | **50 / 50** |
| unmodelled elements preserved | **50 / 50** |
| formula count unchanged | **50 / 50** |
| cell count exactly +1 | **50 / 50** |
| `<dimension>` widened | **46 / 46** that had one |

The four without a `<dimension>` are left without one: absent is legal, and inventing one is a
change nobody asked for.

### 19.3 Excel, opened

**Verified 2026-09-26, Excel for Mac.** `DNREARN-edited-one-cell.xlsx` — the decomposed Goldman
model with `Production!BU8` (the 1Q04 oil rate) changed from `18.1` to `123.456`, 32 of its 33
parts byte-identical to the file it came from.

| | |
|---|---|
| repair dialog | **none** |
| prompt shown | the external-links trust prompt, *"This workbook contains links to one or more external sources"* |
| sheets | all four — `SnapShot`, `Reserves`, `template`, `Production` |
| the edit | `Production!BU8` reads **123.46** in the 1Q04 column |
| derived day counts | row 6 computes `90, 91, 92, 92` for 2006 from the quarter-end dates |
| an untouched sheet's formulas | `Reserves!J21` reads `=J39+J48/6` |

**The link prompt is the pass, not a caveat.** It is the standard prompt any workbook with
external references shows, and it can only appear because `<externalReferences>` and the three
`xl/externalLinks/` parts came through — the exact table that a regenerated `xl/workbook.xml`
drops, leaving `'[2]Oil&Gas'!AZ3` pointing at nothing and no prompt at all.

**2Q06 reading 91 days is the other thing worth naming.** That is the day-count defect from the
original model, corrected by the decomposition and now computed by *Excel* from the quarter-end
dates rather than asserted by this package's reading of the XML.

Not separately confirmed: the two charts, which live on sheets the screenshots did not show.

### 19.4 The harness, now in the repository

~~§17 calls this run "the pass/fail", and it currently lives in a throwaway package outside the
repository.~~ **Moved 2026-09-26.** `swift run save-fidelity <corpus> --edit none|replace|insert`
— `Sources/SaveFidelityTool`, the same shape as `workbook-oracle` and `name-round-trip`: a row
per workbook, flushed, the output file as the resume state, and a marker naming the file being
opened so a workbook that kills the run costs one workbook rather than the rest of it.

It reproduces §19.1 and §19.2 exactly, and reports a summary rather than a table to read by
eye:

```
workbooks 50   edit replace
  ✓ no part lost but the calculation chain: 50/50
    (the chain was dropped in 36 of 50; the rest had none to drop)
  ✓ re-readable after saving: 50/50
  ✓ the edit reads back: 50/50
  ✓ every other sheet byte-identical: 50/50
  ✓ unmodelled elements preserved: 50/50
  ✓ externalReferences preserved: 50/50
  ✓ calcPr preserved: 50/50
  ✓ chartsheets preserved: 50/50
```

Two things it taught while being written down. The corpus is **2,242 workbooks**, not the fifty
every figure here is drawn from — the samples are a first fifty in sorted order, and a full run
is available now that re-running is cheap. And the first version of the summary marked the
dropped calculation chain as a lost part, failing thirty-six correct saves: an edit is *meant*
to drop it, and a gate that cries wolf is one people learn to skip.
