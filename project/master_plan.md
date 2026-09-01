# SwiftXLSX Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

---

## Project Overview

### Mission
Provide a pure-Swift bidirectional library for reading and writing Excel (.xlsx)
files with formulas, styles, and layout features. XLSX is ZIP + XML (Open XML /
OOXML) -- SwiftXLSX handles both layers natively. The only dependency is SwiftZIP,
a sibling pure-Swift package also maintained by this project.

### Target Users
- **Swift developers** who need to read, generate, or round-trip Excel files
- **Server-side Swift** applications importing/exporting financial reports
- **BusinessMathExcel** -- the planned consumer that imports Excel financial
  models into BusinessMath's computational graph, extends them with Monte Carlo
  and optimization, and exports results back to .xlsx

### Key Differentiators
- **Minimal dependencies** -- Foundation + SwiftZIP (pure Swift, no C libraries)
- **Bidirectional** -- full read/write round-trip with formulas, styles, and layout
- **Formula engine** -- Pratt-precedence parser, AST representation, 70 built-in
  Excel functions across 8 categories, dependency-graph evaluation
- **Type-safe API** -- Swift compiler catches structural errors at build time
- **Sendable** -- all public types are strict-concurrency safe (Swift 6.2+)

---

## Architecture

### Module Structure

```
SwiftXLSX/
  Sources/SwiftXLSX/         # 40 source files (core library)
  Sources/SwiftXLSX/Reader/  #  8 source files (XLSX reader / SAX parsers)
  Tests/SwiftXLSXTests/      # 48 test files, ~1400 tests

SwiftZIP/  (sibling package)
  Sources/SwiftZIP/           # ZIP read/write, CRC32, Deflate
```

**Platform:** macOS 14+ / iOS 17+, Swift 6.2+, strict Sendable concurrency.

### Key Types

| Type | Responsibility |
|------|---------------|
| **Data Model** | |
| `Workbook` | Top-level container; holds sheets, shared strings, styles; read via `init(contentsOf:)` / `init(xlsxData:)`, write via `save(to:)` / `save() -> Data` |
| `Worksheet` | Named sheet; write values, formulas, styles by cell reference |
| `CellValue` | `.number`, `.text`, `.bool`, `.error`, `.formula`, `.date`, `.blank`, `.array` |
| `CellRef` | Column/row parser (A1 notation <-> numeric, absolute/relative) |
| `CellRange` | Contiguous rectangular range (e.g. `A1:C5`) |
| `CellAddress` | Sheet-qualified cell reference for cross-sheet formulas |
| `SharedStrings` | Deduplicates strings across all sheets |
| `SheetReference` | Lightweight sheet name + index pair |
| `NamedRange` | Workbook-scoped named range definitions |
| **Formulas** | |
| `FormulaAST` | Abstract syntax tree for Excel formula expressions |
| `FormulaToken` | Lexer token types (operators, references, literals, functions) |
| `FormulaLexer` | Tokenizer for Excel formula strings |
| `FormulaParser` | Pratt precedence-climbing parser producing `FormulaAST` |
| `FormulaSerializer` | AST -> Excel formula string (round-trip serialization) |
| `FormulaEvaluator` | Evaluates AST nodes against a workbook's cell data |
| `FunctionRegistry` | CoW registry mapping function names to implementations |
| `ExcelFunction` | Single function definition (name, arity, implementation closure) |
| `DependencyGraph` | Topological sort for evaluation ordering |
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
| **Reader** | |
| `WorkbookReader` | Orchestrator: ZIP -> relationships -> parsers -> `Workbook` |
| `WorksheetParser` | SAX parser for xl/worksheets/sheetN.xml |
| `StyleSheetParser` | SAX parser for xl/styles.xml |
| `SharedStringsParser` | SAX parser for xl/sharedStrings.xml |
| `WorkbookXMLParser` | SAX parser for xl/workbook.xml |
| `RelationshipsParser` | SAX parser for .rels files |
| `ContentTypesParser` | SAX parser for [Content_Types].xml |
| **Errors** | |
| `ExcelError` | Excel error values: `#VALUE!`, `#REF!`, `#DIV/0!`, `#NAME?`, `#NULL!`, `#NUM!`, `#N/A` |
| `EvalError` | Runtime evaluation errors (type mismatch, division by zero) |
| `XLSXReadError` | Reader errors (ZIP, missing part, XML parse, invalid index) |
| `FormulaParseError` | Parser errors with kind, offset, and source formula |

### Built-in Function Categories (70 functions)

| Category | Count | Examples |
|----------|-------|---------|
| Math | 15 | ABS, ROUND, SQRT, LN, LOG, EXP, POWER, MOD, PI |
| Statistics | 13 | AVERAGE, STDEV, MEDIAN, MIN, MAX, COUNT, PERCENTILE |
| Financial | 11 | PMT, IPMT, PPMT, NPV, IRR, FV, PV, RATE, NPER |
| Text | 9 | LEN, LEFT, RIGHT, MID, TRIM, UPPER, LOWER, CONCATENATE |
| Aggregation | 6 | SUM, SUMIF, SUMIFS, COUNTIF, COUNTIFS, AVERAGEIF |
| Logical | 6 | IF, AND, OR, NOT, IFERROR, IFNA |
| Date | 6 | TODAY, NOW, YEAR, MONTH, DAY, DATE |
| Lookup | 4 | VLOOKUP, HLOOKUP, INDEX, MATCH |

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
3. **Copy-on-write registries** -- `FunctionRegistry` uses CoW storage so
   copying is cheap and thread-safe without locks.
4. **Style deduplication** -- `StyleSheet` deduplicates fonts, fills, borders,
   and xf records to produce minimal xl/styles.xml output matching Excel's
   own dedup behavior.
5. **Dependency graph evaluation** -- Formulas are evaluated in topological
   order via `DependencyGraph`, handling circular reference detection.
6. **SwiftZIP extraction** -- ZIP handling lives in a standalone sibling
   package, keeping SwiftXLSX focused on OOXML semantics.

---

## Current Status

### Phase A: Formula Engine (Complete)
- [x] A1: Data model, AST nodes, cell references, serialization
- [x] A2: Pratt precedence-climbing parser with full round-trip fidelity
- [x] A3: Evaluation engine -- 70 functions, 8 categories, dependency graph

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

### Quality
- 48 source files, 49 test files, ~1404 tests
- Zero warnings target
- All public types are Sendable
- Quality gate green at 45/45 checkers, 0 errors / 0 warnings, with no overrides,
  suppressions, or checker exclusions. The gate config previously used two
  unrecognised keys, so five checkers silently never ran; corrected 2026-08-25.
- Test suite spawns no subprocesses: archive assertions go through SwiftZIP rather
  than `/usr/bin/unzip`.

---

## Roadmap

All five implementation phases are complete. The library is feature-complete for
its defined scope. Future work is driven by consumer needs:

- **BusinessMathExcel integration** -- import Excel financial models into
  BusinessMath's computational graph, extend with Monte Carlo/optimization,
  export results back to .xlsx
- **Performance** -- streaming write for very large workbooks if needed
- **Additional functions** -- expand FunctionRegistry as consumer demand arises

---

## Non-Goals

- Charts or images
- VBA macros
- Password protection
- Pivot tables

---

*Last updated: 2026-08-25 -- reconciled the dependency claim (README had said "zero
external dependencies"; SwiftZIP has always been a dependency, as this plan already
stated), recorded the DocC catalogue, and noted the quality-gate config correction.*
