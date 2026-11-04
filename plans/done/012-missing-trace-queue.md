# Plan: 012 — Queue Nights missing a Heart Rate Trace on every launch

**For spec:** specs/012-sleep-tab.md
**Type:** improvement
**Branch:** feat/sleep-screen

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
>
> Same branch as the rest of spec 012 (PR ellismchardy/serenix#43, not yet merged). Cause,
> diagnosed on 2026-11-04 with a temporary readout on that PR: opening another branch's build
> made SwiftData drop the Heart Rate Trace and Wake Bouts from every stored Night, and the
> once-only flag (`queuedHeartRateTraceRebuilds` in UserDefaults) stopped this build refilling
> them. `git show 4720888 -- specs/012-sleep-tab.md` shows the spec change.

## Approach
The decision of what to queue moves fully into Core: `traceRebuilds` also takes the rebuilds
already queued and leaves those out, so calling it on every launch never queues a Night twice.
The shell then drops the once-only flag and calls it on each launch. One slice at the Night
rebuilds seam, then verify.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice: the missing-trace queue on every launch.** `traceRebuilds(for:now:in:)` gains
   the already-queued rebuilds (`alreadyQueued: [NightRebuild]`) and leaves out any already
   there. `StrapConnection` calls it on every launch with `NightStore.pendingRebuilds` and
   appends what it returns; `NightStore.hasQueuedTraceRebuilds` and its UserDefaults key go
   (the stale value on phones is left unread). Doc comments that say "once" are updated.
   - Seam: Night rebuilds · Files: `src/SerenixCore/NightRebuild.swift`,
     `tests/SerenixCoreTests/NightRebuildTests.swift`, `src/SerenixApp/StrapConnection.swift`,
     `src/SerenixApp/NightStore.swift`
   - Done when: "With 1 Nov's rebuild already queued, nothing more is queued; once 1 Nov's Night
     has a Heart Rate Trace, nothing is queued for it" passes, and the existing missing-trace
     tests still pass with an empty queue passed in.
2. [x] **Verify:** full suite + lint + typecheck green; every automated success criterion in
   spec 012 checked; no `hasQueuedTraceRebuilds` left. Carried to the PR checklist: the macOS CI
   build, and the two phone checks (recent Nights show their charts after a launch; after
   opening another build and then this one, they come back after a launch — on the owner's
   phone, Monday 2 Nov and Sunday 1 Nov).
   - Blocked by: 1

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
