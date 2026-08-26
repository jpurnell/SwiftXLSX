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

## Open item, not addressed here

The local SwiftZIP clone at `Tools/SwiftZIP` is **one commit ahead of origin/main**, holding
unpushed zlib/gzip read features. SwiftXLSX does not use them. If those are wanted downstream,
tag and push a real SwiftZIP release and raise this requirement to match — deliberately,
this time.
