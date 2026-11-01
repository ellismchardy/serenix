# Plan: 002 — Today screen

**For spec:** specs/002-today-screen.md
**Type:** feature
**Branch:** feat/home-screen

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
Build the Today view in `SerenixCore` as one pure function, one behaviour at a time, each test
going through it (the spec's only seam). Its inputs are plain value types: `Night` (every field
optional: Nightly Metrics, Time Asleep, Sleep Onset, Final Wake, Time in Bed, Sleep Score,
Readiness), `DayLoad` (Day + optional Load), the Day to show, the current time and time zone, and
a `SyncStatus` the shell maps 001's `StrapPhase` onto. Baseline and Zone are their own small
types in `SerenixCore` that the Today view calls, but they are tested only through the Today
view. Each slice also draws its part in the shell, so the CI macOS build checks it compiles and
the phone checks run as each piece lands. The first slice replaces 001's `MainView` with the
Today screen and keeps 001's Connect/Sync/Cancel behaviour behind the sync pill; the profile menu
replaces `SettingsView` near the end.

Nothing computes Nights or Load yet (each is its own spec), so the shell feeds the Today view an
empty list and the screen shows "No Night yet" until those specs land. To check the filled-in
screen on the phone before then, task 8 adds a "Show sample Nights" switch to the Debug screen
(agreed in plan review). CI builds Release, so the switch is in every build. It is off by
default, isn't saved, and only swaps the Today view's input for a fixed set of hand-built Nights
and Loads; nothing is written to the store. It is a test aid outside the spec's product
behaviour, the one addition to 001's otherwise unchanged Debug screen.

Assumptions (consistent with the spec, stated so review can check them):
- Readiness is Calibrating while HRV's or Resting HR's Baseline is Calibrating; "n/4" counts the
  Nights up to and including the one shown, and "N to go" is 4 − n.
- The pill's other 001 phases map onto the four spec states: searching → "Connecting…",
  Bluetooth unavailable → "Sync failed" with 001's reason, idle/connected → "Synced HH:mm" from
  the last finished sync (or "Not synced" if there has never been one).

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice (tracer):** Which Day is shown, the header and arrows, "No Night yet / recorded",
   Load and its label, and the sync pill; the shell's Today screen replaces `MainView`.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`, `src/SerenixCore/Night.swift`,
     `src/SerenixCore/SyncStatus.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`,
     `src/SerenixApp/TodayScreen.swift` (new), `src/SerenixApp/MainView.swift` (removed),
     `src/SerenixApp/SerenixApp.swift`, `src/SerenixApp/StrapConnection.swift` (map `StrapPhase`
     to `SyncStatus` only)
   - Done when: the 30 Oct / 31 Oct / 1 Nov arrows criterion, the "No Night yet" criterion, the
     "Load so far" criterion, the missing-Load "—" part, and the sync pill criterion pass.
2. [x] **Slice:** Rings: Readiness number and band (Ready / Steady / Take it easy), Sleep Score,
   missing scores as "—"; shell draws the three rings.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`, `src/SerenixApp/TodayScreen.swift`,
     `src/SerenixApp/ScoreRing.swift` (new)
   - Done when: the 67/66/34/33 band criterion and the missing-score part of the "—" criterion
     pass.
3. [x] **Slice:** Baseline, shown through the HRV tile: median of up to 14 earlier Nights with a
   value, Night shown excluded, Calibrating below 3, missing values skipped; Readiness ring
   Calibrating "n/4"; shell draws the tile grid with the HRV tile.
   - Seam: Today view · Files: `src/SerenixCore/Baseline.swift` (new),
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`,
     `src/SerenixApp/TodayScreen.swift`, `src/SerenixApp/MetricTile.swift` (new)
   - Done when: the median (59 / 60), 14-Night, own-Night-excluded, earlier-Night, 2-vs-3
     Calibrating and missing-skipped criteria pass.
4. [ ] **Slice:** Zones and the other tiles: Resting HR, respiratory rate, skin temperature and
   SpO2 tiles with Zone and difference text; Time Asleep tile; 7-Night trend lines; the "Last
   night" / date heading.
   - Seam: Today view · Files: `src/SerenixCore/Zone.swift` (new),
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`,
     `src/SerenixApp/TodayScreen.swift`, `src/SerenixApp/MetricTile.swift`
   - Done when: every Zone boundary criterion (HRV, Resting HR, respiratory rate, skin
     temperature, SpO2), the difference-format criterion, the trend-line criterion and the
     missing-metric / missing-Time Asleep "—" parts pass.
5. [ ] **Slice:** vs your Baseline: HRV and Resting HR with value, difference and direction
   (good way / bad way), or the single Calibrating line with "N to go"; shell draws the bars.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`, `src/SerenixApp/TodayScreen.swift`
   - Done when: the vs your Baseline Calibrating criterion passes, and a test shows +14% HRV and
     −3 bpm Resting HR both marked the good way.
6. [ ] **Slice:** Popups: Readiness (with Calibrating text), Sleep (minutes awake) and Nightly
   Metric (up to 14 Nights, 5 most recent, Baseline and In range limits, none for SpO2); shell
   sheets opened from the rings and tiles, Load ring inert.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`, `src/SerenixApp/TodayScreen.swift`,
     `src/SerenixApp/TodayPopups.swift` (new)
   - Done when: the Sleep popup minutes-awake criterion and the Nightly Metric popup criterion
     pass, plus a test of the Readiness popup's "Baseline: your last N Nights" and Calibrating
     content.
7. [ ] **Slice (shell only, ADR 0002):** Profile menu replaces `SettingsView`: Strap model,
   connection, battery and last sync; Sync now / Retry sync; Debug opens 001's debug screen;
   footer with version, "MIT licensed", "Not affiliated with WHOOP, Inc."; Done closes it.
   - Seam: none (manual on the phone) · Files: `src/SerenixApp/ProfileMenu.swift` (new),
     `src/SerenixApp/SettingsView.swift` (removed), `src/SerenixApp/TodayScreen.swift`
   - Done when: `swift build` and the CI macOS job are green, and the profile-menu manual steps
     are written into the PR checklist.
8. [ ] **Slice (shell only, test aid):** "Show sample Nights" switch on the Debug screen. When on,
   the Today screen is fed about 20 hand-built Nights and Days ending today. They cover every
   band, every Zone, a Calibrating stretch at the start, a Day with no Night, and a Night
   missing SpO2. When off, it goes back to the real (empty) input. Off at launch, not saved,
   nothing written to SwiftData.
   - Seam: none (manual on the phone) · Files: `src/SerenixApp/SampleNights.swift` (new),
     `src/SerenixApp/DebugView.swift`, `src/SerenixApp/TodayScreen.swift`,
     `src/SerenixApp/StrapConnection.swift` (or wherever the Today input lives)
   - Done when: `swift build` and the CI macOS job are green. The manual steps are in the PR
     checklist: turn the switch on, step through the sample Days, open each popup and check
     the spec's manual criteria, then turn it off and see "No Night yet" again.
9. [ ] **Verify:** full suite + lint + typecheck green, CI macOS build green; every automated
   success criterion in the spec ticked; the manual phone steps (including 001's and the sample
   Nights walk-through) listed for the PR.
   - Blocked by: 8

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
