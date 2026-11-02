# Plan: 007 — Sleeping HR and Resting HR

**For spec:** specs/007-sleeping-hr-and-resting-hr.md (also the 007 edits to specs 002 and 005)
**Type:** feature
**Branch:** feat/sleeping-hr-and-resting-hr (already exists; holds the spec commit 51c333e)

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
A lot of apps, Serenix included, report the lowest heart rate during sleep as "Resting HR". Real
Resting HR is awake and at rest, a few bpm higher. Spec 007 (approved) renames the Night metric
to **Sleeping HR**, which keeps driving Baseline, Zones and Readiness. It adds an awake
**Resting HR** per Day, worked out from History Records the phone already has, so no constant
connection is needed. Load's heart-rate reserve then uses Resting HR, and the Today screen gets
a Resting HR tile. Spec 006 has since merged to `main` (#25–#27), and the user is pushing a bug
fix to `main` too, so the branch starts by merging `main`. That merge has no file conflicts:
`git merge-tree` is clean.

## Approach
- **Merge `main` first** and fix the docs that have drifted since spec 006:
  - spec 006's test default "no Nights (Resting HR 60)"
  - `docs/architecture.md`'s Day model and Baseline line
  - spec 007's stale note about 006
- **Prefactor:** share spec 003's per-minute binning (`SleepPeriod.swift`: `minuteTable`,
  `turn`, `normalised`, `activeDegrees`, `longestActiveGap`, `fewestRecordsPerMinute`, all
  private today) so Resting HR reuses the same 2° rule.
- **Rename the Night metric** in one compile-checked task. It's about 66 uses in src and 115 in
  tests. `StoredNight` keeps its column through `@Attribute(originalName: "restingHR")`, so past
  Nights keep their values. This is the first use of `originalName` in the app, so it gets a
  phone check.
- **Build Resting HR of a Day** test-first in three slices: the tracer, the still-minute rules,
  then the Day rules.
- **Store Resting HR and switch Load:** `DayLoad` gains `restingHR`, and Load's median reads
  Days instead of Nights.
- **Today screen:** the Resting HR tile.
- **The real fixture Day comes early**, because it can disprove the steps rule.
  - It needs the owner to share a Sync Log covering a full Day. If the Strap's step count isn't
    usable, stop and reopen the spec.
- **Decided while planning:**
  - On a Day with no Night, Today stays as it is now: no tiles, so no Resting HR tile either.
  - A rebuilt Day's Resting HR doesn't redo later Days' Load, mirroring spec 005's rule for
    Nights. Day rebuilds already run oldest first.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Merge `main` and reconcile docs:** wait for the user's bug-fix push, then
   `git fetch origin` and `git merge origin/main` (a merge, no force-push). Then update the docs:
   - `specs/006-load-popup.md`: the default becomes "no Days with a Resting HR (Resting HR 60)"
   - `docs/architecture.md`: the Day "with its Load, Resting HR, HR Zones…", "Sleeping HR's
     Spread", and the Health export writing Resting HR, never Sleeping HR
   - `specs/007` Notes: 006 has shipped

   Docs only; no behaviour change.
   - Files: `specs/006-load-popup.md`, `docs/architecture.md`, `specs/007-…md` (Notes only)
   - Done when: the merge is committed; `swift test`, lint and build are green.

2. [x] **Prefactor: shared motion minutes.** Move the minute binning and turn helpers out of
   `SleepPeriod.swift` into an internal type (e.g. `MotionMinutes`) without changing Sleep
   Period behaviour.
   - Files: `src/SerenixCore/SleepPeriod.swift`, new `src/SerenixCore/MotionMinutes.swift`
   - Done when: the existing suite is green, including the NightsTests fixture night (spec 003's
     values unchanged).

3. [x] **Rename the Night metric to Sleeping HR.** This covers:
   - `Night.sleepingHR` and `NightlyMetric.sleepingHR` (name "Sleeping HR")
   - `NightlyMetrics.sleepingHR(of:)`
   - Zone, Baseline, MetricTile, VsBaseline, ReadinessAdvice ("Sleeping HR is up N bpm"),
     Popups and TodayView
   - the shell (`NightStore` with `@Attribute(originalName: "restingHR") var sleepingHR`,
     `MetricTileView` icon, doc comments)
   - all tests. Rewrite the tests that assert the old names and wording (TodayViewTests names
     list and advice strings, NightsTests names); that follows the spec, it isn't weakening them.

   Load's own `restingHR` stays for now, but it reads `\.sleepingHR` until task 8. References to
   hr-tracker's `RHR_SPAN` and `resting_hr()` keep their outside names.
   - Seam: Nights, Today view · Files: the files the rename touches (Night, NightlyMetrics,
     Nights, Zone, Baseline, MetricTile, VsBaseline, ReadinessAdvice, Popups, TodayView, Load (one
     key path), NightStore, MetricTileView, TodayPopups, TodayScreen; TodayViewTests,
     NightsTests, LoadTests, DayHeartRateTests, HistoryRecordBuilder)
   - Done when:
     - The fixture night gives Sleeping HR 48.1.
     - The tile names say "Sleeping HR".
     - Take it easy says "Sleeping HR is up 4 bpm".
     - vs your Baseline and the Readiness popup name Sleeping HR.
     - Searching src for `restingHR` finds only Load's.

4. [x] **Real fixture Day and the step-counter check.**
   - The owner shares a Sync Log from a sync covering a full Day.
   - Convert it to `tests/SerenixCoreTests/Fixtures/Day-<date>.csv`:
     - decode it with the Whoop 5 History Record decoder (a one-off script, not committed)
     - remove the serial and device ID, per docs/conventions.md
     - add a `steps` column, which the fixture reader takes as optional (Night CSVs stay as they
       are)
   - Add a test that the step count stays flat over a stretch the owner says they sat still and
     rises over a stretch they walked.
   - If the counter isn't usable, **stop** and reopen spec 007's still rule.
   - Seam: fixture (History Records) · Files: `NightFixture.swift` (or a new `DayFixture.swift`),
     the new fixture CSV, a new fixture test
   - Done when: the steps criterion of spec 007's real-fixture-Day criterion passes.

5. [ ] **Tracer: Resting HR of a Day.**
   - Add a builder for minute-by-minute records (bpm, steps rising or flat, active seconds per
     minute, worn records per minute).
   - Add `restingHR(of day:records:nights:in:) -> Double?`, covering:
     - the Day span (`Day.span(in:)`)
     - still minutes via `MotionMinutes`
     - still runs, 4 settling minutes, 5-minute windows within minutes 5–15, the lowest mean
   - Every constant is named and cites docs/research/awake-resting-hr.md or spec 003.
   - Seam: Resting HR of a Day · Files: new `src/SerenixCore/RestingHR.swift`, new
     `tests/SerenixCoreTests/RestingHRTests.swift`, `HistoryRecordBuilder.swift`
   - Done when: the desk Day gives 62, and with minutes 5–9 at 66 it gives 64.

6. [ ] **Still-minute rules.** Active seconds (10 means none, 9 gives 62), a step breaking a run
   (50), a step-count drop counting as no step (62), and worn records (29 gives 55.6, 30 gives
   62).
   - Seam: Resting HR of a Day · Files: `RestingHR.swift`, `RestingHRTests.swift`
   - Done when: those four spec 007 criteria pass.

7. [ ] **Day rules.** The 8-hour rule (479 worn minutes means none, 480 gives 62), leaving out the
   Sleep Period of an overlapping Night (45 without it, 62 with it, still none at 479), Day
   boundaries and the 25 Oct 2026 clock change, and repeats and order. Then the real fixture
   Day: Resting HR present, at least that morning's Sleeping HR, and no more than 15 bpm above
   it.
   - Seam: Resting HR of a Day · Files: `RestingHR.swift`, `RestingHRTests.swift`, the fixture
     test
   - Done when: those spec 007 criteria pass, and the real-fixture-Day criterion passes in full.

8. [ ] **Load reads Days' Resting HR.**
   - `DayLoad` gains `restingHR: Double?`.
   - `load(of:records:…)` takes the Days (`[DayLoad]`) in place of the Nights.
   - `LoadMethod.restingHR(for:among:)` takes the median of up to 14 Days on or before the Day,
     with today counting, Days without a value skipped, and a 60 bpm fallback.
   - Port LoadTests' Night-based Resting HR tests to Days, add "Nights alone give the fallback",
     and port DayHeartRateTests' `Night(restingHR: 100)` to a Day.
   - Seam: Load of a Day · Files: `Load.swift`, `Day.swift`, `LoadTests.swift`,
     `DayHeartRateTests.swift`, `LoadPopupTests.swift`/`TodayViewTests.swift` only if their
     `DayLoad` construction needs the new field
   - Done when: spec 005's unticked criteria pass (Resting HR median from Days, Nights alone give
     60, Max HR at Resting HR from a Day).

9. [ ] **Shell: store Resting HR and work it out before Load.**
   - `StoredDayLoad` gains an optional `restingHR` (it migrates by itself, like `heartRate`).
   - `DayLoadStore.apply` works out the Day's Resting HR (with the Nights), then Load with the
     stored Days plus this one.
   - Add a one-time `restingHRBackfilled` UserDefaults flag beside `heartRateZonesBackfilled` in
     `StrapConnection.init` that queues `dayRebuildsDue`.
   - Fix the comment at `StrapConnection.swift` around line 437.
   - Shell; checked by hand (ADR 0002).
   - Files: `src/SerenixApp/DayLoadStore.swift`, `src/SerenixApp/StrapConnection.swift`
   - Done when: it builds in CI; the phone steps go in the PR (past Nights keep their values as
     Sleeping HR, and Days of the last 30 days gain a Resting HR).

10. [ ] **Today screen: Resting HR tile and layout.**
    - In `SerenixCore`, a `RestingHRTile` beside `TimeAsleepTile`: value "62 bpm" or "—", "So far
      today" on today, no Zone, no popup.
    - TodayView exposes the grid order after Time Asleep: Sleeping HR, Resting HR, HRV,
      respiratory rate, skin temperature, SpO2, with tiles only when there's a Night.
    - In the shell, draw it through `TileCard` with the heart icon, put Time Asleep full width
      above a 2-column grid, and make the tile not tappable.
    - Seam: Today view · Files: new `src/SerenixCore/RestingHRTile.swift`, `TodayView.swift`,
      `TodayViewTests.swift`, `src/SerenixApp/MetricTileView.swift`,
      `src/SerenixApp/TodayScreen.swift`
    - Done when: spec 007's Today view criteria (order; 61.6 shows as "62 bpm" with "So far
      today"; an earlier Day shows "58 bpm" with no status; "—" with an empty gauge) and spec
      002's unticked advice criterion pass.

11. [ ] **Verify:**
    - `swift test`, `swift format lint --strict --recursive src tests Package.swift` and
      `swift build` are green, and the macOS CI job builds the app.
    - Every spec 007 criterion, and the unticked 002 and 005 criteria, are ticked.
    - Mark specs 007, 002 and 005 as `built`.
    - List the phone steps for the PR:
      - an install over the previous build keeps past Nights
      - Days gain a Resting HR
      - after a full Day, the tile reads a few bpm above Sleeping HR, with "So far today" on today
      - the layout
    - Move the plan to `plans/done/`.
    - Blocked by: 7, 9, 10

## Done when
- All tasks checked, every success criterion in spec 007 (and the unticked ones in 002 and 005)
  met, suite green.

## Verification
- Each task: `swift test` (Swift Testing), lint, and `swift build` on Windows, as in
  CLAUDE.md's Key commands.
- Expected Resting HR values are the spec's hand-worked literals (62, 64, 50, 55.6, 45).
  They're never recomputed like the code.
- Shell changes (tasks 3, 9 and 10): the macOS CI job builds the `.ipa`. The owner sideloads it
  and runs the phone steps from task 11.
- `/ship` at the end runs spec-reviewer and standards-reviewer over the whole branch.
