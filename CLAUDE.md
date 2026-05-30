# SwiftXLSX — Pure Swift Excel Writer

Zero-dependency Swift library for generating .xlsx files.

## Session Start

1. `development-guidelines/00_CORE_RULES/00_MASTER_PLAN.md` — Architecture
2. `development-guidelines/04_IMPLEMENTATION_CHECKLISTS/CURRENT_*.md` — Active tasks
3. Latest in `development-guidelines/05_SUMMARIES/` — Where we left off

## Key Rules

- No force unwraps (`!`), no `try!`, no force casts (`as!`)
- Zero external dependencies — Foundation only
- All public APIs require DocC documentation
- All types must be Sendable
- Write-only library — no XLSX parsing

## Quality Gate

`swift build && swift test` — zero warnings, zero failures.
