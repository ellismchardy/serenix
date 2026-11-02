# Plan: fix — Saved metrics blank after reopening

**For spec:** specs/003-nightly-metrics.md and specs/005-load.md (bug: root cause from `/diagnose`, below)
**Type:** bug
**Branch:** fix/saved-metrics-on-reopen

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).

## Context
If Serenix is swiped away right after a sync, the Today screen is blank on the next open
(no rings, no tiles) until the sync on open finishes. If the app stays open a few minutes
after the sync, the next open shows the metrics straight away. Spec 003 says "the Today screen
reads stored Nights" and Nights are kept forever. Nothing in it says to hide them while
leftover dates are worked out, so this is a bug and the spec doesn't change.

## Approach
**Root cause.** `StrapConnection.rebuildNights()` (`src/SerenixApp/StrapConnection.swift:325`)
publishes `nights` only after working through every queued Night rebuild. It publishes
`dayLoads` only after every queued Day rebuild. Each rebuild reads about 48 hours of History
Records, so the post-sync work takes minutes. Swiping the app away cuts it off, and the queue
stays in UserDefaults (`NightStore.pendingRebuilds`, `DayLoadStore.pendingRebuilds`). At the
next launch, `init` calls `rebuildNights()`, which drains that leftover queue before showing
anything. The screen stays blank meanwhile, even though the stored Nights and Day Loads are
intact in SwiftData.

**Minimised repro (on the phone).** Sync, swipe away as soon as it completes, reopen → blank.
Sync, wait a few minutes, swipe away, reopen → metrics show. The only difference is whether
the queue was empty at launch.

**Fix.** At the start of the rebuild task, read and publish the stored Nights and Day Loads
before working the queues. Keep the existing publishes after each queue, so worked-out values
replace them. This reuses `NightStore.nights(in:)` and `DayLoadStore.dayLoads(in:)`
(`src/SerenixApp/NightStore.swift`, `src/SerenixApp/DayLoadStore.swift`) and the existing
`storeLog` error handling.

**Test seam.** The user chose this: the shell is checked by hand on the phone (ADR 0002).
No `SerenixCore` change, so no new automated test. The regression check is the repro above,
listed in the PR's manual steps.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Fix:** show the stored Nights and Day Loads before working the leftover queues.
   - Seam: shell, checked by hand (ADR 0002) · Files: `src/SerenixApp/StrapConnection.swift`
     (`rebuildNights()` and its doc comment only).
   - In the detached task, right after `await previous?.value`, fetch
     `NightStore.nights(in:)` and `DayLoadStore.dayLoads(in:)` and assign them on the main
     actor. On a read error, log as the later reads do, and leave the queues to run as now.
   - Done when: lint and `swift build` are clean, the macOS CI job builds the app, and the
     hand check passes: swipe away straight after a sync, reopen, and the rings and tiles show
     at once (before the sync on open finishes), then update when the rebuild completes. A
     normal reopen still shows metrics, and the Load ring shows its stored value at once too.
2. [x] **Cleanup:** drop the throwaway probe.
   - Files: none on this branch (the probe was only ever on `prototype/reopen-probe`).
   - Close draft PR ellismchardy/serenix#24 without merging, and delete the remote and local
     `prototype/reopen-probe` branch, after the user confirms. Confirm that grepping
     `DEBUG-n7r4` on `fix/saved-metrics-on-reopen` finds nothing.
   - Done when: no `[DEBUG-n7r4]` lines exist on this branch, and #24 is closed.
3. [x] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
   `swift build` all green. The PR body lists the manual phone steps from task 1.
   - Blocked by: 1, 2

## Manual check on the phone (for the PR body)
1. Open Serenix and let it sync until the metrics show.
2. Swipe it away as soon as the sync completes, then reopen it: the rings, tiles and Load ring
   show at once, while the sync on open is still running.
3. When that sync and its rebuild finish, the values update in place (no blank in between).
4. Sync, wait a few minutes, swipe away, reopen: the metrics show at once, as before.

## Done when
- All tasks checked. After a cut-off post-sync rebuild, reopening shows the stored Nights and
  Day Loads straight away, matching spec 003 ("the Today screen reads stored Nights") and spec
  005. The suite is green.
