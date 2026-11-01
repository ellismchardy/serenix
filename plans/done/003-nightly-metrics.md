# Plan: 003 — Nightly Metrics

**For spec:** specs/003-nightly-metrics.md
**Type:** feature
**Branch:** feat/nightly-metrics

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
History Sync stores History Records on the phone, and the Today screen can show every Night
value, but nothing turns one into the other, so the app only shows sample Nights behind a Debug
switch. Spec 003 ports hr-tracker's `tools/sleep.py` (Sleep Period) and `tools/metrics.py` (five
Nightly Metrics) into `SerenixCore` unchanged, rebuilds Nights after each sync, and removes the
sample Nights.

## Approach
One public `SerenixCore` entry point, **Nights from History Records**: `nights(from: [HistoryRecord],
in: TimeZone) -> [Night]`, plus (from task 7) **Night rebuilds**, which tells the shell which
dates to work out again after a sync and which History Records to read for each. Inside: per-minute table → wake/sleep labels → Sleep
Period → Time in Bed, then one pure function per Nightly Metric, each constant named with its
unit and its hr-tracker source. Quirks are kept (minute means include HR 0, Resting HR steps by
records, skin temperature includes warm-up). Every test goes through the entry point (the spec's
only seam).

**Fixture.** A new `scripts/make-night-fixture.py` turns hr-tracker's history CSVs (decoded from
the 30 Oct sysdiagnose `.pklg` files with `hr-tracker/tools/history.py`, already verified to give
the protocol doc's numbers) into `tests/SerenixCoreTests/Fixtures/Night-2026-10-30.csv`: one row per
History Record with only the fields the methods read (counter, UTC, HR, RR, motion q0–q3, skin
temperature, SpO2 Window, SpO2). The CSV has no serial or device ID; the script asserts none of
the capture's identifiers appear. Expected values are hr-tracker's **unrounded** output, committed
as literals; the script prints them. A test helper loads the CSV via `Bundle.module`, like
`SyncCapture` (`tests/SerenixCoreTests/SyncCapture.swift`). The motion floats map one to one: the
decoder's `motionOffset` 33 is hr-tracker's `d[41:57]`, and `sleep.py` only uses `|q₁·q₂|` of
normalised vectors, so the order doesn't matter as long as it's consistent. Tolerances follow
the repo's `abs(x - expected) < tol` pattern.

**Shell.** Nights are stored in SwiftData (`StoredNight`, keyed by its night window). After a
completed sync the shell takes the night windows the sync's records fall in, **plus each one's
neighbours**, fetches their records, calls the entry point, and replaces the stored Nights of
those windows with what comes back. Including neighbours means two windows that give the same
date are always worked out in one call, so the "more Time Asleep wins" rule lives only in
`SerenixCore`. The Today screen reads stored Nights.

Assumptions (consistent with the spec, stated for review):
- `HistoryRecord` gets a public memberwise init (tests and the store both need to build one; no
  behaviour change).
- The 30-day pruning of History Records isn't implemented yet (spec 001 never built it); this
  plan doesn't add it. Nights rebuild from whatever records are stored.
- The rebuild runs on a background context after the sync completes (hooked in
  `StrapConnection.handle` at `.completed`, same `Task.detached` pattern as `refreshStoreStats()`),
  so the pill shows "Synced" first and Nights appear moments later. `StoredNight` is added to the
  `ModelContainer` schema in `HistoryRecordStore`.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Prefactor:** public memberwise `HistoryRecord` init; no behaviour change.
   - Files: `src/SerenixCore/HistoryRecord.swift`
   - Done when: existing suite still green.
2. [x] **Slice (tracer):** fixture + Sleep Period: the 29–30 Oct night gives one Night dated
   30 Oct with Sleep Onset 21:05, Final Wake 03:42, Time in Bed 20:57–04:00, Time Asleep 5h52.
   Per-minute table, wake rule with HR cross-check, runs ≥ 7, merge < 60 min across recorded wake
   only, most-sleep period wins, Time in Bed widening, noon-to-noon windows, dating by Final Wake.
   - Seam: Nights from History Records · Files: `src/SerenixCore/Nights.swift` (new),
     `src/SerenixCore/SleepPeriod.swift` (new), `tests/SerenixCoreTests/NightsTests.swift` (new),
     `tests/SerenixCoreTests/NightFixture.swift` (new loader),
     `tests/SerenixCoreTests/Fixtures/Night-2026-10-30.csv` (new), `scripts/make-night-fixture.py` (new)
   - Done when: the first success criterion passes.
3. [x] **Slice:** Resting HR, HRV and skin temperature over the Sleep Period's records with HR > 0.
   - Seam: Nights from History Records · Files: `src/SerenixCore/NightlyMetrics.swift` (new),
     `src/SerenixCore/Nights.swift`, `tests/SerenixCoreTests/NightsTests.swift`
   - Done when: those three values match hr-tracker within ±0.05 (part of criterion 2).
4. [x] **Slice:** Respiratory rate: 5-minute windows with ≥ 200 kept RR, 4 Hz linear resample,
   Hann window, strongest bin in 0.12–0.4 Hz, mean of windows.
   - Seam: Nights from History Records · Files: `src/SerenixCore/NightlyMetrics.swift`,
     `tests/SerenixCoreTests/NightsTests.swift`
   - Done when: respiratory rate matches within ±0.05 (part of criterion 2).
5. [x] **Slice:** SpO2 (windows split by gaps > 5 s, median of 85–100 readings, mean of windows)
   and missing metrics: no SpO2 Window → SpO2 missing, others unchanged; no RR → HRV and
   respiratory rate missing, others unchanged; Resting HR missing under 30 minutes.
   - Seam: Nights from History Records · Files: `src/SerenixCore/NightlyMetrics.swift`,
     `src/SerenixCore/Nights.swift`, `tests/SerenixCoreTests/NightsTests.swift`
   - Done when: criterion 2 fully, and the SpO2-removed and RR-removed criteria pass.
6. [x] **Slice:** windows and edge cases with hand-built records (a small test helper that makes
   still or moving minutes): shuffled and duplicated records give the same Night; two windows give
   one Night each; two windows with one date keep the one with more Time Asleep; longest run 6 →
   no Night, 7 → Night; empty or sparse window → no Night; 59 vs 60 minutes of wake → one vs two
   Sleep Periods; a Sleep Period with under 30 minutes of records has Resting HR missing (moved
   from task 5, which had no short Sleep Period to test it with).
   - Seam: Nights from History Records · Files: `src/SerenixCore/Nights.swift`,
     `src/SerenixCore/SleepPeriod.swift`, `tests/SerenixCoreTests/NightsTests.swift`,
     `tests/SerenixCoreTests/HistoryRecordBuilder.swift` (new helper)
   - Done when: criteria 3–7 and 10 pass, and the short-Sleep-Period Resting HR test passes.
7. [x] **Slice (shell + Night rebuilds):** `StoredNight` in SwiftData; after a sync, rebuild the
   dates its History Records touched, one at a time, and replace their Nights; Today screen reads
   stored Nights; remove `SampleNights` and Debug's "Show sample Nights" switch. Changed in review
   (agreed with the user): which dates to rebuild and which History Records to read for each is
   logic, so it is a second public `SerenixCore` seam, **Night rebuilds**
   (`nightRebuilds(after: [Date], now: Date, in: TimeZone) -> [NightRebuild]`), test-first. Each
   date reads only the two night windows that can give it (memory stays at two windows), dates
   whose windows start more than 30 days before now (History Records kept 30 days) or after now
   are skipped, and dates still to do are kept on the phone and resumed at launch.
   - Seam: Night rebuilds (`SerenixCore`); the rest is checked by hand on the phone (ADR 0002) ·
     Files: `src/SerenixCore/Nights.swift`, `src/SerenixCore/NightRebuild.swift` (new),
     `tests/SerenixCoreTests/NightRebuildTests.swift` (new), `src/SerenixApp/NightStore.swift`
     (new), `src/SerenixApp/HistoryRecordStore.swift` (model container),
     `src/SerenixApp/StrapConnection.swift`, `src/SerenixApp/TodayScreen.swift`,
     `src/SerenixApp/DebugView.swift`, `src/SerenixApp/ProfileMenu.swift`,
     `src/SerenixApp/SampleNights.swift` (removed)
   - Done when: the Night rebuilds tests pass; macOS CI builds the app; the PR lists the phone
     steps for the three by-hand criteria, including syncing twice in one morning.
8. [x] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
   `swift build` green; CI green; every spec success criterion checked, the by-hand ones on the
   phone.

## Verification
- Windows: `swift test` (all Nights tests against the fixture literals), lint, build.
- CI: the Linux job and the macOS `.ipa` build.
- Phone (Sideloadly): morning sync shows last night's Time Asleep, Sleep Onset → Final Wake and
  five Nightly Metrics; compare with `hr-tracker/tools/metrics.py` on that night's Sync Log; a
  second sync leaves the Night unchanged; Debug has no sample switch; a Day without a Night shows
  "No Night recorded".
