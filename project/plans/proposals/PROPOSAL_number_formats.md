# Design Proposal — rendering a number the way the sheet does

**Status:** proposal, 2026-09-11. Phase 0 (Design).
**Motivated by:** `BusinessMathExcel/project/plans/proposals/PROPOSAL_html_grid.md`, which needs
to display a cell as the practitioner's sheet displays it. The capability belongs here, where
every consumer gets it and where styles already live.

---

## 1. Objective

**Turn a stored value and a format code into the text Excel would show.**

```swift
NumberFormat("0.0%").string(from: 0.4212389)      // "42.1%"
NumberFormat("#,##0;[Red](#,##0)").string(from: -1234)  // "(1,234)"
NumberFormat("d mmm yyyy").string(from: 45292)    // "12 May 2024"
```

Today SwiftXLSX **stores and round-trips** format codes — `StyleSheet` writes `numFmt` with a
`formatCode`, `StyleSheetParser` reads them back — but nothing applies one to a value. A consumer
can learn that C4 is formatted `0.0%` and still has no way to render `42.1%`.

The gap matters because the failure is not cosmetic. A practitioner shown `0.4212389` where their
sheet shows `42.1%` concludes the tool is broken, not that formatting is unimplemented.

---

## 2. Ship a subset. Build the whole grammar.

This is the decision the proposal exists to make, and getting it backwards is expensive.

Excel's format language is genuinely large: up to four `;`-separated sections for
positive / negative / zero / text, `0` and `#` and `?` placeholders, thousands separators,
trailing commas that scale by thousands, `%` that scales by 100, date and time codes, literal
text, escapes, bracketed colours, bracketed conditions, fractions, scientific notation, and
locale tags like `[$£-809]`.

Two ways to reach a working subset:

| | Approach | Extending to full coverage |
|---|---|---|
| ✗ | match known code strings, or regex the common shapes | **a rewrite** — the structure was never there |
| ✓ | **tokenise and parse the whole grammar; implement a subset of the *semantics*** | **filling in cases** |

**Parse everything; render what is understood.** A format code the parser can read but the
renderer cannot yet express falls back to raw — and says so. A format code the parser cannot even
tokenise is a parser bug, and should be rare and fixable, not a category of permanent failure.

The cost of the right approach is roughly a week of grammar work before the first percent sign
renders. The cost of the wrong one is doing it twice.

---

## 3. The census comes first

**Which codes matter is measurable, not a matter of taste.** The corpus is 2,240 workbooks, and
`CorpusMeasurementTests.swift` already establishes the pattern — a sweep keyed on
`BUSINESSMATHEXCEL_CORPUS`, the same technique that produced the function-coverage matrix and
settled which `YEARFRAC` basis the corpus actually asks for.

So, before any renderer is written:

> Sweep every workbook, collect every distinct `formatCode` and the number of cells carrying it,
> and rank by frequency.

That output is worth more than an opinion, and it delivers three things at once:

1. **An implementation order** — by real frequency, not by what looks important.
2. **A definition of done that is not "the whole spec"** — a percentage of corpus cells rendered
   correctly, which can be stated and tracked.
3. **A coverage matrix**, in the shape the function matrix already uses: code, cells, workbooks,
   status, notes. Reconciled against the implementation rather than maintained by hand — the
   discipline that caught eight drifted rows in the function matrix.

Expect the distribution to be brutally skewed. General, `0`, `0.00`, `#,##0`, `#,##0.00`, a
currency form and two or three date forms will very likely be the overwhelming majority, with a
long tail of one-offs. **That is the argument for a subset and also the plan for retiring it.**

---

## 4. Staging

| Stage | Content | Done when |
|---|---|---|
| **0** | The census of §3 | the ranked code list exists |
| **1** | Tokeniser + parser for the **full grammar**; AST; the `General` case | every corpus code parses, or the failures are named |
| **2** | Renderers for the head of the distribution — placeholders, separators, `%`, sections, common dates | a stated % of corpus cells render correctly |
| **3** | Colours, conditions, fractions, scientific, locale tags | the tail closes; matrix reaches 100% |

Stage 1 is the load-bearing one and should not be compressed. Stages 2 and 3 are additive and can
be interleaved with other work, which is exactly the property the "path to full coverage"
requirement asks for.

---

## 5. The invariant that makes shipping a subset safe

> **No format code is ever silently wrong.**

Three outcomes, and only three:

| | Result |
|---|---|
| understood | the formatted string |
| parsed, not yet renderable | the raw value, **plus the format code**, marked unformatted |
| not parseable | the raw value, marked, **and recorded as a parser defect** |

A consumer can therefore always tell the difference between "this is what your sheet shows" and
"this is the number, I could not format it." The HTML grid surfaces the second on hover; the CLI
prints it plainly.

Without that invariant a subset is indistinguishable from a bug. With it, a subset is a stated
capability with a visible edge — and the edge shrinks on a schedule the census makes measurable.

---

## 6. Work

| # | Item |
|---|---|
| 1 | The corpus census of §3, and the coverage matrix it produces |
| 2 | `FormatCode` — tokeniser and parser over the full grammar |
| 3 | `NumberFormat.string(from:)` — renderers for stage 2 |
| 4 | The three-outcome result type of §5, so callers can distinguish the cases |
| 5 | Stage 3, ordered by the census |

---

## 7. Test strategy

- **Published examples.** Microsoft documents the format language with worked examples; each is a
  test, quoted rather than computed from what this code returns.
- **Round-trip the census.** Every distinct code in the corpus must parse. A code that does not is
  a named failure, not a silent fallback — that is how stage 1 knows it is done.
- **The invariant of §5 is asserted directly**: a deliberately unsupported code returns the
  unformatted case, never a wrong string. This is the test that keeps a subset honest.
- **Negative-zero and the section rules.** `0.00;(0.00)` on `-0.001` is a classic wrong answer;
  so is which section an exact zero takes when only two are given.

---

## 8. Open questions

1. **Locale.** `[$£-809]` and the separator conventions are locale-dependent, and Foundation has
   opinions. Proposed: render the workbook's own locale where the file states one, fall back to
   `en_US` separators, and **never** use the host machine's locale — the same discipline
   `gregorianUTC` established for calendars in BusinessMath, and for the same reason.
2. **Dates.** Serial-to-date conversion already exists in SwiftExcelFunctions
   (`BuiltinDateTimeFunctions.serialToDate`, phantom 1900 leap day included) but lives downstream
   of here. Duplicating it would put two answers in one dependency chain. Worth deciding whether
   it moves to SwiftExcelCore before stage 2 needs it.
3. **Does this belong in SwiftXLSX or SwiftExcelCore?** Styles live here, which argues for here.
   But `CellValue` lives in Core, and a formatter is arguably vocabulary. Leaning SwiftXLSX on the
   grounds that the format code is storage, not semantics.
