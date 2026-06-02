# Changelog

## [Unreleased]

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
