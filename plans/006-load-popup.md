# Plan: 006 — Load popup

**For spec:** specs/006-load-popup.md
**Type:** feature
**Branch:** feat/load-popup

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
Spec 006 (approved, commit 5dcbe8e on `feat/load-popup`) makes the Load ring open a Load popup.
The popup shows time in each HR Zone, hourly bars stacked by HR Zone, Highest HR, the Max HR
used, and typical Load. On today it also shows a Live HR pill streamed from the Strap (ADR
0007). Today, tapping the ring does nothing unless it reads "Add your age". `0x28` Frames are
ignored, and nothing holds a connection between syncs.

## Approach
`SerenixCore` first, test-first at the spec's seams. The user also agreed two extra seams: spec
001's **History Sync** and a new **Live HR session**. Three hand-checked shell slices follow.
- **HR Zone** (new `src/SerenixCore/HRZone.swift`): `enum HRZone: Int, CaseIterable { one…five }`
  with `static func zone(forHeartRate:maxHR:) -> HRZone?`, using the exact share and lower edges
  0.5/0.6/0.7/0.8/0.9 (named constants, source Edwards). Never `Zone`, which is the Nightly
  Metric enum in `Zone.swift`.
- **Load of a Day** (`src/SerenixCore/Load.swift`, `load(of:records:nights:profile:in:)`): in
  the same pass, `DayLoad` (`src/SerenixCore/Day.swift`) gains optional
  `heartRate: DayHeartRate?`. Its fields are `zoneSeconds: [HRZone: Int]`,
  `hourlyZoneSeconds: [[HRZone: Int]]` (one per local hour of `Day.span(in:)`),
  `highestHR: (bpm, time)?` and `maxHRUsed: MaxHRUsed { bpm, source: .entered/.estimated }`.
  It's set whenever there are records and a Max HR (also for `.maxHRNotAboveRestingHR`), and
  nil otherwise. A nil value on a Day with a Load means "not available". The struct stays
  `Codable`. The repeats and the Day filter already in `load` are reused.
- **Typical Load** (new `src/SerenixCore/TypicalLoad.swift`):
  `typicalLoad(for day: Day, among: [DayLoad]) -> TypicalLoad` with
  `.value(Int)` / `.calibrating(soFar: Int)`. It uses the 28 Days before the Day, skips missing
  Loads and counts 0, and takes the median via `median(of:)` (`Median.swift`), rounding halves up.
- **Protocol** (`src/SerenixCore/Frame.swift`, new `src/SerenixCore/LiveHRReading.swift`):
  `FrameType.realtimeData = 0x28` and `liveHRReading(from: Frame) -> LiveHRReading?` (HR from
  `d[16]` and Strap time from `d[10:14]`, body offsets −8, via `LittleEndian.swift`).
  `Command.liveHR(on: Bool)` builds `0x03 01/00`. `Frame(bytes:)` already gives `.badCRC`.
- **Live HR session** (new `src/SerenixCore/LiveHRSession.swift`):
  - `start(at:)` sends hello (`0x91 01`, as `HistorySync` does).
  - The hello reply triggers `0x03 01`.
  - `receive(_:at:)` returns readings and Sync Log entries, and skips a bad-CRC Frame.
  - `stop(at:)` sends `0x03 00`.
  - It reuses `Command.frame(sequence:)` and `SyncLogEntry`.
- **History Sync** (`src/SerenixCore/HistorySync.swift`):
  - New `mutating func setLiveHR(_ on: Bool, at:) -> HistorySyncOutput`, which sends `0x03` with
    the next sequence number.
  - `0x03` is *not* added to `sentOps`, so a reply to it never fails the sync.
  - `HistorySyncOutput` gains `liveHRReadings`, filled from `0x28` Frames instead of
    `default: break`.
  - Bad CRC on any Frame still fails the sync (spec 001; spec 006 says nothing else changes).
- **Live HR pill** (new `src/SerenixCore/LiveHRPill.swift`):
  `liveHRPill(connection: LiveHRConnection, last: LiveHRReading?, arrivedAt: Date?, now: Date) -> LiveHRPill`,
  where the result is `.connecting`, `.bpm(Int)` or `.unavailable`, and the stale limit is a
  named 5 s constant.
- **Today view** (`src/SerenixCore/TodayView.swift`, `Popups.swift`):
  - New input `lastSyncEnded: Date?`.
  - New `loadPopup: LoadPopup?`, which is nil when `loadOpensProfileMenu` is set.
  - `LoadPopup` holds the date, Load text, "As of your last sync at HH:mm" (today only, via
    `clockText`), the typical line, five zone rows with "42m"/"1h 05m", hourly stacks, the
    Highest HR text, the Max HR used text, `showsLiveHR` (today only), and a `note` for the
    no-records or not-available text.
- **Tests:** expected values are the spec's literals. The per-bpm `records(at:for:from:)` helper
  moves from `LoadTests.swift` to `tests/SerenixCoreTests/HistoryRecordBuilder.swift`.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [ ] **Prefactor:** move `records(at:for:from:firstCounter:)` from `LoadTests.swift` into the
   shared `HistoryRecordBuilder.swift`. There is no behavior change.
   - Files: `tests/SerenixCoreTests/LoadTests.swift`, `tests/SerenixCoreTests/HistoryRecordBuilder.swift`
   - Done when: the existing suite is still green.
2. [ ] **Slice (tracer):** HR Zone and the Day's seconds in each HR Zone, plus the Max HR used,
   from Load of a Day.
   - Seam: Load of a Day · Files: `src/SerenixCore/HRZone.swift` (new), `src/SerenixCore/Load.swift`, `src/SerenixCore/Day.swift`, `tests/SerenixCoreTests/LoadTests.swift` (or new `DayHeartRateTests.swift`)
   - Done when these criteria pass:
     - An hour at 164 bpm gives 3600 s in HR Zone 4 (entered, Max HR 190).
     - The 10-minute edge list.
     - Zone seconds equal the seconds over the floor, including with repeats and order changes.
     - Birth year 1986 at 162 bpm gives HR Zone 5, estimated, Max HR 180.
     - The existing Load tests stay green.
3. [ ] **Slice:** hourly HR Zone seconds per local hour, across midnight and clock changes.
   - Seam: Load of a Day · Files: `src/SerenixCore/Load.swift`, `src/SerenixCore/Day.swift`, tests as task 2
   - Done when: the hourly criterion passes (31 Oct 23:00 and 1 Nov 00:00 hold 1800 s each; 29
     Mar has 23 hours and 25 Oct has 25), and the 164 bpm hour's bars hold HR Zone 4 only.
4. [ ] **Slice:** Highest HR and its earliest time, with HR 0 skipped.
   - Seam: Load of a Day · Files: as task 3
   - Done when: the Highest HR criterion passes (150 at 09:00; all HR 0 gives none), and so do
     Highest HR 164 and 200 in criteria 1–2.
5. [ ] **Slice:** Typical Load.
   - Blocked by: 1
   - Seam: Today view's input; Typical Load is a pure function, tested directly · Files: `src/SerenixCore/TypicalLoad.swift` (new), `tests/SerenixCoreTests/TypicalLoadTests.swift` (new)
   - Done when: the numeric part of the Typical Load criterion passes: 45; 46 with a half;
     missing skipped and 0 counted; 29 Days back not counted; 3 Days gives calibrating(3).
6. [ ] **Slice:** Protocol: decode `0x28` into a Live HR reading, and build Live HR on/off.
   - Blocked by: 1. **Needs the owner's real `0x28` capture first** (spec open question). Trim it
     into `tests/SerenixCoreTests/Fixtures/LiveHR-<date>.txt` in the existing capture format
     (`SyncCapture.swift`), with serial and device ID removed.
   - Seam: Protocol · Files: `src/SerenixCore/Frame.swift`, `src/SerenixCore/LiveHRReading.swift` (new), `tests/SerenixCoreTests/LiveHRReadingTests.swift` (new), the fixture
   - Done when: the Protocol criterion passes. Fixture Frames decode to HR and Strap time, and
     the acquiring ones to 0. A changed byte with the old CRC gives `.badCRC`. On and off match
     `whoop5.py`'s `frame(2, 0x03, 01)` and `frame(3, 0x03, 00)` bytes, committed as literals.
7. [ ] **Slice:** Live HR session, used when no sync is running.
   - Blocked by: 6
   - Seam: Live HR session (agreed with the user, not in the spec's list) · Files: `src/SerenixCore/LiveHRSession.swift` (new), `tests/SerenixCoreTests/LiveHRSessionTests.swift` (new)
   - Done when:
     - Start sends hello (bytes equal `whoop5.py`'s asserted hello).
     - The hello reply sends `0x03 01`.
     - Fixture `0x28` Frames come out as readings.
     - A bad-CRC Frame is skipped and logged.
     - Stop sends `0x03 00`.
     - Every Frame appears in its Sync Log entries.
8. [ ] **Slice:** History Sync turns Live HR on and off mid-sync and passes readings out.
   - Blocked by: 6
   - Seam: History Sync (spec 001's seam) · Files: `src/SerenixCore/HistorySync.swift`, `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when, mid-capture:
     - `setLiveHR(true)` sends `0x03 01` with the next sequence number.
     - A `0x28` Frame yields a reading and is logged.
     - A non-done reply to `0x03` doesn't fail the sync, and the sync still completes on the
       capture.
     - `setLiveHR(false)` sends `0x03 00`.
     - The existing History Sync tests stay green.
9. [ ] **Slice:** Live HR pill.
   - Blocked by: 6
   - Seam: Live HR pill · Files: `src/SerenixCore/LiveHRPill.swift` (new), `tests/SerenixCoreTests/LiveHRPillTests.swift` (new)
   - Done when the pill criterion passes:
     - "…" while connecting.
     - 72 at 4.9 s.
     - "—" at 5.0 s, for a 0 reading, and for no Strap, Bluetooth off or a failed connection.
10. [ ] **Slice:** Today view: the Load popup.
    - Blocked by: 4, 5
    - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`, `src/SerenixCore/Popups.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
    - Done when:
      - The ring opens the popup for Load 57 and for no records, and opens the profile menu for
        `.noMaxHR`.
      - The pill and "As of your last sync at 08:12" show on today only.
      - The no-records and not-available notes show.
      - "42m" and "1h 05m".
      - The typical line's text: "Typical: 45 · today +45", "that Day", "−", "±0", and just
        "Typical: 45" with a missing Load.
11. [ ] **Slice (shell):** store a Day's heart rate with its Load, and queue every due Day once
    after the update.
    - `StoredDayLoad` gains an optional encoded `heartRate` field (lightweight migration).
    - A new UserDefaults key (e.g. `heartRateZonesBackfilled`) queues `dayRebuildsDue` once and
      runs `rebuildNights()`.
    - `TodayScreen` passes `connection.lastSyncCompleted` as `lastSyncEnded`.
    - Blocked by: 10
    - Seam: shell (by hand, ADR 0002) · Files: `src/SerenixApp/DayLoadStore.swift`, `src/SerenixApp/StrapConnection.swift`, `src/SerenixApp/TodayScreen.swift`
    - Done when: the macOS CI job builds, and the "after the update" manual criterion is listed
      with steps for the PR.
12. [ ] **Slice (shell):** the Load popup view, and the ring opening it.
    - `TodayPopup.load` and a `LoadPopupView` in `TodayPopups.swift`, with Charts stacked hourly
      bars and zone rows.
    - The ring Button opens `.load` unless `loadOpensProfileMenu`.
    - Blocked by: 11
    - Seam: shell (by hand) · Files: `src/SerenixApp/TodayPopups.swift`, `src/SerenixApp/TodayScreen.swift`
    - Done when: CI builds, and the "tapping the Load ring" manual criterion is listed for the PR.
13. [ ] **Slice (shell):** the Live HR connection and pill.
    - Starting and stopping:
      - `StrapConnection` gains `startLiveHR()` and `stopLiveHR()`.
      - With no sync running, `startLiveHR()` connects (via `rememberedStrap`) and runs a
        `LiveHRSession`.
      - During a sync, it calls `session.setLiveHR`.
      - Stopping disconnects only outside a sync.
    - The popup's appear and disappear and `sceneWentToBackground` / `sceneBecameActive` drive it.
    - It publishes the last reading, its arrival time and the connection state for `liveHRPill`.
      A 1-second timer re-evaluates staleness.
    - `SyncLogArchive` keeps one `livehr.txt`, excluded from the 5-sync prune and included in
      `writeCombined`.
    - Blocked by: 7, 8, 9, 12
    - Seam: shell (by hand) · Files: `src/SerenixApp/StrapConnection.swift`, `src/SerenixApp/SyncLogArchive.swift`, `src/SerenixApp/TodayPopups.swift`, `src/SerenixApp/SerenixApp.swift`
    - Done when: CI builds, and the Live HR manual criteria (pill, off-wrist and out of range,
      during a sync, leaving and coming back, the shared log) are listed with steps for the PR.
14. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
    and `swift build` are green. The macOS CI job builds. Every spec 006 criterion is checked,
    with the manual ones done on the phone.
    - Blocked by: 13

## Notes
- Task 6 (and so 7–9 and 13) waits on the owner's `0x28` capture from `whoop5.py`, including the
  first seconds at HR 0. Tasks 1–5 and 10–12 don't need it.
- Agreed seams beyond the spec's list (user, 2026-11-01): Live HR session (new) and History Sync
  (spec 001). The spec doesn't change.
- A bad CRC during a sync still fails the sync (spec 001). Outside a sync, the Live HR session
  skips it.
- The shell can't build on Windows; tasks 11–13 rely on the macOS CI job.

## Done when
- All tasks checked, every success criterion in spec 006 met, suite green.
