# Design Proposal: SwiftXLSX v1 — Excel Computation Engine + File Format Library

> **Resolved decisions** (per user review 2026-06-01):
> - Formula system uses a proper AST (recursive expression tree), not string builders
> - Formula arguments use `CellRef`, not `String`
> - `CellStyle` uses composed value types (Font, Border, Alignment, NumberFormat)
> - Reading/parsing existing .xlsx files IS a goal
> - Default styling derived from user's Book.xltx template (SF Mono, SF Pro Display)
> - Named ranges are variables — first-class in the AST, not a layout feature
> - The AST is evaluable — SwiftXLSX can compute formula results, not just serialize them
> - Simple arithmetic maps to Swift math; every formula is evaluable without Excel
> - Phases proceed A1 → A2 → A3 → B → C → D → E
> - CellValue and EvaluationResult unified into a single `CellValue` type
> - FunctionRegistry uses CoW struct semantics, not `@unchecked Sendable` class
> - Default styling is a configurable `DesignBundle`, not hardcoded constants
> - Parser errors clearly on unsupported constructs with diagnostic messages
> - IRR/RATE share an iterative solver; BusinessMathExcel can override with BusinessMath's Newton-Raphson

## 1. Objective

**Objective:** SwiftXLSX is a spreadsheet computation engine with an Excel file format layer. It represents formulas as an evaluable AST, treats named ranges as variables, and can read, evaluate, and write .xlsx files — all in pure Swift with zero dependencies.

This is more than openpyxl. openpyxl reads and writes Excel files but doesn't evaluate formulas — it leaves that to Excel. SwiftXLSX evaluates formulas natively, which means you can:
- Read an Excel model, change an input, and recompute all downstream cells without Excel
- Run Monte Carlo simulation by varying inputs and re-evaluating the graph thousands of times
- Build models programmatically and compute their results in Swift

The AST is the Rosetta Stone: it connects Excel's formula language to Swift's computation model. `=B5*B6` parses into `.multiply(.cellRef(B5), .cellRef(B6))`, evaluates to `values[B5] * values[B6]`, and serializes back to `=B5*B6`. Named range `DiscountRate` pointing to B5 resolves exactly like a Swift variable binding.

**Master Plan Reference:** This supersedes the original Phase 2/3 plan. Removes "reading/parsing XLSX" from non-goals. Adds formula evaluation as a core capability.

## 2. Motivation

**Current situation:** SwiftXLSX is a thin XML serializer. No formula structure, no evaluation, no reading, no named ranges. Users construct formula strings by hand.

**What's missing:**
- No formula AST — formulas are opaque strings, can't be parsed, evaluated, or transformed
- No evaluation — can't compute formula results without Excel
- No named ranges — spreadsheets' variable system is invisible to the library
- No reading — can't open existing .xlsx files
- No real styling — 6 preset styles, no font control, no borders, no alignment
- No layout features — no merge cells, freeze panes, data validation
- ZIP depends on `/usr/bin/zip` (Process), unavailable on iOS/Linux

**Why evaluation matters:** Without evaluation, importing an Excel model is read-only — you can see the formulas but can't run them. With evaluation, every Excel model becomes a callable function: provide inputs, evaluate the graph, get outputs. This is what makes Monte Carlo, sensitivity analysis, and optimization possible on imported models — vary an input, re-evaluate, collect the output. Repeat 10,000 times.

**Why named ranges matter:** Named ranges ARE Excel's variable system. `=NPV(DiscountRate, CashFlows)` is semantically identical to `npv(discountRate, cashFlows)` in Swift. When we parse a formula and encounter `DiscountRate`, we resolve it through the workbook's name table to a cell reference — exactly like resolving a variable through a symbol table. If the AST doesn't model named ranges as first-class nodes, we lose this semantic information and degrade to opaque cell addresses.

**Default styling:** The user's Book.xltx template uses SF Mono Regular (11pt) for data, SF Pro Display Semibold (18pt) for titles, with a 2-column left gutter. SwiftXLSX should produce output matching this aesthetic by default.

## 3. Proposed Architecture

### The Three Layers

```
┌─────────────────────────────────────────────────┐
│  File Format Layer (Reader/Writer)              │
│  .xlsx ↔ Workbook/Worksheet/CellValue objects   │
├─────────────────────────────────────────────────┤
│  Computation Layer (AST + Evaluator)            │
│  FormulaAST, FormulaEvaluator, DependencyGraph  │
│  FunctionRegistry, NameResolver                 │
├─────────────────────────────────────────────────┤
│  Core Model Layer                               │
│  Workbook, Worksheet, CellRef, CellRange,       │
│  CellValue, CellStyle, NamedRange               │
└─────────────────────────────────────────────────┘
```

The File Format layer handles OOXML serialization (writing XML, packaging ZIP, parsing XML).
The Computation layer handles formula representation, evaluation, and dependency analysis.
The Core Model layer holds the data structures that both layers operate on.

### Module Structure

```
Sources/SwiftXLSX/
├── Core/                         # Data model
│   ├── Workbook.swift            # Container: sheets, named ranges, styles
│   ├── Worksheet.swift           # Cells, column widths, row heights
│   ├── CellValue.swift           # .string, .number, .formula, .date, .blank, .bool
│   ├── CellRef.swift             # A1-style cell reference with absolute/relative
│   ├── CellRange.swift           # Rectangular block: A1:B10
│   ├── NamedRange.swift          # Variable binding: name → cell/range + scope
│   └── SheetReference.swift      # Cross-sheet qualified reference
├── Formula/                      # Computation engine
│   ├── FormulaAST.swift          # Expression tree (the recursive enum)
│   ├── FormulaSerializer.swift   # AST → Excel formula string
│   ├── FormulaParser.swift       # Excel formula string → AST
│   ├── FormulaEvaluator.swift    # AST → computed value (given cell values + names)
│   ├── FunctionRegistry.swift    # Maps function names to implementations
│   ├── BuiltinFunctions.swift    # SUM, AVERAGE, PMT, NPV, IF, etc.
│   └── DependencyGraph.swift     # Build + topological sort of cell dependencies
├── Styling/                      # Composed value types
│   ├── CellStyle.swift           # Font + Border + Alignment + NumberFormat + Fill
│   ├── Font.swift
│   ├── Border.swift
│   ├── Alignment.swift
│   ├── NumberFormat.swift
│   ├── Fill.swift
│   └── Theme.swift               # Office theme colors and fonts
├── Layout/                       # Structural features
│   ├── MergeCell.swift
│   ├── FreezePane.swift
│   ├── AutoFilter.swift
│   └── DataValidation.swift
├── Writer/                       # .xlsx output
│   ├── WorkbookWriter.swift      # Workbook → XML entries → ZIP
│   ├── StyleSheetWriter.swift    # CellStyle objects → styles.xml
│   ├── SharedStringsWriter.swift
│   ├── ZIPWriter.swift           # Pure Swift ZIP writer
│   └── XMLEscape.swift
├── Reader/                       # .xlsx input
│   ├── WorkbookReader.swift      # ZIP → XML → Workbook
│   ├── WorksheetReader.swift     # Sheet XML → cells with parsed FormulaASTs
│   ├── StyleSheetReader.swift    # styles.xml → CellStyle objects
│   ├── SharedStringsReader.swift
│   ├── ZIPReader.swift           # Pure Swift ZIP reader
│   └── ThemeReader.swift         # theme1.xml → Theme
└── Template/                     # Default styling
    ├── DesignBundle.swift        # Configurable style bundle (fonts, widths, gutter, etc.)
    └── DefaultDesignBundle.swift # Opinionated defaults from user's Book.xltx template
```

### Implementation Phases

**Phase A: Formula Engine (split into three sub-phases)**

The core of the entire library. Everything else builds on this. Split into three sub-phases to isolate risk and enable parallel development of A1 and A3.

**Phase A1: Data Model — AST, References, and Serialization**

The expression tree, cell reference types, named ranges, and AST → string serialization. This is the foundation — pure data structures with no parsing or evaluation logic. Fast to build, easy to test, no ambiguity.

- `CellValue` — unified value type: `.number(Double)`, `.text(String)`, `.bool(Bool)`, `.error(ExcelError)`, `.formula(FormulaAST)`, `.date(Date)`, `.blank`, `.array([CellValue])`. This is both the storage type and the evaluation result — one type flows through the entire system.
- `FormulaAST` — recursive expression tree: arithmetic, comparisons, function calls, cell references, named ranges, literals, errors
- `FormulaSerializer` — AST → Excel formula string (for writing)
- `CellRef` — A1-style reference with absolute/relative markers ($A$1, A1, $A1, A$1)
- `CellRange` — rectangular range (A1:B10) with iteration, row/column counts, absolute variants
- `NamedRange` — variable binding: name → cell/range/formula, workbook or sheet scope
- `SheetReference` — cross-sheet qualified reference ('Sheet 2'!A1)
- `ExcelError` — #VALUE!, #REF!, #DIV/0!, #NAME?, #NULL!, #NUM!, #N/A
- Worksheet gains `write(_ formula: FormulaAST, to:, style:)` and `formulaAST(at:)`
- Workbook gains `addNamedRange(name:, ...)` and `resolveNamedRange(_:inSheet:)`

**Phase A2: Formula Parser**

The riskiest single piece — a recursive descent parser for Excel's formula grammar. Isolated so it doesn't block A1 or A3.

- `FormulaParser` — Excel formula string → AST, supporting:
  - A1-style cell references with absolute/relative markers
  - Cell ranges (A1:B10)
  - Named ranges (recognized as identifiers that aren't function names)
  - Function calls with comma-separated arguments
  - Arithmetic operators with correct precedence (+, -, *, /, ^)
  - Comparison operators (=, <>, >, <, >=, <=)
  - String concatenation (&)
  - Unary negation (distinguishing `-A1` from `A1-B1`)
  - Parenthesized sub-expressions
  - String literals ("hello"), number literals, boolean literals (TRUE/FALSE)
  - Error literals (#VALUE!, #REF!, etc.)
  - Sheet-qualified references ('Sheet Name'!A1)
- Parser errors with diagnostic messages: line position, what was expected, what was found
- Structured references, dynamic arrays, R1C1 mode, implicit intersection are OUT OF SCOPE — parser returns a clear error identifying the unsupported construct

**Phase A3: Evaluation Engine**

The evaluator, function registry, and dependency graph. Depends on A1 (the AST types) but is independent of A2 (the parser). Can be developed in parallel with A2.

- `FormulaEvaluator` — AST → CellValue, given a cell value provider and name resolver. Arithmetic maps to Swift operators. Functions dispatch through the registry. Cell refs are lookups. Named ranges are variable resolution.
- `FunctionRegistry` — CoW value type mapping function names to Swift implementations, user-extensible. Ships `.builtin` with ~40 functions. Consumers create new registries via `extending(_:with:)`.
- `BuiltinFunctions` — core Excel functions organized by category:
  - Math: ABS, ROUND, ROUNDUP, ROUNDDOWN, SQRT, LN, LOG, EXP, POWER, MOD, INT, CEILING, FLOOR, SIGN, PI
  - Stats: AVERAGE, STDEV, STDEVP, MEDIAN, MIN, MAX, COUNT, COUNTA, PERCENTILE, LARGE, SMALL, VAR, VARP
  - Financial: PMT, IPMT, PPMT, NPV, IRR, FV, PV, RATE, NPER, SLN, DB (IRR and RATE share an iterative solver)
  - Logical: IF, AND, OR, NOT, IFERROR, IFNA
  - Aggregation: SUM, SUMIF, SUMIFS, COUNTIF, COUNTIFS, AVERAGEIF
  - Text: LEN, LEFT, RIGHT, MID, TRIM, UPPER, LOWER, CONCATENATE, TEXT
  - Lookup: VLOOKUP, HLOOKUP, INDEX, MATCH
  - Date: TODAY, NOW, YEAR, MONTH, DAY, DATE
- `DependencyGraph` — DAG of cell dependencies built from formula ASTs. Topological sort for evaluation order. Circular reference detection. Input/output cell identification. Impact analysis (which outputs change if I modify this input?).
- Type coercion matching Excel semantics: "5"+3=8, TRUE+1=2, ""+0=0
- `Workbook.evaluate()` — recompute all formulas in topological order (single-threaded; not thread-safe — documented)
- `Workbook.evaluate(cell:inSheet:)` — recompute one cell and its downstream dependents

**Phase B: Rich Styling**
- Composed `CellStyle` with `Font`, `Border`, `Alignment`, `NumberFormat`, `Fill`
- Builder pattern: `.with(font:).with(border:)` returning new values
- `Theme` type for Office theme colors
- `DesignBundle` — configurable default styling applied to new workbooks. Ships with opinionated defaults derived from user's Book.xltx template (SF Mono Regular 11pt for data, SF Pro Display Semibold 18pt for titles, 2-column left gutter). Users can create custom bundles or modify the default. Not hardcoded — a value type the user passes to `Workbook.init` or sets globally.

**Phase C: Layout & Interactivity**
- Merge cells
- Freeze panes
- Auto-filter
- Data validation (dropdown lists, numeric constraints)
- Print area / page setup
- Row height

**Phase D: Pure Swift ZIP**
- Replace `/usr/bin/zip` Process with native Swift ZIP writer
- Native Swift ZIP reader
- Enables iOS and Linux support
- Extract XML generation from Workbook into WorkbookWriter

**Phase E: Full XLSX Reader**
- `WorkbookReader`: open .xlsx → parse ZIP → load XML → construct Workbook with parsed FormulaASTs, resolved named ranges, composed CellStyles
- `StyleSheetReader`: styles.xml → CellStyle objects
- `SharedStringsReader`: shared string table
- `ThemeReader`: theme1.xml → Theme
- Round-trip test: read existing .xlsx → save → verify identical output

Note: `FormulaParser` is in Phase A2, not Phase E. Parsing is fundamental to the AST — you can't evaluate formulas from existing workbooks without it. Phase E adds the *file format* reader (ZIP, XML, styles); Phase A2 provides the *formula* reader (string → AST).

## 4. API Surface

### Phase A1: Unified CellValue

```swift
/// The universal value type in SwiftXLSX. This is both the storage type (what's in a cell)
/// and the evaluation result (what a formula produces). Excel doesn't distinguish between
/// "the value 5 that a user typed" and "the value 5 that SUM produced" — neither do we.
public enum CellValue: Equatable, Hashable, Sendable {
    case number(Double)                              // 42, 3.14, 0.065
    case text(String)                                // "hello", "Q1 Revenue"
    case bool(Bool)                                  // TRUE, FALSE
    case error(ExcelError)                           // #VALUE!, #REF!, #DIV/0!
    case formula(FormulaAST, cached: CellValue?)     // =A1+B1 with optional cached result
    case date(Date)                                  // Serial date number internally
    case blank                                       // Empty cell
    case array([CellValue])                          // Range result (SUM argument, etc.)

    /// The computed value of this cell. For non-formula cells, returns self.
    /// For formula cells, returns the cached evaluation result (or .blank if not yet evaluated).
    /// For arrays, returns self. This is the "what would Excel show in this cell?" accessor.
    public var resolved: CellValue { get }

    /// Whether this cell contains a formula (evaluated or not).
    public var isFormula: Bool { get }

    /// The formula AST if this cell has one, nil otherwise.
    public var formulaAST: FormulaAST? { get }
}
```

### Phase A1: FormulaAST

```swift
/// The expression tree. Every Excel formula parses into this structure,
/// can be evaluated in Swift, and can be serialized back to an Excel formula string.
public indirect enum FormulaAST: Equatable, Hashable, Sendable {

    // ── Leaf Nodes ─────────────────────────────────────────────
    case cellRef(CellRef)                         // B2, $A$1
    case cellRange(CellRange)                     // A1:A10, $B$2:$B$100
    case sheetRef(SheetReference)                 // 'Sheet 2'!B2, 'Data'!A1:A100
    case namedRange(String)                       // DiscountRate, CashFlows
    case number(Double)                           // 0.065, 42
    case text(String)                             // "hello"
    case bool(Bool)                               // TRUE, FALSE
    case error(ExcelError)                        // #VALUE!, #REF!, #DIV/0!

    // ── Arithmetic ─────────────────────────────────────────────
    case add(FormulaAST, FormulaAST)              // left + right
    case subtract(FormulaAST, FormulaAST)         // left - right
    case multiply(FormulaAST, FormulaAST)         // left * right
    case divide(FormulaAST, FormulaAST)           // left / right
    case power(FormulaAST, FormulaAST)            // base ^ exponent
    case negate(FormulaAST)                       // -expr
    case concatenate(FormulaAST, FormulaAST)      // left & right

    // ── Comparison ─────────────────────────────────────────────
    case equal(FormulaAST, FormulaAST)            // =
    case notEqual(FormulaAST, FormulaAST)         // <>
    case greaterThan(FormulaAST, FormulaAST)      // >
    case lessThan(FormulaAST, FormulaAST)         // <
    case greaterOrEqual(FormulaAST, FormulaAST)   // >=
    case lessOrEqual(FormulaAST, FormulaAST)      // <=

    // ── Function Call ──────────────────────────────────────────
    // Generic: handles ALL Excel functions. Convenience builders below
    // provide type-safe construction for common ones.
    case function(String, [FormulaAST])           // name + arguments

    // ── Convenience Builders (common functions) ────────────────

    // Aggregation
    public static func sum(_ range: FormulaAST) -> FormulaAST
    public static func average(_ range: FormulaAST) -> FormulaAST
    public static func count(_ range: FormulaAST) -> FormulaAST
    public static func min(_ range: FormulaAST) -> FormulaAST
    public static func max(_ range: FormulaAST) -> FormulaAST
    public static func stdev(_ range: FormulaAST) -> FormulaAST
    public static func median(_ range: FormulaAST) -> FormulaAST

    // Financial
    public static func pmt(rate: FormulaAST, nper: FormulaAST, pv: FormulaAST) -> FormulaAST
    public static func ipmt(rate: FormulaAST, per: FormulaAST,
                            nper: FormulaAST, pv: FormulaAST) -> FormulaAST
    public static func ppmt(rate: FormulaAST, per: FormulaAST,
                            nper: FormulaAST, pv: FormulaAST) -> FormulaAST
    public static func npv(rate: FormulaAST, values: FormulaAST) -> FormulaAST
    public static func irr(values: FormulaAST, guess: FormulaAST) -> FormulaAST
    public static func fv(rate: FormulaAST, nper: FormulaAST, pmt: FormulaAST) -> FormulaAST
    public static func pv(rate: FormulaAST, nper: FormulaAST, pmt: FormulaAST) -> FormulaAST

    // Statistical
    public static func percentile(_ range: FormulaAST, k: FormulaAST) -> FormulaAST

    // Logical
    public static func `if`(_ test: FormulaAST,
                            then: FormulaAST, else: FormulaAST) -> FormulaAST

    // Lookup
    public static func vlookup(value: FormulaAST, table: FormulaAST,
                               col: FormulaAST, exactMatch: Bool) -> FormulaAST
}

/// Excel error values that can appear in cells and formulas
public enum ExcelError: String, Equatable, Hashable, Sendable {
    case value   = "#VALUE!"
    case ref     = "#REF!"
    case div0    = "#DIV/0!"
    case name    = "#NAME?"
    case null    = "#NULL!"
    case num     = "#NUM!"
    case na      = "#N/A"
}
```

### Phase A1: Cell Reference Types

```swift
/// A1-style cell reference with optional absolute markers
public struct CellRef: Equatable, Hashable, Sendable {
    public let column: Int              // 1-based
    public let row: Int                 // 1-based
    public let absoluteColumn: Bool     // $A vs A
    public let absoluteRow: Bool        // $1 vs 1

    public init(_ reference: String)    // Parses "A1", "$A$1", "A$1", "$A1"
    public init(column: Int, row: Int,
                absoluteColumn: Bool = false, absoluteRow: Bool = false)

    public var reference: String        // "A1", "$A$1", etc.
    public func absolute() -> CellRef  // Both column and row absolute
}

/// Rectangular range of cells
public struct CellRange: Equatable, Hashable, Sendable {
    public let start: CellRef
    public let end: CellRef

    public init(_ reference: String)            // "A1:B10"
    public init(from: CellRef, to: CellRef)
    public init(from: String, to: String)

    public var reference: String                // "A1:B10"
    public func absolute() -> CellRange         // "$A$1:$B$10"

    /// All cell references in this range, row by row
    public var cells: [CellRef] { get }

    /// Number of rows and columns
    public var rowCount: Int { get }
    public var columnCount: Int { get }
}

/// Cross-sheet qualified reference
public struct SheetReference: Equatable, Hashable, Sendable {
    public let sheetName: String
    public let range: CellRange     // Could also be a single cell (1x1 range)

    public init(sheet: String, range: CellRange)
    public init(sheet: String, cell: CellRef)

    public var reference: String    // "'Sheet Name'!A1:B10"
}
```

### Phase A1: Named Ranges (Variables)

```swift
/// A named range is a variable binding in the spreadsheet's symbol table.
/// `DiscountRate` → B5 is equivalent to `let discountRate = cellValue(B5)`.
/// `CashFlows` → B10:B20 is equivalent to `let cashFlows = cellValues(B10:B20)`.
public struct NamedRange: Equatable, Hashable, Sendable {
    public let name: String

    /// What the name resolves to: a single cell, a range, or a cross-sheet reference
    public let reference: NamedRangeTarget

    /// Scope: workbook-wide or sheet-specific
    public let scope: NameScope

    public enum NameScope: Equatable, Hashable, Sendable {
        case workbook
        case sheet(String)
    }
}

public enum NamedRangeTarget: Equatable, Hashable, Sendable {
    case cell(CellRef)
    case range(CellRange)
    case sheetCell(SheetReference)
    case sheetRange(SheetReference)
    case formula(FormulaAST)        // Named ranges can also be formulas (e.g., dynamic names)
}

// Workbook additions
extension Workbook {
    public var namedRanges: [NamedRange] { get }

    @discardableResult
    public func addNamedRange(name: String, cell: CellRef,
                              scope: NamedRange.NameScope = .workbook) -> NamedRange
    @discardableResult
    public func addNamedRange(name: String, range: CellRange,
                              scope: NamedRange.NameScope = .workbook) -> NamedRange
    @discardableResult
    public func addNamedRange(name: String, sheetRef: SheetReference,
                              scope: NamedRange.NameScope = .workbook) -> NamedRange

    /// Resolve a name to its target. Returns nil if name not found.
    public func resolveNamedRange(_ name: String,
                                  inSheet: String? = nil) -> NamedRangeTarget?
}
```

### Phase A1 (Serialization) + A2 (Parsing): Formula Serialization and Parsing

```swift
/// Converts a FormulaAST to an Excel formula string.
/// The output is what appears in the formula bar when you click a cell.
public enum FormulaSerializer {
    /// Serialize with standard A1-style references.
    /// Returns string WITHOUT the leading "=" — caller adds it for cell formulas.
    public static func serialize(_ ast: FormulaAST) -> String

    /// Serialize, resolving named ranges to their cell references.
    /// Use when you need fully-resolved formulas.
    public static func serialize(_ ast: FormulaAST,
                                  resolvingNamesWith resolver: NameResolver) -> String
}

/// Parses an Excel formula string into a FormulaAST.
/// Handles A1-style references, named ranges, function calls, operators.
public enum FormulaParser {
    /// Parse a formula string. The leading "=" is optional.
    public static func parse(_ formula: String) throws -> FormulaAST
}

/// Protocol for resolving named ranges during serialization or evaluation.
public protocol NameResolver: Sendable {
    func resolve(_ name: String, inSheet: String?) -> NamedRangeTarget?
}

// Workbook conforms to NameResolver
extension Workbook: NameResolver { ... }
```

### Phase A3: Formula Evaluation

```swift
/// Evaluates a FormulaAST to a concrete CellValue.
///
/// Given a cell value store (where to look up cell values) and a name resolver
/// (where to look up named ranges), walks the AST and computes the result.
///
/// Arithmetic maps to Swift operators. Function calls dispatch through
/// the FunctionRegistry. Named ranges resolve through the NameResolver.
/// Cell references look up values in the CellValueProvider.
///
/// Returns a CellValue — the same type that cells store. There is no separate
/// "evaluation result" type. Excel doesn't distinguish between a value the user
/// typed and a value a formula produced, and neither does SwiftXLSX.
public enum FormulaEvaluator {

    /// Evaluate a single formula AST.
    public static func evaluate(
        _ ast: FormulaAST,
        cells: CellValueProvider,
        names: NameResolver,
        functions: FunctionRegistry = .builtin
    ) throws -> CellValue

    /// Evaluate all formulas in a workbook in dependency order.
    /// Modifies cell values in place with computed results.
    /// Single-threaded; not thread-safe. See DependencyGraph for evaluation order.
    public static func evaluateAll(_ workbook: Workbook) throws
}

/// Protocol for looking up cell values during evaluation.
public protocol CellValueProvider: Sendable {
    func value(at ref: CellRef) -> CellValue?
    func value(at ref: CellRef, inSheet: String) -> CellValue?
    func values(in range: CellRange) -> [CellValue]
    func values(in range: CellRange, inSheet: String) -> [CellValue]
}

// Workbook conforms to CellValueProvider
extension Workbook: CellValueProvider { ... }
```

### Phase A3: Function Registry

```swift
/// Registry mapping Excel function names to Swift implementations.
/// Ships with ~40 built-in functions. User-extensible for custom functions.
///
/// Value type with copy-on-write semantics. No shared mutable state —
/// `extending(_:with:)` returns a new registry; the original is unchanged.
/// Sendable by construction; no `@unchecked` needed.
public struct FunctionRegistry: Sendable {

    /// The default registry with all built-in functions.
    public static let builtin = FunctionRegistry.makeBuiltin()

    /// Create an empty registry.
    public init()

    /// Create a new registry starting from a base, adding custom functions.
    /// The base registry is not modified.
    public static func extending(
        _ base: FunctionRegistry = .builtin,
        with functions: [String: ExcelFunction]
    ) -> FunctionRegistry

    /// Add a function to this registry (mutating — CoW).
    public mutating func register(name: String, function: ExcelFunction)

    /// Look up a function by name (case-insensitive).
    public func function(named: String) -> ExcelFunction?
}

/// A single Excel function implementation.
public struct ExcelFunction: Sendable {
    public let name: String
    public let minArgs: Int
    public let maxArgs: Int?   // nil = variadic
    public let evaluate: @Sendable ([CellValue]) throws -> CellValue

    public init(name: String, minArgs: Int, maxArgs: Int?,
                evaluate: @escaping @Sendable ([CellValue]) throws -> CellValue)
}

/// Built-in function categories (all registered in FunctionRegistry.builtin):
///
/// Math:       ABS, ROUND, ROUNDUP, ROUNDDOWN, SQRT, LN, LOG, EXP, POWER, MOD,
///             INT, CEILING, FLOOR, SIGN, PI
/// Stats:      AVERAGE, STDEV, STDEVP, MEDIAN, MIN, MAX, COUNT, COUNTA,
///             PERCENTILE, LARGE, SMALL, VAR, VARP
/// Financial:  PMT, IPMT, PPMT, NPV, IRR, FV, PV, RATE, NPER, SLN, DB
///             (IRR and RATE share an iterative Newton-Raphson solver;
///              BusinessMathExcel can override with BusinessMath's implementation)
/// Logical:    IF, AND, OR, NOT, IFERROR, IFNA
/// Aggregation: SUM, SUMIF, SUMIFS, COUNTIF, COUNTIFS, AVERAGEIF
/// Text:       LEN, LEFT, RIGHT, MID, TRIM, UPPER, LOWER, CONCATENATE, TEXT
/// Lookup:     VLOOKUP, HLOOKUP, INDEX, MATCH
/// Date:       TODAY, NOW, YEAR, MONTH, DAY, DATE
```

### Phase A3: Dependency Graph

```swift
/// Builds and queries the cell dependency graph for a workbook.
///
/// The dependency graph is a DAG where:
/// - Cells with no formula are leaf nodes (inputs)
/// - Cells with formulas depend on the cells they reference
/// - Named ranges are resolved to their target cells
///
/// This graph enables:
/// - Topological sort for evaluation order
/// - Identifying input cells (no formula = leaf = user-editable)
/// - Identifying output cells (no dependents = root = result)
/// - Impact analysis (which outputs change if I modify this input?)
public struct DependencyGraph: Sendable {

    /// Build the dependency graph from a workbook's formulas.
    public init(workbook: Workbook) throws

    /// All cells in topological order (evaluate in this order).
    public var evaluationOrder: [CellAddress] { get }

    /// Cells with no formula — the inputs to the model.
    public var inputs: [CellAddress] { get }

    /// Cells with no dependents — the outputs of the model.
    public var outputs: [CellAddress] { get }

    /// Cells that directly depend on the given cell.
    public func dependents(of cell: CellAddress) -> [CellAddress]

    /// Cells that the given cell directly references in its formula.
    public func precedents(of cell: CellAddress) -> [CellAddress]

    /// All cells downstream of the given cell (transitive dependents).
    public func allDependents(of cell: CellAddress) -> Set<CellAddress>

    /// True if the graph has no cycles.
    public var isAcyclic: Bool { get }

    /// If cycles exist, returns the cells involved.
    public var cycles: [[CellAddress]] { get }
}

/// A fully-qualified cell address (sheet + cell reference).
public struct CellAddress: Equatable, Hashable, Sendable {
    public let sheet: String
    public let cell: CellRef
}
```

### Worksheet and Workbook API Changes

```swift
extension Worksheet {
    /// Write a formula using the AST. The formula is serialized to an Excel string
    /// for the .xlsx file, and can be evaluated in Swift.
    public func write(_ formula: FormulaAST, to ref: String, style: CellStyle = .general)

    /// Get the formula AST for a cell, if it has one.
    public func formulaAST(at ref: String) -> FormulaAST?

    /// Existing writeFormula(_ string:) remains for backward compat.
    /// Internally parses the string into a FormulaAST.
}

extension Workbook {
    /// Evaluate all formulas in the workbook (topological order).
    /// Cell values are updated in place with computed results.
    public func evaluate() throws

    /// Evaluate a single cell and all cells that depend on it.
    public func evaluate(cell: CellRef, inSheet: String) throws

    /// Build and return the dependency graph for this workbook.
    public func dependencyGraph() throws -> DependencyGraph

    /// Read an existing .xlsx file (Phase E, but init signature defined now).
    public init(contentsOf url: URL) throws
}
```

### Phase B: Rich Styling

```swift
public struct Font: Equatable, Hashable, Sendable {
    public var name: String
    public var size: Double
    public var color: String?     // RGB hex or nil for theme
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool

    // No hardcoded static presets — defaults come from DesignBundle.
    // DesignBundle.default provides SF Mono Regular 11pt, SF Pro Display Semibold 18pt, etc.
    // Users can create custom bundles with their own font choices.
}

public struct Border: Equatable, Hashable, Sendable {
    public var top: BorderEdge?
    public var bottom: BorderEdge?
    public var left: BorderEdge?
    public var right: BorderEdge?

    public struct BorderEdge: Equatable, Hashable, Sendable {
        public let style: Style
        public let color: String
        public enum Style: String, Sendable {
            case thin, medium, thick, double, dashed, dotted
        }
    }

    public static let thin = Border(/* all edges thin */)
    public static let bottom = Border(bottom: .init(style: .thin, color: "000000"))
}

public struct Alignment: Equatable, Hashable, Sendable {
    public var horizontal: Horizontal?
    public var vertical: Vertical?
    public var wrapText: Bool
    public var indent: Int
    public enum Horizontal: String, Sendable { case left, center, right }
    public enum Vertical: String, Sendable { case top, center, bottom }
}

public struct NumberFormat: Equatable, Hashable, Sendable {
    public let formatString: String
    public static let general = NumberFormat(formatString: "General")
    public static let currency = NumberFormat(formatString: #"$#,##0.00"#)
    public static let percent = NumberFormat(formatString: "0.00%")
    public static let date = NumberFormat(formatString: "mm/dd/yyyy")
    public static let integer = NumberFormat(formatString: "#,##0")
    public static let accounting = NumberFormat(formatString: #"_($* #,##0.00_)"#)
    public init(formatString: String)
}

public struct Fill: Equatable, Hashable, Sendable {
    public let patternType: PatternType
    public let foregroundColor: String?
    public enum PatternType: String, Sendable { case none, solid, gray125 }
    public static func solid(_ color: String) -> Fill
}

public struct CellStyle: Equatable, Hashable, Sendable {
    public var font: Font
    public var border: Border?
    public var alignment: Alignment?
    public var numberFormat: NumberFormat
    public var fill: Fill?

    public func with(font: Font) -> CellStyle
    public func with(border: Border) -> CellStyle
    public func with(alignment: Alignment) -> CellStyle
    public func with(numberFormat: NumberFormat) -> CellStyle
    public func with(fill: Fill) -> CellStyle

    public static let general: CellStyle
    public static let currency: CellStyle
    public static let percent: CellStyle
    public static let integer: CellStyle
    public static let date: CellStyle
    public static let header: CellStyle
    public static let title: CellStyle
}

/// Configurable default styling applied to new workbooks. Ships with opinionated
/// defaults derived from user's Book.xltx template. Users can create custom bundles
/// or modify the default — this is not hardcoded.
public struct DesignBundle: Equatable, Sendable {
    public var bodyFont: Font               // Default: SF Mono Regular, 11pt
    public var titleFont: Font              // Default: SF Pro Display Semibold, 18pt
    public var labelFont: Font              // Default: SF Mono Semibold, 11pt
    public var gutterColumnCount: Int       // Default: 2 (columns A-B)
    public var gutterColumnWidth: Double    // Default: 2.85
    public var dataColumnWidth: Double      // Default: 14.28
    public var titleRowHeight: Double       // Default: 40.0
    public var defaultSheetNames: [String]  // Default: ["Definitions", "Sheet 1", ...]

    public static let `default`: DesignBundle  // The opinionated defaults above

    public init(/* all parameters with defaults */)
}

extension Workbook {
    /// Create a workbook with a design bundle applied.
    public init(designBundle: DesignBundle = .default)
}
```

### Phase C: Layout

```swift
extension Worksheet {
    public func mergeCells(_ range: CellRange)
    public func freezePanes(at ref: String)
    public func setAutoFilter(_ range: CellRange)
    public func addValidation(_ range: CellRange, type: ValidationType)
    public func setRowHeight(row: Int, height: Double)
}

public enum ValidationType: Sendable {
    case list([String])
    case decimal(min: Double, max: Double)
    case integer(min: Int, max: Int)
}
```

## 5. MCP Schema

N/A — SwiftXLSX is a library, not an MCP tool.

## 6. Constraints & Compliance

- **Concurrency:** FormulaAST, CellRef, CellRange, CellStyle, CellValue, NamedRange, DependencyGraph, FunctionRegistry are all value types — Sendable by construction. Workbook/Worksheet remain `@unchecked Sendable` reference types with justification. `Workbook.evaluate()` is single-threaded and not thread-safe (documented).
- **Safety:** No force unwraps. Formula parsing returns errors via `throws`. Division by zero produces `.error(.div0)`, not a crash. Circular references detected by DependencyGraph before evaluation. Evaluation depth is bounded to prevent stack overflow on deeply nested formulas.
- **Dependencies:** Zero. Foundation only. This is a hard constraint. Built-in function implementations (PMT, NPV, IRR, etc.) are pure Swift — no Accelerate, no vDSP, no external math libraries.
- **Platform:** macOS 14+, iOS 17+. Phase D (pure Swift ZIP) enables Linux.

## 7. Source & API Compatibility

**Phase A1:** Mostly additive. New FormulaAST, CellRange, NamedRange types. New `write(_ formula:)` method. `CellRef` gains `absoluteColumn`/`absoluteRow` properties — this is a breaking change to CellRef's initializer but the existing convenience `init(_ reference: String)` still works. `CellValue` is rewritten as a unified type (breaking — old `.formula(String)` becomes `.formula(FormulaAST, cached: nil)`).

**Phase A2:** Additive. New FormulaParser type.

**Phase A3:** Additive. New FormulaEvaluator, FunctionRegistry, DependencyGraph types. New `Workbook.evaluate()` method. Existing `writeFormula(_ string:)` now parses to AST internally (depends on A2).

**Phase B:** Breaking change to CellStyle. Deprecate old init, compose Font/Border/Alignment/NumberFormat/Fill. Static presets unchanged in name but different internals.

**Phase E:** Additive. `Workbook(contentsOf:)` initializer.

**Migration:** Each phase ships with its own semver tag.

## 8. Backend Abstraction

N/A — formula evaluation is CPU-only, single-threaded, and fast for typical workbook sizes. If evaluation of very large workbooks (100K+ formula cells) becomes a bottleneck, the DependencyGraph's topological levels could be evaluated in parallel (cells at the same level have no inter-dependencies). This is a future optimization, not a Phase A concern.

## 9. Dependencies

**Internal:** None — SwiftXLSX is the leaf dependency.
**External:** None. Foundation only. Built-in financial functions (PMT, NPV, IRR) are implemented from their mathematical definitions, not delegated to any library.

## 10. Test Strategy

**Test Categories:**

**AST Construction:**
- Build FormulaAST programmatically, verify structure
- Convenience builders produce correct `.function(name, args)` nodes

**Serialization (AST → string):**
- `.add(.cellRef("A1"), .cellRef("B1"))` → `"A1+B1"`
- `.pmt(rate:nper:pv:)` → `"PMT(B2/12,B3,-B1)"`
- Named ranges serialize as names, not cell refs: `.namedRange("Rate")` → `"Rate"`

**Parsing (string → AST):**
- `"A1+B1"` → `.add(.cellRef, .cellRef)`
- `"PMT(B2/12,B3,-B1)"` → `.pmt(rate: .divide(...), nper: ..., pv: .negate(...))`
- `"SUM(CashFlows)"` → `.function("SUM", [.namedRange("CashFlows")])`
- Operator precedence: `"A1+B1*C1"` → `.add(A1, .multiply(B1, C1))`
- Parentheses: `"(A1+B1)*C1"` → `.multiply(.add(A1, B1), C1)`

**Round-trip (string → AST → string):**
- Parse then serialize, verify output matches input (modulo whitespace)

**Evaluation:**
- Arithmetic: `2 + 3` → `.number(5.0)`
- Cell references: given A1=10, B1=20, evaluate `=A1+B1` → `.number(30.0)`
- Named ranges: given DiscountRate→B5, B5=0.065, evaluate `=DiscountRate/12` → `.number(0.00541667)`
- Functions: evaluate `=PMT(0.065/12, 360, -500000)` → `.number(3160.34)` (verify against Excel)
- Error propagation: evaluate `=1/0` → `.error(.div0)`
- Nested: evaluate `=IF(A1>100, PMT(B1/12,B2,-A1), 0)` — both branches
- Type coercion: `"5" + 3` → `.number(8)`, `TRUE + 1` → `.number(2)`
- Formula caching: after evaluation, `.formula(ast, cached: .number(42))` — `resolved` returns `.number(42)`

**Parser Error Reporting:**
- Missing closing paren: `"SUM(A1:A10"` → error with offset pointing to end, expected ")"
- Unsupported construct: `"Table1[Column]"` → error identifying structured reference as unsupported
- Invalid cell ref: `"AAA99999"` → error vs. valid ref (boundary: XFD1048576)
- Empty formula: `""` → error describing empty input

**Dependency Graph:**
- Linear chain: A1→B1→C1, verify topological order
- Diamond: A1→B1, A1→C1, B1+C1→D1, verify correct order
- Circular reference detection: A1→B1→A1, verify `isAcyclic == false`
- Input/output identification: verify leaf nodes are inputs, root nodes are outputs

**Named Range Resolution:**
- Workbook-scoped name resolves from any sheet
- Sheet-scoped name resolves only from that sheet
- Same name, different scopes: sheet scope takes precedence

**Built-in Functions (golden path for each):**
- `PMT(0.065/12, 360, -500000)` → `3160.34` (Excel reference)
- `NPV(0.10, [-1000, 300, 420, 680])` → `108.87` (Excel reference)
- `IRR([-1000, 300, 420, 680])` → `0.1663` (Excel reference)
- `SUM(1,2,3,4,5)` → `15`
- `AVERAGE(10,20,30)` → `20`
- `IF(TRUE, "yes", "no")` → `"yes"`
- `VLOOKUP(3, A1:B5, 2, FALSE)` → value in column B where column A equals 3

**Edge Cases:**
- Empty workbook evaluation (no formulas)
- Formula referencing empty cell (treat as 0 or "" depending on context)
- Very long formula strings (1000+ characters)
- Unicode in named ranges and sheet names
- 10K+ cell workbook evaluation performance

**Reference Truth:**
- Excel's own formula results for all built-in function tests
- User's Book.xltx template for styling tests
- Excel-generated .xlsx files as XML structure reference

**Validation Trace:**
- `FormulaAST.pmt(rate: .divide(.cellRef(CellRef("B2")), .number(12)), nper: .cellRef(CellRef("B3")), pv: .negate(.cellRef(CellRef("B1"))))` serializes to `PMT(B2/12,B3,-B1)`
- `FormulaParser.parse("PMT(B2/12,B3,-B1)")` produces the same AST (Phase A2)
- Given B1=`.number(500000)`, B2=`.number(0.065)`, B3=`.number(360)`: evaluates to `.number(3160.34)` (Phase A3)
- After evaluation, cell value is `.formula(pmtAST, cached: .number(3160.34))` — `.resolved` returns `.number(3160.34)`
- `CellRange("A1:B10").absolute().reference` → `"$A$1:$B$10"` (Phase A1)

## 11. Architecture Decision Review

**ADR-001: Formula AST over string builders**
- Category: architecture
- Decision: Formulas are a recursive enum (`FormulaAST`). Enables parsing, serialization, evaluation, and dependency analysis.
- Rationale: The AST is the shared representation between file format (read/write) and computation (evaluate). Without it, formulas are opaque strings.

**ADR-002: Named ranges are first-class AST nodes**
- Category: architecture
- Decision: `FormulaAST` includes `.namedRange(String)` as a leaf node, and `NamedRange` is in `Core/`, not `Layout/`.
- Rationale: Named ranges are Excel's variable system. `=NPV(DiscountRate, CashFlows)` is a formula with two variable references. Treating them as layout concerns would lose this semantic information. They must be resolvable during evaluation, which makes them part of the computation layer.

**ADR-003: The AST is evaluable**
- Category: architecture
- Decision: SwiftXLSX includes a formula evaluator that can compute results from ASTs without Excel. This makes it a computation engine, not just a file format library.
- Rationale: Every node in the AST maps to a Swift computation. Arithmetic is operators. Functions are registered implementations. Cell references are lookups. Named ranges are variable resolution. There is nothing in a typical Excel formula that Swift can't evaluate. Evaluation enables Monte Carlo (vary inputs, re-evaluate graph, collect outputs) and eliminates the need for Excel in the loop.

**ADR-004: CellStyle as composed value types**
- Category: api
- Decision: CellStyle composes Font, Border, Alignment, NumberFormat, Fill.
- Rationale: Enables reading styles from files, template defaults, and Hashable deduplication.

**ADR-005: Read support is a goal**
- Category: architecture
- Decision: SwiftXLSX reads and writes .xlsx files. "Reading/parsing XLSX" removed from non-goals.
- Rationale: Reading + AST + evaluation = importing any Excel model as a callable function.

**ADR-006: Unified CellValue type**
- Category: architecture
- Decision: CellValue is both the storage type and the evaluation result. No separate `EvaluationResult` enum. Formula cells use `.formula(ast, cached: result)` to hold both the expression and its computed value.
- Rationale: Excel doesn't distinguish between "the value 5 the user typed" and "the value 5 that SUM produced." A unified type means no conversion code at evaluation boundaries, and `.resolved` gives the display value regardless of how it was produced.

**ADR-007: FunctionRegistry as CoW value type**
- Category: concurrency
- Decision: FunctionRegistry is a struct with copy-on-write semantics, not an `@unchecked Sendable` class.
- Rationale: Eliminates the "only mutated during setup" runtime invariant. `extending(_:with:)` returns a new registry; the original is unchanged. Sendable by construction — no unsafe annotations needed.

**ADR-008: DesignBundle over hardcoded defaults**
- Category: api
- Decision: Default styling is a configurable `DesignBundle` value type, not hardcoded `Font.body` constants.
- Rationale: Different users and projects have different aesthetic preferences. The opinionated defaults (SF Mono, SF Pro Display, 2-column gutter) ship as `DesignBundle.default` but can be replaced without modifying library source.

**ADR-009: Phase A split into A1/A2/A3**
- Category: process
- Decision: The original monolithic Phase A is split into A1 (data model + serialization), A2 (parser), and A3 (evaluation engine). A1 and A3 can be developed in parallel; A2 is the highest-risk piece and is isolated.
- Rationale: The parser is the riskiest single component — Excel's formula grammar has ambiguities (unary minus vs subtraction, comma overloading, sheet name quoting). Isolating it prevents parser difficulties from blocking the rest of the engine. A3 only needs ASTs (from A1), not parsed strings (from A2).

## 12. Adversarial Review

**Strongest case for a different approach:**

The strongest counterargument is scope: SwiftXLSX is becoming a spreadsheet engine, which is a multi-year project category. openpyxl (read+write, no eval) is 30K+ lines. Google Sheets' computation engine is millions. Even a "simple" evaluator needs to handle: operator precedence, implicit type coercion (Excel silently converts "5" to 5 in arithmetic), error propagation (#VALUE! through a chain of formulas), range expansion (SUM(A1:A10) vs SUM(A1,A2,A3)), and 40+ built-in functions with their exact Excel semantics (including edge cases like PMT with a 0% rate, or IRR that doesn't converge).

A pragmatic alternative: skip evaluation entirely. Just parse + serialize the AST. Let BusinessMathExcel handle evaluation by mapping AST nodes to BusinessMath function calls — BusinessMath already has PMT, NPV, IRR implementations. SwiftXLSX stays a file format library; BusinessMathExcel becomes the computation layer.

**Why we're proceeding with evaluation in SwiftXLSX:**

The user's insight resolves this: "simple arithmetic maps to Swift math." The evaluator for `=B5*B6` is literally `values[B5] * values[B6]`. The evaluator for `=SUM(A1:A10)` is literally `values[A1...A10].reduce(0, +)`. These are not complex — they're trivial. The only complex implementations are the ~15 financial functions (PMT, NPV, IRR), and those have well-documented mathematical formulas.

The scope risk is real but bounded: we're implementing ~40 functions, not ~500. The `FunctionRegistry` is extensible, so BusinessMathExcel (or any consumer) can add more without modifying SwiftXLSX. And the evaluator is the entire value proposition — without it, the AST is just a data structure. With it, every Excel model becomes a callable Swift function.

**Where this design is most likely wrong:**

Type coercion. Excel is extremely loose with types: `"5" + 3` = 8, `TRUE + 1` = 2, `"" + 0` = 0. The evaluator needs to match these semantics or produce different results than Excel, which undermines trust. The mitigation: document the coercion rules explicitly and test against Excel's actual behavior for each case.

The other risk is the formula parser. Excel's formula grammar has quirks: unary minus vs subtraction, sheet names with spaces, structured references (`Table1[Column]`), implicit intersection (`@`), R1C1 mode. A recursive descent parser will handle 95% of real-world formulas. The remaining 5% can return a parser error with a description of what wasn't handled — better than silently producing a wrong AST.

**What an experienced critic would say:**

"You're one scope creep away from reimplementing Excel. Draw a hard line: evaluate A1-style formulas with the registered function set, return errors for everything else. Don't try to be complete — try to be correct for the formulas you do handle."

Agreed. The FunctionRegistry pattern enforces this: if a function isn't registered, evaluation returns `.error(.name)` — same as Excel does for unknown functions. We don't guess, we don't approximate, we error clearly.

## 13. Alternatives Considered

**Alternative 1: AST without evaluation (parse + serialize only)**
- Advantage: Dramatically simpler. No function implementations, no type coercion, no dependency graph.
- Disadvantage: The AST becomes a fancy data structure with no computational power. BusinessMathExcel must implement its own evaluator anyway.
- Why rejected: Evaluation is the core value proposition. Without it, you can't run Monte Carlo on imported models.

**Alternative 2: Delegate evaluation to BusinessMath entirely**
- Advantage: Reuses BusinessMath's existing PMT/NPV/IRR implementations. No duplication.
- Disadvantage: Creates a circular dependency expectation — SwiftXLSX is supposed to be the leaf dependency. Also, BusinessMath doesn't implement SUM, AVERAGE, IF, VLOOKUP.
- Why rejected: SwiftXLSX must be self-contained. BusinessMathExcel can extend the FunctionRegistry with domain-specific implementations, but basic evaluation works standalone.

**Alternative 3: Use an existing formula parser library**
- Advantage: Battle-tested parsing of Excel's formula grammar
- Disadvantage: No such library exists in pure Swift. JavaScript/Python parsers exist but can't be imported. Violates zero-dependency constraint.
- Why rejected: Must be Foundation-only.

## 14. Future Directions

- **Parallel evaluation:** Cells at the same topological level can be evaluated concurrently
- **Incremental evaluation:** When one cell changes, only re-evaluate its dependents (not the whole workbook)
- **Expression transformations:** Insert row → adjust all cell references in formulas
- **Conditional formatting:** Color scales, data bars, icon sets
- **Charts:** Bar, line, pie (significant OOXML complexity)
- **R1C1 references:** Alternative reference style, useful for programmatic formula generation
- **Array formulas / dynamic arrays:** SORT, FILTER, UNIQUE, SEQUENCE
- **Streaming writer:** Large files without full workbook in memory
- **Additional built-in functions:** Expand from ~40 to ~100+ based on demand

## 15. Open Questions

### Resolved

1. ~~Formula arguments: CellRef or String?~~ **CellRef.** No raw strings in the AST.
2. ~~CellStyle migration?~~ **Composed value types.** Font/Border/Alignment/NumberFormat/Fill.
3. ~~Pure Swift ZIP priority?~~ **Phase D before Phase E.** Reader needs ZIP reader.
4. ~~Phase ordering?~~ **A1 → A2 → A3 → B → C → D → E.** (A1 and A3 can be developed in parallel.)
5. ~~Named ranges: Layout or Core?~~ **Core.** They're variables, not layout.
6. ~~Evaluation: SwiftXLSX or BusinessMathExcel?~~ **SwiftXLSX.** Computation is core.

7. ~~Formula parser scope?~~ **A1-style references and common functions only.** Structured references, dynamic arrays, R1C1 mode deferred. Parser returns clear diagnostic error for unsupported constructs.

8. ~~Type coercion strategy?~~ **Match Excel.** `"5"+3=8`, `TRUE+1=2`. Document coercion rules and test against Excel's actual behavior.

9. ~~Template bundling?~~ **Configurable DesignBundle, not hardcoded.** Ships with opinionated defaults from Book.xltx template. Users can create custom bundles.

10. ~~IRR convergence?~~ **Match Excel: 20 iterations, 1e-7 tolerance, `#NUM!` on non-convergence.** IRR and RATE share an iterative solver. BusinessMathExcel can override with BusinessMath's Newton-Raphson.

11. ~~Unified CellValue and formula storage?~~ **Option (a): `.formula(FormulaAST, cached: CellValue?)`.** Keeps CellValue truly unified — one type, one cell, one value. `.resolved` returns the cached result or `.blank` if not yet evaluated.

12. ~~Parser error reporting?~~ **Include offset + expected-vs-found + suggestion.** Richer errors cost more code but save significant debugging time, especially since the parser is the riskiest component.

## 16. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Article Name:** SwiftXLSXGuide.md

Covers:
- Quick start: create workbook, write formulas, save
- Formula AST: building expressions, convenience builders, raw `.function()` escape hatch
- Named ranges: defining variables, using them in formulas
- Evaluation: computing formula results in Swift, the dependency graph
- Function registry: built-in functions, adding custom functions
- Rich styling: fonts, borders, alignment, number formats (Phase B)
- Layout: merge, freeze, filter, validate (Phase C)
- Reading .xlsx files (Phase E)
- Round-trip: read → modify → evaluate → save
- Extending with BusinessMathExcel
