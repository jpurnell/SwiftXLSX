# SwiftXLSX — Pure Swift Excel Library

Pure-Swift library for reading and writing .xlsx files.

## Session Start

1. `project/master_plan.md` — Architecture
2. `project/checklists/CURRENT_*.md` — Active tasks
3. Latest in `project/summaries/` — Where we left off

## Key Rules

- No force unwraps (`!`), no `try!`, no force casts (`as!`)
- Zero external dependencies — Foundation only
- All public APIs require DocC documentation
- All types must be Sendable
- Read/write library for .xlsx files

## Releases

- Tags are **`vX.Y.Z`** — matching BusinessMath and `development-guidelines/rules/release_checklist.md`.
- `Package.swift` version strings stay unprefixed (`exact: "0.7.0"`); SwiftPM strips the `v`
  when matching a tag to a version, so the two forms are the same version to it.
- Retagged 2026-09-01: every tag through 0.7.0 was recreated as `vX.Y.Z` on its original commit
  and the unprefixed tags deleted. Revisions are unchanged, so no consumer's `Package.resolved`
  or SwiftPM fingerprint record needed correcting.

## Quality Gate

`swift build && swift test` — zero warnings, zero failures.
