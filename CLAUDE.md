# SwiftXLSX — Pure Swift Excel Library

Pure-Swift library for reading and writing .xlsx files.

## Session Start

1. `project/master_plan.md` — Architecture
2. `development-guidelines/project/checklists/CURRENT_*.md` — Active tasks
3. Latest in `development-guidelines/project/summaries/` — Where we left off

## Key Rules

- No force unwraps (`!`), no `try!`, no force casts (`as!`)
- Zero external dependencies — Foundation only
- All public APIs require DocC documentation
- All types must be Sendable
- Read/write library for .xlsx files

## Quality Gate

`swift build && swift test` — zero warnings, zero failures.
