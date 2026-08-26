# ``SwiftXLSX``

Read, write, and evaluate Excel (.xlsx) workbooks in pure Swift.

## Overview

SwiftXLSX builds spreadsheets programmatically and evaluates their formulas
without Excel and without a spreadsheet engine on the host. A workbook is a
tree of Swift values: ``Workbook`` owns ``Worksheet``s, each cell holds a
``CellValue``, and formulas are ``FormulaAST`` nodes rather than opaque
strings, so they can be parsed, rewritten, evaluated, and serialized back.

```swift
let workbook = Workbook()
let sheet = workbook.addSheet(name: "Sheet1")

sheet.write(100_000, to: "B1")
sheet.write(0.065, to: "B2")
sheet.writeFormula("=B1*B2", to: "B3")

let outputURL = URL(fileURLWithPath: "Interest.xlsx")
try workbook.save(to: outputURL)
```

Formula evaluation runs through ``FormulaEvaluator``, which resolves cell
references via a ``CellValueProvider`` and named ranges via a
``NameResolver``. Function lookup goes through a ``FunctionRegistry``,
which starts from the built-in catalogue and accepts your own
``ExcelFunction`` values.

## Topics

### Building a Workbook

- ``Workbook``
- ``Worksheet``
- ``CellValue``
- ``CellRef``
- ``CellRange``
- ``CellAddress``
- ``SheetReference``

### Styling

- ``CellStyle``
- ``Font``
- ``Border``
- ``Fill``
- ``Alignment``
- ``NumberFormat``
- ``DesignBundle``
- ``StyleSheet``

### Formulas

- ``FormulaAST``
- ``FormulaLexer``
- ``FormulaParser``
- ``FormulaSerializer``
- ``FormulaToken``
- ``FormulaParseError``

### Evaluation

- ``FormulaEvaluator``
- ``CellValueProvider``
- ``WorkbookValueProvider``
- ``DependencyGraph``

### Functions

- ``ExcelFunction``
- ``FunctionRegistry``
- ``ExcelFunctionError``
- ``BuiltinMathFunctions``
- ``BuiltinStatsFunctions``
- ``BuiltinFinancialFunctions``
- ``BuiltinLogicalFunctions``
- ``BuiltinTextFunctions``
- ``BuiltinLookupFunctions``
- ``BuiltinDateFunctions``
- ``BuiltinAggregationFunctions``

### Named Ranges

- ``NamedRange``
- ``NamedRangeCollection``
- ``NamedRangeTarget``
- ``NameResolver``
- ``NameScope``

### Validation and Errors

- ``ValidationType``
- ``ExcelError``
- ``XLSXReadError``

### Supporting Types

- ``SharedStrings``
