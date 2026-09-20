# SwiftXLSX Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

---

## Project Overview

### Mission
Provide a pure-Swift bidirectional library for reading and writing Excel (.xlsx)
files with formulas, styles, and layout features. XLSX is ZIP + XML (Open XML /
OOXML) -- SwiftXLSX handles both layers natively. Its dependencies are SwiftZIP
(archive layer) and SwiftExcelCore (the shared spreadsheet vocabulary), both
sibling pure-Swift packages also maintained by this project.

### Target Users
- **Swift developers** who need to read, generate, or round-trip Excel files
- **Server-side Swift** applications importing/exporting financial reports
- **BusinessMathExcel** -- the planned consumer that imports Excel financial
  models into BusinessMath's computational graph, extends them with Monte Carlo
  and optimization, and exports results back to .xlsx

### Key Differentiators
- **Minimal dependencies** -- Foundation + SwiftZIP + SwiftExcelCore (pure Swift,
  no C libraries)
- **Bidirectional** -- full read/write round-trip with formulas, styles, and layout
- **Formula syntax** -- Pratt-precedence parser and AST round-trip fidelity, over the
  `FormulaAST` vocabulary that lives in SwiftExcelCore. *Evaluation* is no longer here:
  the function library left for SwiftExcelFunctions in 0.13.0 (see Architectural
  Decision 7). This package is syntax and storage.
- **Type-safe API** -- Swift compiler catches structural errors at build time
- **Sendable** -- all public types are strict-concurrency safe (Swift 6.2+)

---

## Architecture

### Module Structure

```
SwiftXLSX/
  Sources/SwiftXLSX/         # 24 source files (writer, styles, formula syntax)
  Sources/SwiftXLSX/Reader/  # 11 source files (XLSX reader / SAX parsers)
  Tests/SwiftXLSXTests/      # 43 test files, 847 tests (Swift Testing)

SwiftZIP/         (sibling)  # ZIP read/write, CRC32, Deflate
SwiftExcelCore/   (sibling)  # CellValue, CellRef, CellRange, CellAddress,
                             # SheetReference, NamedRange, ExcelError, FormulaAST,
                             # CellValueProvider, DependencyGraph — re-exported,
                             # so `import SwiftXLSX` still sees them
SwiftExcelFunctions/         # The evaluator and the built-in functions. NOT a
                             # dependency of this package — it depends on Core, and
                             # a caller that evaluates formulas imports it directly.
```

**Platform:** macOS 14+ / iOS 17+, Swift 6.2+, strict Sendable concurrency.

### Key Types

| Type | Responsibility |
|------|---------------|
| **Vocabulary** (SwiftExcelCore, re-exported — `import SwiftXLSX` sees them) | |
| `CellValue` | `.number`, `.text`, `.bool`, `.error`, `.formula`, `.date`, `.blank`, `.array` |
| `CellRef` | Column/row parser (A1 notation <-> numeric, absolute/relative) |
| `CellRange` | Contiguous rectangular range (e.g. `A1:C5`), plus whole-row/column spans |
| `CellAddress` | Sheet-qualified cell reference for cross-sheet formulas |
| `SheetReference` | Lightweight sheet name + index pair |
| `NamedRange` | Named range definitions, workbook- or sheet-scoped |
| `ExcelError` | `#VALUE!`, `#REF!`, `#DIV/0!`, `#NAME?`, `#NULL!`, `#NUM!`, `#N/A` |
| `FormulaAST` | Abstract syntax tree for Excel formula expressions |
| `CellValueProvider` | The seam that lets a function library read cells without a workbook |
| `DependencyGraph` | Topological sort for evaluation ordering; this package adds the `Workbook`/`Worksheet` initialisers, since a graph over cells is a fact about cells and the *file* part is what belongs here |
| **Data Model** (this package) | |
| `Workbook` | Top-level container; holds sheets, shared strings, styles; read via `init(contentsOf:)` / `init(xlsxData:)`, write via `save(to:)` / `save() -> Data` |
| `Worksheet` | Named sheet; write values, formulas, styles by cell reference |
| `SharedStrings` | Deduplicates strings across all sheets |
| `ArrayFormula` | An array formula and the range it spills over |
| `WorkbookValueProvider` | `CellValueProvider` conformance backed by a `Workbook` |
| **Formula Syntax** | |
| `FormulaToken` | Lexer token types (operators, references, literals, functions) |
| `FormulaLexer` | Tokenizer for Excel formula strings |
| `FormulaParser` | Pratt precedence-climbing parser producing `FormulaAST` |
| `FormulaSerializer` | AST -> Excel formula string (round-trip serialization) |
| **Styles** | |
| `CellStyle` | Composed style: font, border, fill, alignment, number format |
| `Font` | Font name, size, bold, italic, color |
| `Border` | Edge styles and colors |
| `Fill` | Background/pattern fill colors |
| `Alignment` | Horizontal, vertical, wrap text, text rotation |
| `NumberFormat` | Built-in and custom Excel number format codes |
| `StyleSheet` | Deduplicating style manager (fonts, fills, borders, xf records) |
| `DesignBundle` | Preset style collections for consistent workbook theming |
| **Layout** | |
| `ValidationType` | Data validation rules: `.list`, `.decimal`, `.integer` |
| **Reader** (all internal; `Workbook.init(contentsOf:)` is the public entry) | |
| `WorkbookReader` | Orchestrator: ZIP -> relationships -> parsers -> `Workbook` |
| `WorksheetParser` | SAX parser for xl/worksheets/sheetN.xml |
| `StyleSheetParser` | SAX parser for xl/styles.xml |
| `SharedStringsParser` | SAX parser for xl/sharedStrings.xml |
| `WorkbookXMLParser` | SAX parser for xl/workbook.xml |
| `RelationshipsParser` | SAX parser for .rels files |
| `ContentTypesParser` | SAX parser for [Content_Types].xml |
| `DefinedNameResolver` | Reads a defined name's target back into a reference |
| `DefinedNameWriter` | Writes defined names to xl/workbook.xml |
| `SharedFormula` | Translates a shared formula to each cell that shares it |
| **Errors** | |
| `XLSXReadError` | Reader errors (ZIP, missing part, XML parse, invalid index) |
| `FormulaParseError` | Parser errors with kind, offset, and source formula |

### Built-in Functions

**Not in this package.** The 73 built-in functions, `FunctionRegistry`, `ExcelFunction`,
`FormulaEvaluator` and `EvalError` moved to
[SwiftExcelFunctions](https://github.com/jpurnell/SwiftExcelFunctions) in 0.13.0, and were
deliberately *not* re-exported: a file reader has no business owning what `AVERAGE` means, and
a re-export would have preserved the old shape while claiming the new one. A caller that
evaluates formulas depends on that package and imports it; a caller that reads and writes
files needs no change.

### API

```swift
// Write
let workbook = Workbook()
let sheet = workbook.addSheet(name: "Summary")
sheet.write("Revenue", to: "A1", style: .header)
sheet.write(1_500_000.0, to: "B1", style: .currency)
sheet.writeFormula("=B1*0.4", to: "B2", style: .currency)
try workbook.save(to: URL(fileURLWithPath: "report.xlsx"))

// Read
let wb = try Workbook(contentsOf: URL(fileURLWithPath: "report.xlsx"))
let val = wb.sheets[0].cell(at: "B1")  // .number(1_500_000.0)
```

---

## Core Architectural Decisions

1. **SAX over DOM** -- All XML parsing uses Foundation's event-driven XMLParser
   (SAX), keeping memory usage low for large workbooks.
2. **Pratt precedence climbing** -- The formula parser uses a top-down operator
   precedence algorithm for correct handling of nested expressions, unary
   operators, and function calls without ambiguity.
3. **Copy-on-write registries** -- ~~`FunctionRegistry` uses CoW storage so
   copying is cheap and thread-safe without locks.~~ Moved out with the function
   library in 0.13.0; the decision now belongs to SwiftExcelFunctions.
4. **Style deduplication** -- `StyleSheet` deduplicates fonts, fills, borders,
   and xf records to produce minimal xl/styles.xml output matching Excel's
   own dedup behavior.
5. **Dependency graph ordering** -- `DependencyGraph` topologically sorts cells and
   detects circular references. The type moved to SwiftExcelCore in 0.23.0, because a
   graph over cells holds whether or not those cells came from an `.xlsx`. What stayed
   here is the file-facing part: turning a `Workbook` or `Worksheet` into the address
   set and provider the graph wants.
6. **SwiftZIP extraction** -- ZIP handling lives in a standalone sibling
   package, keeping SwiftXLSX focused on OOXML semantics.
7. **The package split (0.12.0 / 0.13.0)** -- The vocabulary went down to
   SwiftExcelCore and the function library went out to SwiftExcelFunctions, leaving
   this package as *syntax and storage*. The two extractions were deliberately
   asymmetric: Core's types are re-exported, because this package still traffics in
   `CellValue` and `FormulaAST` on every call, and making callers add an import would
   have been a breaking change dressed up as a refactor. The functions were not
   re-exported, because they are genuinely gone. Downstream cost of both, measured
   rather than assumed: BusinessMathExcel's 564 tests passed with no source change.

---

## Current Status

### Phase A: Formula Engine (Complete)
- [x] A1: Data model, AST nodes, cell references, serialization
- [x] A2: Pratt precedence-climbing parser with full round-trip fidelity
- [x] A3: Evaluation engine -- ~~70 functions, 8 categories, dependency graph~~
      Built here, then moved out in 0.13.0. Complete, but no longer this package's.

### Phase B: Rich Styling (Complete)
- [x] Font (name, size, bold, italic, color)
- [x] Border (edge styles, colors)
- [x] Fill (solid, pattern, foreground/background colors)
- [x] Alignment (horizontal, vertical, wrap text, rotation)
- [x] NumberFormat (built-in codes + custom format strings)
- [x] CellStyle composition (font + border + fill + alignment + number format)
- [x] StyleSheet deduplication
- [x] DesignBundle preset themes

### Phase C: Layout Features (Complete)
- [x] Merge cells
- [x] Freeze panes
- [x] Auto-filter
- [x] Data validation (list, decimal, integer)
- [x] Row heights
- [x] Column widths

### Phase D: SwiftZIP Extraction (Complete)
- [x] Standalone SwiftZIP package (ZIPWriter, ZIPReader, CRC32, Deflate)
- [x] SwiftXLSX writer ported to SwiftZIP
- [x] SwiftXLSX reader uses SwiftZIP for archive extraction

### Phase E: XLSX Reader (Complete)
- [x] 8 SAX parsers (Worksheet, StyleSheet, SharedStrings, WorkbookXML, Relationships, ContentTypes, WorkbookReader orchestrator, XLSXReadError)
- [x] WorkbookReader orchestrates full read pipeline
- [x] Workbook convenience initializers: `init(contentsOf:)`, `init(xlsxData:)`
- [x] Round-trip tests (write -> read -> verify)
- [x] Foreign-package tests (read packages this library did not write) — added 2026-09-01
      after the reader was found unable to open any Excel-authored workbook: the main
      document part was matched by substring, which also matches extended-properties,
      so real files parsed to zero sheets and returned no error. Round-trip tests could
      not catch it, because our own writer emits the one relationship ordering that works.

### Documentation (Complete)
- [x] DocC catalogue at `Sources/SwiftXLSX/SwiftXLSX.docc`, declared as a target resource
- [x] All 44 public types curated into eight topic groups; no uncurated leftovers
- [x] Doc-comment examples compile — they are checked by the gate, not just rendered

### Phase F: The package split (Complete) — 0.12.0 / 0.13.0
- [x] Vocabulary extracted to SwiftExcelCore, re-exported for source compatibility
- [x] Function library and evaluator extracted to SwiftExcelFunctions, not re-exported
- [x] `DependencyGraph` followed to Core in 0.23.0; file-facing initialisers stayed
- [x] SwiftExcelCore pinned `from:` rather than `exact:` (0.23.1) — three packages
      depend on it and SwiftPM must unify them on one version, or two `CellValue`
      types exist and nothing typechecks

### Phase G: Corpus-driven hardening (Ongoing) — 0.14.0 through 0.31.1
Real workbooks, not round-trips, drove this. Our own writer emits the one shape that
works, so round-trip tests are structurally unable to find these:
- [x] Formula syntax gaps: omitted arguments, whole-column/row ranges, percent suffix,
      underscores and dots in names, error literals after a sheet name (0.14.0);
      `LAMBDA(…)(args)` (0.28.0); array constants `{1,2,3;4,5,6}` (0.31.0);
      `1:1` written without `$` (0.30.0)
- [x] Defined names survive a round trip, including whole-column names (0.26.0)
- [x] Array formulas: written, read back, and not mistaken for constants (0.16.0–0.20.0)
- [x] Cached formula results — errors, booleans, dates — survive a save (0.21.0)
- [x] Japanese text: furigana kept and reachable, not concatenated into values (0.23.2, 0.24.0)
- [x] Crashers found by fuzzing the lexer: long identifiers, large numbers (0.24.1, 0.26.1)
- [x] Whole-column data validation applied to the whole column (0.31.1)

### Testing (Complete) — 0.32.0
- [x] Suite migrated from XCTest to Swift Testing, the project standard
- [x] 847 tests in 43 suites; the count is the check, since a `func testX` left without
      `@Test` still compiles and silently stops running
- [x] Assertions strengthened where the migration made them visible to the gate:
      17 exact float comparisons named as such, 109 tests moved off helpers the auditor
      could not see into, 49 weak assertions tightened against the sources

### Quality
- 35 source files, 43 test files, 847 tests
- Zero warnings target
- All public types are Sendable
- Quality gate green at 45/45 checkers, 0 errors / 0 warnings, with no overrides,
  suppressions, or checker exclusions. The gate config previously used two
  unrecognised keys, so five checkers silently never ran; corrected 2026-08-25.
- Test counts fell from ~1414 to 847 across 0.12.0–0.13.0 because 170 tests went to
  SwiftExcelCore and 546 to SwiftExcelFunctions with the code they cover. None were
  lost, and each split was verified by counting both sides.
- Test suite spawns no subprocesses: archive assertions go through SwiftZIP rather
  than `/usr/bin/unzip`.

---

## Roadmap

All implementation phases are complete, and the scope itself narrowed in 0.13.0:
this package is syntax and storage. Future work is driven by consumer needs and by
what the corpus finds.

- **BusinessMathExcel integration** -- import Excel financial models into
  BusinessMath's computational graph, extend with Monte Carlo/optimization,
  export results back to .xlsx
- **Performance** -- streaming write for very large workbooks if needed
- ~~**Additional functions** -- expand FunctionRegistry as consumer demand arises~~
  Not this package's to expand. `FunctionRegistry` left in 0.13.0; the item belongs
  to SwiftExcelFunctions now, and is kept here only to show where it went.
- **Corpus-driven reader defects** -- Phase G is open-ended by nature. Every fix from
  0.14.0 on came from a real workbook this library could not read correctly, and the
  rate has not yet fallen to zero.

---

## Non-Goals

- Charts or images
- VBA macros
- Password protection
- Pivot tables

---

*Last updated: 2026-09-20 -- reconciled against everything shipped since 2026-09-03,
which was 27 releases (0.12.0 through 0.32.0) and left this document describing a package
that no longer exists. The largest correction: the plan still claimed a formula **engine**
with 70 built-in functions as a key differentiator, and listed `FormulaEvaluator`,
`FunctionRegistry`, `ExcelFunction` and `EvalError` in its type table. All of them left in
0.13.0, along with the vocabulary in 0.12.0 — so roughly half the table named types this
package no longer defines. Also corrected: file and test counts (49/49/~1414 -> 35/43/847,
the drop being the two extractions rather than deleted tests), the reader parsers marked
internal, Phases F and G and a Testing section added, and the "additional functions" roadmap
item struck as no longer ours to do. 0.32.0 itself is the XCTest -> Swift Testing migration.

Previously, 2026-09-03 -- recorded 0.10.0 (`write(_:to:cached:style:)`) and 0.11.0 (a
dependency graph scoped to a sheet or a subset of cells, and `allCells` made public). The
0.8.0 through 0.10.0 releases were all one shape: information the reader understood, with no
way for a caller to reach or state it. 0.11.0 is a different one — the graph was reachable, but
only ever answered the evaluator's question, and a caller recovering a model is asking another.*
