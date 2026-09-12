# Design Proposal: Surgical Save — editing a workbook without destroying it

**Status:** proposal, 2026-09-08. Ready for RED.
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

1. **Is `ownedPartPaths` derivable rather than listed?** A hardcoded list rots. Better if the
   reader records which paths it consumed and the writer regenerates exactly those, so the two
   cannot drift. Prefer that if it is not awkward.
2. **Where does the splicer live?** A new `Writer/WorksheetSplicer.swift`, or an extension of the
   existing reader into a rewriter that retains source offsets? The second is faster and more
   faithful; the first is easier to test in isolation. §9.
3. **Does `Worksheet` track changes today?** §4 needs `changedCells` and there is no dirty flag
   now. Where it lives affects whether `write(_:to:)` gets slower for the composed-in-code case,
   which must not regress.
4. **Does entry order in the ZIP matter to Excel?** §12. If it does, the origin's order must be
   preserved too, not just its contents.
5. **What does a corpus fidelity run actually fail on?** Unknown until run, and it is the most
   informative number in this proposal. Run it before step 3.

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
