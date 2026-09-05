# Changelog

> **Tags are `vX.Y.Z` as of 2026-09-01.** Every tag through 0.7.0 was recreated in that form on
> its original commit and the unprefixed tags removed. Commits are unchanged, and SwiftPM treats
> `v0.7.0` and `0.7.0` as the same version, so `exact: "0.7.0"` in a consumer's manifest keeps
> resolving to the same revision. Version *numbers* in this file remain unprefixed.

## [Unreleased]

## [0.16.0] - 2026-09-05

### Fixed

- **Array-formula members no longer read as constants.**

  A legacy array formula is stored once, at the top-left cell of the range it
  fills, with a `ref` naming the span. Every other cell in that span carries an
  empty `<f/>` and its cached value:

  ```xml
  <c r="D55"><f t="array" ref="D55:D174">+TRANSPOSE(consol!H35:DW35)/1000</f><v>0</v></c>
  <c r="D56"><f ca="1"/><v>-0.5</v></c>
  ```

  The reader captured `t` but never acted on `"array"` and never read its `ref`,
  so the members fell through to their cached value — exactly the failure the
  shared-formula and data-table branches already guard against, and their comment
  already names: *"that would turn a computed cell into a constant silently."*
  One workbook in the measured corpus lost **224 cells** that way, each a computed
  cell presenting as an input.

  Members are now marked `_ARRAY(anchor, span)` — computed *by* the anchor rather
  than given a copy of its formula. That is the real dependency, since the formula
  evaluates once and fills the rectangle; copying it would claim each of 120 cells
  independently recomputes the whole array. The dependency graph picks the anchor
  up from the marker's first argument with no further work: reading the workbook
  above now gives D55 its 119 dependents.

  An empty `<f/>` outside every span is untouched.

## [0.15.0] - 2026-09-05

### Changed

- Depends on SwiftExcelCore `0.3.0`, in which `CellValue.array` carries a `CellMatrix`
  rather than a flat `[CellValue]`.

  Nothing here needed editing. The single site that touches the case is a bare
  `case .array:`, which matches regardless of payload — so this is a rebuild against a
  breaking upstream change, not an adoption of one. `Workbook`'s `CellValueProvider`
  conformance picks up the new shaped read from the protocol's default implementation.

### Breaking

- Transitively, through the re-exported SwiftExcelCore: callers that bind the payload of
  `CellValue.array` need updating. See SwiftExcelCore's 0.3.0 entry for why.

## [0.14.0] - 2026-09-04

**The parser reads what real workbooks contain.** Measured across 79 of them — teaching models, a
production credit model and a 104-sheet media model — formulas that fail to parse fall from
**292,437 to 17**, of 549,059. From 53% of the corpus to 0.003%.

### Added
- **Omitted arguments.** `IFERROR(B5/C5-1,)` and `ADDRESS(r, c, 1, , "Sheet")` parse, with the
  empty position becoming `FormulaAST.missing`. The comma marks the place because position decides
  which parameter is which. ~21,500 formulas.
- **Whole-column and whole-row ranges**, with and without `$`: `$E:$E`, `A:A`, `$2:$3`, `Comp!1:1`,
  `'Lease Revenue'!$2:$3`. They become ordinary ranges over Excel's grid, so no new AST case was
  needed. ~135,000 formulas.
- **Underscores and dots inside words.** `days_per_week`, `COVARIANCE.P`, and the `_xll.` and
  `_xlfn.` prefixes Excel writes for add-in and newer-than-the-format functions. ~116,000 formulas.
- **A percent suffix.** `L4+0.25%` — a scale on the number just read, not an operator.
- **An error literal after a sheet name.** `CB_DATA_!#REF!`.
- `FormulaToken.columnRef` and `.rowRef`, produced only for a `$`-marked word that names only a
  column or only a row.

### Changed
- **`DependencyGraph` no longer enumerates enormous ranges.** Above 4,096 cells a range is
  intersected with the cells that exist. This is not a cap but the better answer: `$B:$G` is a
  request for whatever is in those columns, not for 6,291,456 addresses, and the corpus writes such
  a range about 135,000 times. Below the limit nothing changed — `A1:A5` still names five cells
  whether or not they hold anything.
- Depends on **SwiftExcelCore 0.2.0** for `FormulaAST.missing`.

### Fixed
- `testMissingFunctionArgAfterComma` asserted that an omitted argument throws. It was wrong about
  Excel, and now asserts the parse.

### Notes
What remains unparsed is 17 formulas: 12 nesting `INDIRECT(ADDRESS(...))` inside `ISREF`/`INDEX`,
3 with a range whose endpoint is a function call, and 2 array literals `{10,20,30}`. Array
literals would need a new `FormulaAST` case for two formulas, which is not a trade worth making
today.

## [0.13.0] - 2026-09-04

**The function library moved to SwiftExcelFunctions.** This package is now syntax and storage:
lexer, parser, serializer, reader, writer, styles, and the dependency graph.

### Removed
- The 73 built-in Excel functions across the eight `Builtin*Functions` files.
- `FunctionRegistry`, `ExcelFunction`, `FormulaEvaluator`, `EvalError`.

They are in [SwiftExcelFunctions](https://github.com/jpurnell/SwiftExcelFunctions), which depends
on SwiftExcelCore and BusinessMath. A caller that evaluated formulas through this package adds
that dependency and imports it; a caller that reads and writes files needs no change.

**Not re-exported, unlike the 0.12.0 extraction.** That one moved types this package still
traffics in, so `import SwiftXLSX` had to keep seeing them. These leave outright: a file reader
has no business owning what `AVERAGE` means, and a re-export would preserve the old shape while
claiming the new one.

### Changed
- `FormulaParserIntegrationTests` moved to SwiftExcelFunctions. Its 49 cases parse a formula here
  and evaluate it there, so it belongs with the evaluator and takes a test-only dependency back on
  this package for the parser.

### Notes
- 722 tests here, 546 there. The 1,268 split with none lost.
- Verified before removing: nothing else in this package referenced them, SwiftZIP is a dependency
  of this package rather than a consumer, and BusinessMathExcel's references are all to
  BusinessMath's unrelated generic `FormulaEvaluator<Double>`.

## [0.12.0] - 2026-09-04

**The spreadsheet vocabulary moved to SwiftExcelCore.** `CellValue`, `CellRef`, `CellRange`,
`CellAddress`, `SheetReference`, `ExcelError`, `FormulaAST`, `NamedRange` and the
`CellValueProvider` protocol now live in a separate Foundation-only package, so a function library
and a file reader can share them without depending on each other.

**Source-compatible.** This package re-exports SwiftExcelCore with `@_exported`, so
`import SwiftXLSX` still sees every one of those types and no existing caller needs a second
import. Verified against a downstream consumer: BusinessMathExcel's 564 tests pass with no source
change.

### Changed
- Depends on **SwiftExcelCore 0.1.0**, pinned `exact:`.
- `WorkbookValueProvider` split into its own file. It was sharing one with the
  `CellValueProvider` protocol it conforms to; the protocol is the seam that lets a function
  library read cells without a workbook, and it moved, while the conformance needs a `Workbook`
  and stayed.

### Notes
- `EvalError` stayed. It is internal, and documented as evaluation's own error type "mapped to
  `ExcelError` at the boundary" — the function library's business rather than the vocabulary's. It
  will travel with the functions when those move to SwiftExcelFunctions.
- `CellValueWriteTests` is new, holding three cases lifted from `CellValueTests`: they write
  through a `Worksheet` and read the value back, which asserts what storage does rather than what
  the value type is.
- 1,268 tests passing; 170 more moved to SwiftExcelCore with the types they cover.

## [0.11.1] - 2026-09-03

### Fixed
- A `$` marker is not a different cell. `DependencyGraph` treated `$B$3` and `B3` as distinct
  nodes, so a graph over a sheet using absolute references split into disconnected pieces and
  under-reported both dependents and precedents.

Released rather than retagged: `v0.11.0` had already been consumed downstream, and moving a
published tag breaks SwiftPM's trust-on-first-use fingerprint for every consumer that recorded it.

## [0.11.0] - 2026-09-03

A dependency graph can be built over part of a workbook.

`DependencyGraph(workbook:)` answers the question a spreadsheet *evaluator* asks: in what order
must every cell be visited? For that, every cell belongs — labels included, and a
referenced-but-empty cell too, because you still have to visit it to learn it is zero.

A caller recovering a *model* from a sheet is asking something else: which quantities depend on
which. There a title in `A1` is not a node, and a reference to an empty cell is not an input.
Filtering the whole-workbook graph afterwards does not answer it, because by then the topological
order and the cycle set have already been computed over the unfiltered set. The scope has to be
given before the graph is built.

### Added
- `DependencyGraph(sheet:including:)` and `DependencyGraph(workbook:including:)`. A reference to a
  cell the scope excludes — on another sheet, or failing the filter — is dropped along with its
  edge, rather than pulling a foreign or empty cell in. Sheet scoping applies whether or not a
  content filter is given.
- `DependencyGraph.allCells` is now public. `evaluationOrder` is empty when the graph has a cycle,
  so without this there was no way to enumerate membership at all — which is the first thing a
  caller asks of a scoped graph.

### Fixed
- A `$` marker split a cell into several graph nodes. `CellRef` hashes its markers, so a formula
  reading `$C12` produced a phantom node beside the real `C12`, with the edges divided between
  them — and under a filter the marked form fell out of scope, so the edge was dropped entirely
  and the cell looked as though nothing read it.

  That is not a small error on real models: a mixed reference is how a rule fills across a row
  while holding one operand still, so the edges lost are exactly the ones tying every period back
  to its assumptions. Found on a teaching model whose four decision variables all appeared to be
  unread, because every formula reached them as `$C12`.

`DependencyGraph(workbook:)` is otherwise unchanged, and a test pins that: labels still counted,
every sheet still walked, referenced empty cells still nodes.

## [0.10.0] - 2026-09-03

A formula can be written with the value it last computed. The reader has always surfaced both —
the rule in `<f>` and the result in `<v>` — and the writer could only ever say the first, so a
`Workbook` built in code could not be made to look like one read from disk.

That matters most for tests of the reader's own shapes. A data table's body is cached numbers
under a single marker; a shared formula's dependents are cached values with empty `<f>` elements.
Anything exercising those had no way to build a fixture without a real file.

The third gap of this shape after 0.8.0 and 0.9.0: information the reader understood, with no way
for a caller to state it.

### Added
- `Worksheet.write(_:to:cached:style:)`: a formula and the value Excel last computed for it. The
  existing overload is unchanged and still writes no cached value.

## [0.9.0] - 2026-09-02

A cell's presentation survives the read. The reader has resolved each cell's style since it was
written — Excel's built-in number formats included, so `numFmtId="9"` arrives as `0%` — and then
stored it where no caller could reach it: `Worksheet.cells` is internal and `private(set)`, and
nothing else exposed a style.

The format is not decoration. It is often the only statement a workbook makes about what a number
*is*: `0.4` in a cell formatted `0%` is a margin, the same `0.4` formatted `"$"#,##0` is money,
and the label beside it may say neither.

### Added
- `Worksheet.style(at:)`: the `CellStyle` applied to a cell, or `nil` when the cell holds nothing.

## [0.8.0] - 2026-09-02

Named ranges survive the read. `xl/workbook.xml` has been parsed for defined names since the
reader was written, and the result was thrown away twice over — once at the parse call
(`let (sheetInfos, _) = ...`) and again in `Workbook.init(xlsxData:)`, which adopted only the
sheets. A formula referring to a named range therefore reached callers as
`FormulaAST.namedRange("Circ")` with nothing on the public API to look `Circ` up in, which makes
the reference unresolvable rather than merely inconvenient.

Real models lean on named ranges for exactly the values a reader most wants: switches, rates,
and the single cell a whole model keys off. The Wharton LBO practice model routes its
circularity toggle through one, and a consumer could read every formula in that workbook without
being able to say what any of them meant.

### Added
- `Workbook.namedRanges`: the file's names as a `NamedRangeCollection`. Empty for a workbook this
  library built, since the writer defines none.

No new type: `NamedRange`, `NamedRangeTarget`, `NameScope`, and `NamedRangeCollection` have been
here since 0.1.0 for the authoring side, and the read side now produces the same values the
write side consumes. A reader-only `DefinedName` would have been a second name for one idea.

A name's target is parsed into `.sheetCell` or `.sheetRange` where the file states a reference.
Excel permits any formula there, so anything else is kept verbatim as `.formula(.text(…))` —
a name whose target cannot be parsed is still a name, and what the file said beats a cell
invented for it. Scope comes from `localSheetId`, which is an index into the sheets rather than
a name; resolution is `NamedRangeCollection`'s, so a sheet-scoped name takes precedence over a
workbook-scoped one of the same spelling. Excel's own `_xlnm.` page-setup entries are kept
rather than filtered, leaving the caller to decide what to ignore.

## [0.7.0] - 2026-09-01

Formula cells written by Excel are now read as formulas. Until this release, a cell whose formula
was stored elsewhere in the file — which is how Excel stores most repeated formulas — was read as
the constant Excel had cached in it.

### Fixed
- **Shared formulas were silently read as constants.** Excel writes a repeated formula once, on
  its group's master cell, as `<f t="shared" ref="B2:B4" si="0">A2*2</f>`; every other member
  carries only `<f t="shared" si="0"/>` with no text, its formula being the master's with relative
  references shifted by the offset between them. `WorksheetParser` had no `t="shared"` handling,
  so those cells fell past the empty `<f>` to their cached `<v>` and became `.number`.

  On the Wharton LBO Practice Model this was **81 of 155 formula cells on one sheet** — computed
  cells posing as inputs, with no error and no warning. Substituting a cached result for a formula
  is the exact failure this library's consumers are built to avoid, and it was happening in the
  reader.

  Members met before their master are held and resolved when the sheet ends, so document order
  does not matter. A group whose master never appears is marked `_SHARED` rather than falling back
  to a value.
- **What-If data tables were silently read as constants**, by the same mechanism:
  `<f t="dataTable" ref="P6:T10" r1="D11" r2="D21"/>` is self-closing and carries no text. Now
  read as `_DATATABLE(span, input1, input2)`, preserving the span and input cells that identify
  the table.

### Added
- `SharedFormula.translate(_:rowDelta:columnDelta:)` — shifts relative references and pins
  absolute ones, the rule Excel applies when filling a formula. References shifted off the sheet
  become `#REF!`, matching Excel.
- `ForeignWorkbookReadTests` gains shared-formula and data-table coverage: translation across rows
  and columns, absolute references staying pinned, ranges translating as units, and the master
  keeping its own formula.

### Known gaps
- Percent literals do not lex: `=P5+2%` parses as `_RAW`. Eight cells on the Wharton model. Loud
  rather than silent, so the formula-cell invariant holds, but the formula is not usable.

## [0.6.0] - 2026-09-01

Reading a workbook this library did not write now works. Until this release it did
not, for any file Excel produced, and it failed by returning an empty workbook rather
than an error.

### Fixed
- **The reader could not open any workbook Excel writes.** `WorkbookReader` located the
  main document part with `type.contains("officeDocument")`. Several OOXML relationship
  types live under the `.../officeDocument/2006/relationships/` namespace, so that
  substring also matches `.../relationships/extended-properties` — which Excel lists
  *first* in `_rels/.rels`. The reader therefore selected `docProps/app.xml`, which is
  well-formed XML containing no `<sheet>` elements, and returned a workbook with **zero
  sheets and no error**. Now matched by exact type: only the main document part ends in
  `/officeDocument`.

  Every existing reader test round-tripped through this library's own writer, whose
  `_rels/.rels` happens to list the workbook relationship first, so the entire test
  suite passed against a reader that could not open a real spreadsheet. `Tests/
  SwiftXLSXTests/ForeignWorkbookReadTests.swift` closes that gap by assembling packages
  shaped the way Excel shapes them, rather than the way we do.
- Relationship targets are resolved rather than concatenated. A package-absolute target
  (`/xl/workbook.xml`) was appended to the workbook directory, producing `xl//xl/...`,
  which matches no ZIP entry; `.` and `..` segments were not collapsed at all. Both forms
  are legal OOXML. `WorkbookReader.resolvePart(_:relativeTo:)` now handles the three
  shapes a target can take.

### Added
- DocC catalogue (`Sources/SwiftXLSX/SwiftXLSX.docc`) curating all 44 public types
  into eight topic groups; declared as a target resource so SwiftPM stops reporting
  it as an unhandled file.

### Changed
- SwiftZIP dependency now requires `0.6.0`, a real published release. The manifest
  previously required `0.5.0`, a tag that has never existed: the revision
  `Package.resolved` had pinned under that version left SwiftZIP's history during a
  refactor, taking the tag with it, so resolution failed outright. It was first
  corrected to `0.3.0` (the only surviving tag, and sufficient — every SwiftZIP API
  used here is present in it), then raised to `0.6.0` once that release was cut.
  SwiftZIP skipped `0.4.0` and `0.5.0` on purpose so no version string is ever reused
  for different content.
- `WorkbookTests` reads archives with `SwiftZIP.ZIPReader` instead of spawning
  `/usr/bin/unzip` via `Process`. Removes the external binary dependency from the
  test suite and drops those tests from ~0.150s to ~0.010s.
- `LOG(number, base)` states its float comparison as `!base.isEqual(to: 1)` rather
  than `!=`. Behaviour is unchanged: only exactly 1.0 is rejected, matching Excel,
  which returns very large values for bases merely near 1.
- Doc-comment examples on 13 public symbols now compile. They previously referenced
  undefined values (`registry`, `wb`, `myProvider`, `myResolver`), returned `()` where
  a `CellValue` was required, or called the internal `FormulaParser.parseTokens`.
- README no longer claims "zero external dependencies"; it names the SwiftZIP
  dependency and states what is actually true (no C or system libraries, no shelling out).

### Fixed
- Force unwrap in `WorkbookTests.testWriteFormula` replaced with `XCTUnwrap`.
- `.quality-gate.yml` used two keys this gate version does not recognise
  (`checkers`, `exclude`), so the configuration was silently inert and five checkers
  never ran. `checkers` is now `enabledCheckers`; the `exclude: [disk-clean]` entry was
  removed because `disk-clean` is no longer a checker at all — it moved to the
  `quality-gate clean` subcommand.

## [0.5.0] - 2026-06-02

### Added
- Phase E: XLSX reader
  - `Workbook(contentsOf:)` and `Workbook(xlsxData:)` — parse existing .xlsx files
  - `Workbook.save()` — in-memory save returning Data
  - OOXML XML parsers for workbook, worksheets, shared strings, styles, relationships
  - Full round-trip fidelity: write → read → verify for values, formulas, styles, and layout
  - Style reconstruction from OOXML (fonts, fills, borders, number formats, alignment)
  - Layout feature reconstruction (freeze panes, merge cells, auto-filter, validation, row heights)

## [0.4.0] - 2026-06-02

### Changed
- Phase D: SwiftZIP dependency
  - Extracted ZIP reader/writer into standalone SwiftZIP package
  - SwiftXLSX now depends on SwiftZIP for ZIP operations
  - Removed internal ZIPWriter.swift

## [0.3.0] - 2026-06-02

### Added
- Phase C: Layout and interactivity
  - `Worksheet.mergeCells` — merge cell regions
  - `Worksheet.freezePanes` — freeze rows and columns
  - `Worksheet.setAutoFilter` — enable auto-filter dropdown headers
  - `Worksheet.setRowHeight` — custom row heights
  - `Worksheet.addValidation` — data validation with list, decimal, and integer constraints
  - `ValidationType` — enum for validation rule types
  - OOXML-compliant element ordering in worksheet XML

## [0.2.0] - 2026-06-02

### Changed
- Phase B: Rich styling (breaking change to `CellStyle`)
  - `CellStyle` rewritten as composed value type with `Font`, `Border`, `Alignment`, `NumberFormat`, `Fill`
  - Builder pattern: `.with(font:).with(border:)` returning new immutable values
  - `StyleSheet` rewritten to handle font/border/fill/alignment/number-format deduplication and full XML generation
  - `DesignBundle` — configurable default styling with SF Mono / SF Pro Display defaults
  - All existing preset names preserved (`.general`, `.header`, `.currency`, etc.)
  - New `.title` preset (18pt bold)

## [0.1.2] - 2026-06-02

### Added
- Phase A2: Formula parser (string to AST)
  - `FormulaLexer` — character-by-character tokenizer for Excel formula strings
  - `FormulaParser` — Pratt (precedence-climbing) parser producing `FormulaAST`
  - `FormulaToken` — rich token type with cell refs, errors, booleans classified at lex time
  - `FormulaParseError` — structured error with offset and formula context
  - Full round-trip: `serialize(parse(str)) == str` for all formula patterns
  - `Worksheet.writeFormula` upgraded from `_RAW` hack to real parsing with fallback
  - 119 new tests (72 lexer + 82 parser + 70 round-trip + 49 integration, some shared)

## [0.1.1] - 2026-06-02

### Added
- Phase A3: Formula evaluation engine
  - `FormulaEvaluator` — AST walker with Excel type coercion and error propagation
  - `FunctionRegistry` — CoW value type with case-insensitive lookup, user-extensible
  - 62 built-in Excel functions across 8 categories (Math, Stats, Financial, Logical, Text, Lookup, Date, Aggregation)
  - `DependencyGraph` — DAG builder with topological sort, cycle detection, impact analysis
  - `CellValueProvider` protocol and `WorkbookValueProvider` for cell lookups
  - `CellAddress` for fully-qualified sheet+cell references

## [0.1.0] - 2026-06-01

### Added
- Phase A1: Data model, AST, references, and serialization
  - `FormulaAST` — recursive expression tree for Excel formulas
  - `FormulaSerializer` — AST to Excel formula string with precedence-aware parenthesization
  - `CellRef`, `CellRange`, `SheetReference` — cell reference types with absolute/relative markers
  - `NamedRange`, `NamedRangeCollection`, `NameResolver` — Excel's variable system
  - `CellValue` — unified value type with formula caching
  - `ExcelError` — standard Excel error values
  - Pure-Swift ZIP writer (no Process dependency)
  - 17 convenience builders on FormulaAST for common functions
