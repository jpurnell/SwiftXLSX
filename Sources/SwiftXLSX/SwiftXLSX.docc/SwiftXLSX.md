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

This package reads and writes; it does not evaluate. Formula evaluation, the
built-in Excel functions and the function registry live in
[SwiftExcelFunctions](https://github.com/jpurnell/SwiftExcelFunctions), which
takes a `FormulaAST` from here and a `CellValueProvider` — `WorkbookValueProvider`
conforms — and computes a result. A caller that only reads and writes files needs
none of it.

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

### Reading cells and dependencies

- ``WorkbookValueProvider``
- ``DependencyGraph``

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
