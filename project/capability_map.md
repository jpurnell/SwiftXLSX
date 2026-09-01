# SwiftXLSX Capability Map

**Purpose:** Scannable inventory of what this project can do — feature areas, key types, external interfaces, and application domains.

**Last reviewed:** 2026-09-01

> **Format reference:** See `development-guidelines/rules/capability_map.md` for field definitions,
> naming conventions, and maintenance rules.

---

## Workbook Authoring

**Key types:** `Workbook`, `Worksheet`, `CellValue`, `CellRef`, `CellRange`, `SheetReference`
**Interfaces:** `Workbook()`, `addSheet(name:)`, `write(_:to:)`, `save()`, `save(to:)`
**Applications:** Generating spreadsheets from computed data, exporting reports, producing models a finance user can open and edit

## Workbook Reading

**Key types:** `WorkbookReader`, `WorksheetParser`, `StyleSheetParser`, `SharedStringsParser`, `WorkbookXMLParser`, `RelationshipsParser`, `ContentTypesParser`, `XLSXReadError`
**Interfaces:** `Workbook(contentsOf:)`, `Workbook(xlsxData:)`
**Applications:** Ingesting spreadsheets authored elsewhere, round-tripping a workbook through code, recovering a model from a file
**Dependencies:** SwiftZIP

Reads packages written by Excel as of 0.6.0. Earlier releases resolved the main document part
by substring match and returned an empty workbook for any Excel-authored file — see the
`ForeignWorkbookReadTests` suite, which reads packages this library did not write.

## Formula Representation

**Key types:** `FormulaAST`, `FormulaLexer`, `FormulaParser`, `FormulaSerializer`, `FormulaToken`, `FormulaParseError`
**Interfaces:** `write(_ formula: FormulaAST, to:)`, `writeFormula(_:to:)`, `formulaAST(at:)`
**Applications:** Writing live formulas rather than baked values, reading a sheet's logic rather than its results, translating formulas between representations

## Formula Evaluation

**Key types:** `FormulaEvaluator`, `FunctionRegistry`, `ExcelFunction`, `CellValueProvider`, `EvalError`, `ExcelError`
**Interfaces:** `FormulaEvaluator.evaluate(_:provider:)`, `FunctionRegistry.register(_:)`
**Applications:** Computing results without Excel, validating that a generated sheet produces expected values, custom function extension

## Built-in Function Library

**Key types:** `BuiltinMathFunctions`, `BuiltinStatsFunctions`, `BuiltinFinancialFunctions`, `BuiltinLogicalFunctions`, `BuiltinTextFunctions`, `BuiltinLookupFunctions`, `BuiltinDateFunctions`, `BuiltinAggregationFunctions`
**Interfaces:** Resolved by name through `FunctionRegistry`
**Applications:** Evaluating the formulas real spreadsheets contain — PMT, NPV, IRR, VLOOKUP, and the common math, text, and date set

## Dependency Analysis

**Key types:** `DependencyGraph`, `NamedRange`, `NamedRangeCollection`, `NameResolver`
**Interfaces:** `DependencyGraph.topologicalSort()`, cycle detection, impact analysis
**Applications:** Determining recalculation order, finding circular references, assessing the blast radius of changing a cell

## Presentation and Layout

**Key types:** `CellStyle`, `Font`, `Border`, `Alignment`, `Fill`, `NumberFormat`, `StyleSheet`, `DesignBundle`, `ValidationType`
**Interfaces:** `write(_:to:style:)`, `mergeCells(_:)`, `freezePanes(at:)`, `setAutoFilter(_:)`, `addValidation(_:type:)`, `setColumnWidth(column:width:)`, `setRowHeight(row:height:)`
**Applications:** Producing spreadsheets that read as designed documents rather than data dumps; constraining user input through validation
