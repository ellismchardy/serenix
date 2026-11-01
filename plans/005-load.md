# Plan: 005 — Load

**For spec:** specs/005-load.md
**Type:** feature
**Branch:** feat/load

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
The Today screen's Load ring always shows "—": nothing works out Load, and the Profile has no
age or Max HR to work it from. Spec 005 adds per-second Banister TRIMP over each Day, scaled
0–100, worked out on the phone after each sync, plus optional birth year, sex and Max HR in the
Profile. It also adds an "Add your age" ring label and retunes the Readiness advice Load
constants to 55/50/33. Readiness (the next spec) reads the stored Day Loads.

## Approach
Four `SerenixCore` seams from the spec, each built test-first, then two hand-checked shell slices.
- **Profile** (`src/SerenixCore/Profile.swift`): gains `birthYear: Int?`, `sex: Sex` (`.female`,
  `.male`, `.preferNotToSay`, default) and `maxHR: Int?`. It also gets range checks (Max HR
  100–230; birth year 100 to 13 years before a given year) and
  `estimatedMaxHR(in year:) -> Double?` (Tanaka, unrounded as the spec's formula; nil for a birth year outside the range). Today it's an internal struct built from
  the name only. It becomes public where Load and the shell need it, and keeps `init(name:)`
  working.
- **Load of a Day** (new `src/SerenixCore/Load.swift`):
  `load(of day: Day, records: [HistoryRecord], nights: [Night], profile: Profile, in: TimeZone) -> DayLoad`.
  Inside it, these are separate pure functions: the records in the Day (deduplicated by
  `HistoryRecord.identity`, as in `nights(from:in:)` in `Nights.swift`), the Resting HR median
  (reusing `median(of:)` in `Median.swift`), the Max HR, the TRIMP sum and the scale. Named
  constants carry their unit and source (issue 16): floor 0.5, fallback 60 bpm, k/b per sex,
  14 Nights.
- **`DayLoad`** (`src/SerenixCore/Day.swift`) gains `missingReason: LoadMissing?`
  (`.noRecords`, `.noMaxHR`, `.maxHRNotAboveRestingHR`), so `load` stays `Int?`. It becomes
  `Codable` for the shell's storage.
- **Day rebuilds** (new `src/SerenixCore/DayRebuild.swift`, next to `NightRebuild.swift`):
  `DayRebuild { day, records: DateInterval; isDue(at:) }`. Two functions:
  `dayRebuilds(after recordTimes:, now:, in:)` and `dayRebuildsDue(now:, in:)` (every Day still
  due, for Profile changes). It shares `historyRecordRetention` with Night rebuilds, which moves
  from `private` to file-internal in `NightRebuild.swift`.
- **Today view** (`src/SerenixCore/TodayView.swift`): reads `DayLoad.missingReason`. With
  `.noMaxHR`, `loadLabel` is "Add your age" and a new `loadOpensProfileMenu: Bool` is true.
- Expected values are the literals in the spec's success criteria, worked by hand from its
  formula. Records are built one per second at a given heart rate by a helper in
  `LoadTests.swift` (the shared `HistoryRecordBuilder.swift` fixes heart rate at 55 bpm).

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice:** Profile gains birth year, sex and Max HR, with their ranges and the Max HR
   estimate.
   - Seam: Profile · Files: `src/SerenixCore/Profile.swift`, `tests/SerenixCoreTests/ProfileTests.swift` (new)
   - Done when: the spec's Profile criterion passes (Max HR 100–230, birth year 100 to 13 years
     back, the estimate for 1986 in 2026 is 180); the existing Today view tests stay green.
2. [x] **Slice (tracer):** Load of a Day with an entered Max HR and no Nights (60 bpm): the
   per-second sum, the floor, the cap at Max HR, the clamp at Resting HR, the sex constants, the
   scale and rounding, HR 0, repeats and order, and missing for no records vs 0.
   - Seam: Load of a Day · Files: `src/SerenixCore/Load.swift` (new), `src/SerenixCore/Day.swift` (`DayLoad.missingReason`), `tests/SerenixCoreTests/LoadTests.swift` (new)
   - Done when: these criteria pass: 164 bpm gives 57/58/57 by sex; 33 and 43; 0 and 33 at the
     floor; 200 = 190 = 64; 24 h = 100; HR 0, repeats and order give 57; no records means missing,
     and records under the floor give 0.
3. [ ] **Slice:** Day boundaries: only records in the Day's local midnight-to-midnight count,
   including across a clock change.
   - Seam: Load of a Day · Files: `src/SerenixCore/Load.swift`, `tests/SerenixCoreTests/LoadTests.swift`
   - Done when: 23:30–00:30 gives 49 for each Day; 29 Mar 2026 runs 00:00 to 23:00 UTC.
4. [ ] **Slice:** Max HR from age, an entered Max HR winning over it, and the missing reasons
   `.noMaxHR` and `.maxHRNotAboveRestingHR`.
   - Seam: Load of a Day · Files: `src/SerenixCore/Load.swift`, `tests/SerenixCoreTests/LoadTests.swift`
   - Done when: birth year 1986 at 154 bpm gives 56; no birth year means missing for no Max HR;
     Max HR 190 with 1986 gives 57; Max HR 100 with Resting HR 100 means missing.
5. [ ] **Slice:** Resting HR as the median of up to 14 Nights dated on or before the Day,
   skipping Nights without one.
   - Seam: Load of a Day · Files: `src/SerenixCore/Load.swift`, `tests/SerenixCoreTests/LoadTests.swift`
   - Done when: both Resting HR criteria pass (45; the later Night is ignored; 41; 43 with 15
     Nights; a missing Resting HR is skipped); the Resting HR 100 / 96 bpm criterion gives 0.
6. [ ] **Slice:** Day rebuilds after a sync, and every Day still due for a Profile change.
   - Blocked by: (none; it's independent of 1–5)
   - Seam: Day rebuilds · Files: `src/SerenixCore/DayRebuild.swift` (new), `src/SerenixCore/NightRebuild.swift` (retention constant visibility only), `tests/SerenixCoreTests/DayRebuildTests.swift` (new)
   - Done when: both Day rebuild criteria pass.
7. [ ] **Slice:** Readiness advice Load constants become 55/50/33.
   - Blocked by: (none)
   - Seam: Today view · Files: `src/SerenixCore/ReadinessAdvice.swift`, `tests/SerenixCoreTests/TodayViewTests.swift` (rewrite the 002 advice test's 60/30/69 expectations to the new values; that follows the changed spec 002 criterion)
   - Done when: the spec 005 advice criterion and spec 002's unticked advice criterion pass.
8. [ ] **Slice:** Today view: "Add your age" and the ring tap flag for a Load missing for lack
   of Max HR; the normal label otherwise.
   - Blocked by: 4, 7
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: the spec's Today view criterion passes.
9. [ ] **Slice (shell):** store a Load per Day and work Days out after each sync's Nights.
   - A `StoredDayLoad` SwiftData model keyed by date, in `NightStore.swift` or a new `DayLoadStore.swift`, added to the `ModelContainer` schema in `HistoryRecordStore`.
   - A pending `DayRebuild` queue in UserDefaults, like `NightStore.pendingRebuilds`.
   - `StrapConnection`: `queueNightRebuilds` also queues Day rebuilds, and `rebuildNights()` works out queued Days after the Nights, one at a time off the main thread, reading the Day's records plus the stored Nights and the Profile.
   - `TodayScreen` passes the stored Day Loads in place of `dayLoads: []`.
   - Blocked by: 5, 6, 8
   - Seam: none in `SerenixCore` (shell, checked by hand per ADR 0002) · Files: `src/SerenixApp/NightStore.swift` or `DayLoadStore.swift` (new), `src/SerenixApp/HistoryRecordStore.swift`, `src/SerenixApp/StrapConnection.swift`, `src/SerenixApp/TodayScreen.swift`
   - Done when: the macOS CI job builds; the first manual criterion (Load ring after a morning sync) is listed with its steps for the PR.
10. [ ] **Slice (shell):** Profile rows and the ring tap.
    - `ProfileStore` keeps birth year, sex and Max HR in UserDefaults.
    - `ProfileMenu` adds the Birth year picker, the Sex choice with its hint, and the Max HR field with "Estimated N from your age".
    - A change queues `dayRebuildsDue` and runs the rebuild.
    - The Load ring opens the profile menu when `loadOpensProfileMenu` is true.
    - None of these fields is ever logged.
    - Seam: shell (by hand) · Files: `src/SerenixApp/ProfileStore.swift`, `src/SerenixApp/ProfileMenu.swift`, `src/SerenixApp/TodayScreen.swift`, `src/SerenixApp/StrapConnection.swift`
    - Done when: the macOS CI job builds; the remaining manual criteria (Add your age, the rows surviving a relaunch, no Profile fields in a shared Sync Log) are listed with steps for the PR.
11. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
    and `swift build` are green, the macOS CI job builds, and every spec 005 criterion (plus
    spec 002's advice criterion) is checked; the manual ones are done on the phone.
    - Blocked by: 10

## Notes
- `/execute` switches to the existing `feat/load` branch. The spec commit is already on it.
  `feat/load` was cut before PR 22 (spec 004, Baseline Spread and Zones) merged. Before task 1,
  bring it up to date with `main` (`sync_with_base_branch`). 004 touches `Baseline`, `Zone`,
  `TodayView` and `TodayViewTests`, which tasks 7–8 also edit. Spec 005 doesn't depend on
  anything in 004.
- 30-day pruning of History Records still isn't built (spec 003's plan noted this). The 30-day
  rule only limits which Days are queued.
- The shell's new `Profile` fields go through the `Profile` value. `ProfileStore` stays the
  only place they're kept.

## Done when
- All tasks checked, every success criterion in spec 005 met, suite green.
