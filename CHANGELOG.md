# Changelog

> **Tags are `vX.Y.Z` as of 2026-09-01.** Every tag through 0.7.0 was recreated in that form on
> its original commit and the unprefixed tags removed. Commits are unchanged, and SwiftPM treats
> `v0.7.0` and `0.7.0` as the same version, so `exact: "0.7.0"` in a consumer's manifest keeps
> resolving to the same revision. Version *numbers* in this file remain unprefixed.

## [Unreleased]

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
