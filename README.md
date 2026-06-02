# SwiftXLSX

Pure-Swift library for generating and evaluating Excel (.xlsx) files. Zero external dependencies.

## Features

- **Formula AST** — represent Excel formulas as a recursive expression tree
- **Formula Parser** — parse Excel formula strings (`=SUM(A1:B5)/12`) into AST trees
- **Formula Evaluation** — compute formula results natively in Swift, no Excel required
- **62 Built-in Functions** — Math, Stats, Financial (PMT, NPV, IRR), Logical, Text, Lookup, Date, Aggregation
- **Dependency Graph** — topological sort, cycle detection, impact analysis
- **Named Ranges** — Excel's variable system as first-class AST nodes
- **Rich Styling** — composed `CellStyle` with `Font`, `Border`, `Alignment`, `NumberFormat`, `Fill` and builder pattern
- **Design Bundles** — configurable default styling (SF Mono, SF Pro Display, gutter columns)
- **Layout** — merge cells, freeze panes, auto-filter, data validation, custom row heights
- **Cell References** — A1-style with absolute/relative markers, cross-sheet references
- **XLSX Reader** — parse existing .xlsx files back into Workbook objects
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

## License

See LICENSE file.
