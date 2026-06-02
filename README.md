# SwiftXLSX

Pure-Swift library for generating and evaluating Excel (.xlsx) files. Zero external dependencies.

## Features

- **Formula AST** — represent Excel formulas as a recursive expression tree
- **Formula Evaluation** — compute formula results natively in Swift, no Excel required
- **62 Built-in Functions** — Math, Stats, Financial (PMT, NPV, IRR), Logical, Text, Lookup, Date, Aggregation
- **Dependency Graph** — topological sort, cycle detection, impact analysis
- **Named Ranges** — Excel's variable system as first-class AST nodes
- **Cell References** — A1-style with absolute/relative markers, cross-sheet references
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

// Write a formula using the AST
sheet.write(
    .pmt(rate: .divide(.cellRef(CellRef("B2")), .number(12)),
         nper: .cellRef(CellRef("B3")),
         pv: .negate(.cellRef(CellRef("B1")))),
    to: "B4"
)

// Save
try workbook.save(to: URL(fileURLWithPath: "output.xlsx"))
```

## Requirements

- Swift 6.2+
- macOS 14+ / iOS 17+

## License

See LICENSE file.
