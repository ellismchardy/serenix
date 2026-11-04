# Plan: 007 — Queue Days missing their values on every launch

**For spec:** specs/007-sleeping-hr-and-resting-hr.md (and specs/006-load-popup.md, which points to it)
**Type:** improvement
**Branch:** feat/missing-day-values-queue

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
>
> Why: on 2026-11-04 opening another branch's build made SwiftData drop newer stored fields.
> The Day backfills for HR Zones (spec 006) and Resting HR (spec 007) ran once behind the
> UserDefaults flags `heartRateZonesBackfilled` and `restingHRBackfilled`, so lost values were
> never refilled. Same weakness spec 012's missing-trace queue fixed for Nights (PR #43).

## Approach
`DayLoad` gains `valuesKept` (true for any Day worked out by Load of a Day; the init defaults it
to true). Day rebuilds gains the missing-values queue, `dayRebuilds(missingValuesIn:alreadyQueued:
now:in:)`: stored Days whose values weren't kept, still due, not already queued, oldest first.
The shell stores the note as an optional field on `StoredDayLoad` (nil reads as not kept),
asks the queue at the start of every rebuild pass, and drops both once-only flags. One slice at
the Day rebuilds seam (Core and shell together, so nothing is half-wired), then verify.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [ ] **Slice: the missing-values queue on every rebuild pass.** `DayLoad.valuesKept` (default
   true); `dayRebuilds(missingValuesIn:alreadyQueued:now:in:)` in Day rebuilds.
   `StoredDayLoad` gains `valuesKept: Bool?`, written true and read as `?? false`.
   `StrapConnection.rebuildNights()` queues what the function returns, from the stored Day Loads
   and `DayLoadStore.pendingRebuilds`, before working out the queued Days; the two `init` blocks
   and their UserDefaults keys go (stale values on phones are left unread). Doc comments that
   say "once" or "before spec 006/007" are updated.
   - Seam: Day rebuilds · Files: `src/SerenixCore/Day.swift`, `src/SerenixCore/DayRebuild.swift`,
     `tests/SerenixCoreTests/DayRebuildTests.swift`, `src/SerenixApp/DayLoadStore.swift`,
     `src/SerenixApp/StrapConnection.swift`
   - Done when: spec 007's four new Day rebuilds criteria pass (Days not kept queued oldest
     first and kept Days not; already-queued skipped; not-due skipped; a Day from Load of a Day
     with no Resting HR or HR Zones has its values kept), and no `heartRateZonesBackfilled` or
     `restingHRBackfilled` is left in the source.
2. [ ] **Verify:** full suite + lint + typecheck green; every unticked automated criterion in
   specs 006 and 007 checked. Carried to the PR checklist: the macOS CI build, and the phone
   checks (after opening another build of Serenix that doesn't store HR Zones or Resting HR,
   then this one, Days of the last 30 show them again after a launch, with no new sync; a
   second launch queues nothing more).
   - Blocked by: 1

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
