# 2026-08-25 — Quality gate driven to 0 errors / 0 warnings

## Where we started

`swift build` failed outright: SwiftZIP could not resolve.

```
error: Dependencies could not be resolved because no versions of 'swiftzip'
match the requirement 0.5.0..<1.0.0
```

## What was actually wrong

Not a SwiftZIP update, as first assumed. **No `0.5.0` tag has ever existed.** SwiftZIP's
only tag, on the remote and in the local clone, is `0.3.0`. `Package.resolved` had pinned
"0.5.0" at revision `7fa8643`, which is not in SwiftZIP's history — the guidelines-layout
refactor rewrote that history and the tag went with it. (SwiftXLSX's *own* version is
0.5.0, which is a plausible origin for the wrong number, though that is inference.)

Every SwiftZIP API SwiftXLSX uses — `ZIPReader.read`, `ZIPReader.readEntry`,
`ZIPWriter.write` — exists in 0.3.0, so relaxing the requirement cost nothing.

## The cascade

Fixing the build let the gate run further, and each fix uncovered the next layer:

1. **build** — `from: "0.5.0"` → `from: "0.3.0"`.
2. **safety** — force unwrap → `XCTUnwrap`; two path-traversal warnings. Note for next
   time: `.standardized`, which the auditor's own hint recommends, does **not** clear that
   rule. It fires on the string-path API itself. Switching to `url.checkResourceIsReachable()`
   cleared it; nearby `removeItem(at:)` calls were never flagged.
3. **config** — `.quality-gate.yml` used `checkers` and `exclude`, two keys this gate
   version does not recognise, so the config was silently inert and **five checkers never
   ran**. Correcting `checkers` → `enabledCheckers` took errors from 5 to 14. That increase
   was the fix working. `exclude: [disk-clean]` was deleted rather than renamed: `disk-clean`
   is no longer a checker, having moved to the `quality-gate clean` subcommand.
4. **bounded-io** — tests shelled out to `/usr/bin/unzip`. The checker wanted a
   `ProcessRunner` kernel that does not exist in this project, so the subprocess was removed
   entirely in favour of `SwiftZIP.ZIPReader`. Those tests went ~0.150s → ~0.010s.
5. **doc-comment-code** — 13 doc examples did not compile. This checker only began running
   after the config fix.
6. **doc-lint / doc-code** — added a DocC catalogue. That in turn activated `doc-code`,
   which caught an undefined symbol in the new catalogue's own example.

## Verification worth keeping

The rewritten `WorkbookTests` assertions were checked for teeth: a bogus entry was injected,
both tests were confirmed to fail, then it was reverted. A test that cannot fail is worse
than the warning it silences. This was done twice — once after the `fileExists` rewrite and
again after the mechanism changed to `ZIPReader`.

## End state

45/45 checkers, 0 errors, 0 warnings, no overrides. Institutional consistency 0.50 → 1.00.
1395 XCTest + 44 swift-testing tests pass.

## Follow-on: SwiftZIP 0.6.0 released, SwiftXLSX raised to it

SwiftZIP is developed at `Tools/SwiftZIP` (it is the canonical repo, not a checkout). It held
two unreleased feature commits — the gzip and zlib readers — so 0.6.0 was cut and pushed, and
this package's requirement raised from the interim `0.3.0` to `0.6.0`.

**Version numbering:** 0.4.0 and 0.5.0 are retired and will not be published. 0.5.0 is burned
(its tag was deleted and the commit is gone); 0.4.0 would sort *below* it, so any surviving
`from: "0.5.0"` pin would still resolve to nothing. 0.6.0 is unambiguously past the gap.

**The same latent failure was found there.** SwiftZIP's gate config did not enable the full
checker set, so `doc-run` and `doc-comment-code` had never run: its DocC article trapped at
runtime on `ZIPError.truncatedArchive` (it read `Data()` as an archive — empty `Data` is a
*truncated* archive, not an empty one), and five doc-comment examples did not compile. Both
packages now set `enabledCheckers: [all]`. **If another package in this org has a default
checker selection, assume its doc examples are broken until proven otherwise.**

**Two quality-gate quirks worth remembering:**
- `quality-gate release` reports `release.version-mismatch` against *its own* CLI version
  (3.1.0) rather than the project's, in both packages and regardless of `--tag`. It is a tool
  bug, not a project defect. Do not invent a version constant to satisfy it.
- `release-readiness` errors when the README advertises a version whose tag does not exist
  yet — which is unavoidable while preparing the tagging commit. Create the tag first so the
  pre-commit hook runs against real content, then move the (still unpushed) tag onto the
  release commit.
