# Changelog

## [Unreleased]

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
