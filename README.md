# SwiftXLSX

Pure-Swift library for reading and writing Excel (.xlsx) files — formulas, styles and layout.
No C or system-library dependencies, and nothing shells out to an external binary.

Formula **evaluation** lives in a separate package. This one is syntax and storage: it parses,
serializes, reads and writes. To compute results, add
[SwiftExcelFunctions](https://github.com/jpurnell/SwiftExcelFunctions).

## Features

- **Formula AST** — represent Excel formulas as a recursive expression tree
- **Formula Parser** — parse Excel formula strings (`=SUM(A1:B5)/12`) into AST trees
- **Formula Serializer** — AST back to an Excel formula string, with precedence-aware parens
- **Dependency Graph** — topological sort, cycle detection, impact analysis (the type lives in
  SwiftExcelCore; this package builds one from a `Workbook` or `Worksheet`)
- **Named Ranges** — Excel's variable system as first-class AST nodes
- **Rich Styling** — composed `CellStyle` with `Font`, `Border`, `Alignment`, `NumberFormat`, `Fill` and builder pattern
- **Design Bundles** — configurable default styling (SF Mono, SF Pro Display, gutter columns)
- **Layout** — merge cells, freeze panes, auto-filter, data validation, custom row heights
- **Cell References** — A1-style with absolute/relative markers, cross-sheet references
- **XLSX Reader** — parse existing .xlsx files back into Workbook objects, including packages written by Excel (fixed in 0.6.0; earlier releases returned an empty workbook for those)
- **Pure-Swift ZIP** — no Process/shell dependencies, works on iOS and Linux

## Quick Start

```swift
import SwiftXLSX

let workbook = Workbook()
let sheet = workbook.addSheet(name: "Sheet1")

// Write values
sheet.write(100_000, to: "B1")
sheet.write(0.065, to: "B2")
sheet.write(360, to: "B3")

// Write a formula from a string (parsed into AST automatically)
sheet.writeFormula("PMT(B2/12,B3,-B1)", to: "B4")

// Or build formulas programmatically
sheet.write(
    .pmt(rate: .divide(.cellRef(CellRef("B2")), .number(12)),
         nper: .cellRef(CellRef("B3")),
         pv: .negate(.cellRef(CellRef("B1")))),
    to: "B5"
)

// Style with the builder pattern
sheet.write("Total", to: "A4", style: .header.with(border: .bottom))

// Layout features
sheet.freezePanes(at: "A2")
sheet.mergeCells(CellRange(from: "A1", to: "B1"))
sheet.setRowHeight(row: 1, height: 40)

// Save
try workbook.save(to: URL(fileURLWithPath: "output.xlsx"))

// Read an existing file
let loaded = try Workbook(contentsOf: URL(fileURLWithPath: "input.xlsx"))
let firstSheet = loaded.sheets[0]
let value = firstSheet.cell(at: "A1")  // CellValue?
```

## Requirements

- Swift 6.2+
- macOS 14+ / iOS 17+

Two package dependencies, both pure Swift:

- [SwiftZIP](https://github.com/jpurnell/SwiftZIP) 0.6.0+ — the ZIP reader and writer.
- [SwiftExcelCore](https://github.com/jpurnell/SwiftExcelCore) 0.14.0+ — the shared spreadsheet
  vocabulary (`CellValue`, `CellRef`, `CellRange`, `FormulaAST`, `ExcelError`, `NamedRange`,
  `DependencyGraph`). It is re-exported, so `import SwiftXLSX` sees those types with no second
  import, and it is pinned `from:` rather than `exact:` so SwiftPM can unify it across the
  packages that share it.

`swift-docc-plugin` is a build-time plugin only.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Permissive deliberately. This is shared plumbing: it is more useful the more
widely it is used, and it carries no copyleft. The copyleft layers of the family
(SwiftExcelFunctions, BusinessMath, BusinessMathExcel) are AGPLv3 with a
commercial option; copyleft may depend on permissive, never the reverse.
