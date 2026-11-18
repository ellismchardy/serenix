# Plan: 019 — Sleep accuracy harness

**For spec:** specs/019-sleep-accuracy-harness.md
**Type:** feature
**Branch:** feat/sleep-accuracy-harness

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).

## Context
Serenix's sleep/wake labelling (spec 003) was ported from hr-tracker with constants set by eye,
and nobody knows how well it finds wake. The sleep accuracy map (#78) needs a measuring stick
before any rule changes. Spec 019 builds it: a public labeller seam in `SerenixCore`, a
`SleepAccuracy` library that scores the labeller against Walch's PSG Reference Nights and
compares Tilt with the quaternion turn on the owner's nights, and a thin `sleep-accuracy` CLI.
The app's Nights must not change.

## Approach
**Prefactor-as-slice first.** `SleepPeriod` (`src/SerenixCore/SleepPeriod.swift`) today builds
its minute table straight from History Records, computing active seconds in
`MotionMinutes.activeSeconds(in:)` (`src/SerenixCore/MotionMinutes.swift`) from the quaternion
`turn`. Task 1 moves the minute table onto a per-second input (UTC time, optional heart rate,
optional angle) and makes the active test "angle > threshold"; `SleepPeriod.init(records:)`
builds that input with the existing quaternion `turn` (angle empty unless the record before is
>0 and ≤ `longestActiveGap` s earlier — the current rule) and labels at 2°. Heart rate 0 stays a
value, so minute means keep including it, as now. Everything after the minute table
(`labelled`, `mainPeriod`, `timeInBed`, `WakeBout.bouts`) is reused unchanged. The new public
API exposes per-minute labels (start + sleep/wake/no-data) and the optional Sleep Period (Sleep
Onset, Final Wake, Time in Bed, minute labels, Wake Bouts). `RestingHR` keeps using
`MotionMinutes.minuteIndex`/`fewestRecordsPerMinute` untouched.

**Harness library.** New targets in `Package.swift`: `SleepAccuracy` (library, Foundation +
`SerenixCore`, `src/SleepAccuracy`), `SleepAccuracyTests` (`tests/SleepAccuracyTests`),
`sleep-accuracy` (executable, `src/sleep-accuracy`). `project.yml` only links the `SerenixCore`
product, so the iOS build is unaffected; `Process` (for git) lives only in the executable.
Types: `Epoch` label (wake/N1/N2/N3/REM/unscored), `ReferenceNight` (id, labelling input, PSG
time 0 as a `Date` on a whole UTC minute, Epoch labels), a scorer producing a `Codable` report
value, Markdown rendering from that value (so Markdown and JSON hold the same numbers by
construction).

**Walch file format.** Checked on PhysioNet (sleep-accel 1.0.0, open access, ODC-By 1.0):
`motion/<id>_acceleration.txt` (time, x, y, z in g), `heart_rate/<id>_heartrate.txt` (time,
bpm), `labels/<id>_labeled_sleep.txt` (time, stage), times in seconds from PSG start, codes
0 wake, 1 N1, 2 N2, 3 N3, 5 REM (4 undefined → N3 per spec; −1 unscored). The separator isn't
documented, so the adapter splits on commas and whitespace alike — this settles the spec's
open question without a download; the by-hand run confirms it.

**Test inputs.** Made-up files written to a temp directory inside each Walch test; hand-built
labelling inputs and quaternions elsewhere; the existing `NightFixture` (tests only) for the
fixture-night equivalence in `SerenixCoreTests`. Expected values are the spec's literals.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice: public labeller seam, app routed through it.**
   - Seam: labeller seam + History Records → Night (spec 003's tests) · Files:
     `src/SerenixCore/SleepPeriod.swift`, `src/SerenixCore/MotionMinutes.swift`, new
     `src/SerenixCore/SleepLabelling.swift`, new `tests/SerenixCoreTests/SleepLabellingTests.swift`
   - Done when: angle 2.0° → all sleep at 2°, all wake at 1.9°; empty angle never active; 29
     seconds = no data, 30 = data; the 29–30 Oct fixture night via the input (quaternion turn,
     2°) matches spec 003's Sleep Onset/Final Wake/Time in Bed/Time Asleep literals; every
     existing `SerenixCoreTests` test passes unedited.
2. [x] **Slice: Tilt from quaternion.** Public `StrapMotion.tilt(from:to:)` beside a now-public
   `turn`: the vertical (0,0,1) seen in the Strap's frame (Rᵀ·z, i.e. assuming the quaternion
   takes the Strap's frame to the world's; floats in (x, y, z, w) order) at each reading, angle
   between the two vectors. Also `MotionAngle` and `SleepWakeLabeller.input(from:angle:)`, so
   the Strap transfer run (task 8) gets the same gap rule for both series.
   - Seam: labeller seam (`SerenixCore`) · Files: `src/SerenixCore/MotionMinutes.swift`, new
     `src/SerenixCore/StrapMotion.swift`, `src/SerenixCore/SleepLabelling.swift`,
     `tests/SerenixCoreTests/StrapMotionTests.swift`
   - Done when: 30° about the vertical → Tilt 0°, turn 30°; 30° about a horizontal axis → Tilt 30°.
3. [x] **Slice (tracer bullet): scorer, visible verdict, one Reference Night.** Add the three
   targets; `Epoch`, `ReferenceNight`, compare at Epochs (minute label → both Epochs),
   sensitivity, specificity, accuracy, κ; a stub `sleep-accuracy` main that prints usage.
   - Blocked by: 1
   - Seam: harness library · Files: `Package.swift`, `src/SleepAccuracy/*`,
     `src/sleep-accuracy/main.swift`, `tests/SleepAccuracyTests/ScorerTests.swift`
   - Done when: the 4-Epoch example gives 0.667 / 1.000 / 0.750 / κ 0.500; a sleep minute counts
     sleep for both Epochs.
4. [x] **Slice: what is compared, and both layers.** Unscored and no-data Epochs skipped; 90%
   coverage rule with the left-out list; raw-label layer; no Sleep Period → all wake.
   Note from task 3: `Scorer` already skips unscored Epochs and already scores a Reference Night
   without a Sleep Period all wake, so those two tests start green. Show them red by temporarily
   breaking the rule, and replace task 3's "no-data minute counts as wake" fallback.
   - Seam: harness library · Files: `src/SleepAccuracy/Scorer*.swift`, `tests/SleepAccuracyTests/ScorerTests.swift`
   - Done when: the spec's exclusion, 89%/90%, raw-vs-visible and no-Sleep-Period criteria pass.
5. [x] **Slice: per-night errors and pooling.** PSG Sleep Onset/Final Wake/Wake Bouts/Time
   Asleep; Time Asleep, WASO, Sleep Onset, Final Wake biases; Wake Bout count/mean length side
   by side; pooled Epoch stats per layer; Bland–Altman; means skipping empty errors.
   - Seam: harness library · Files: as task 4
   - Done when: the PSG Epoch 2–9 example (60 s / 300 s / 2 bouts of 0.5 min / 3.0 min) and the
     ±10 min → mean 0.0, SD 14.1, limits ±27.7 criteria pass.
6. [x] **Slice: Walch adapter.** Read the three files (comma or whitespace separated), sort and
   de-duplicate samples, per-second axis medians → gravity direction → Tilt (empty when the
   previous second has no samples), HR carried ≤ 15 s, label mapping, PSG time 0 at a whole UTC
   minute, seconds before 0 kept; missing file or off-grid label time → error naming the recording.
   - Blocked by: 3
   - Seam: harness library (adapter) · Files: `src/SleepAccuracy/WalchAdapter.swift`,
     `tests/SleepAccuracyTests/WalchAdapterTests.swift`
   - Done when: every Walch-adapter criterion in the spec passes.
7. [x] **Slice: sweep and reports.** Threshold sweep (best = highest pooled κ, lower threshold on
   a tie, full report for it); stamped report value (labeller, thresholds, dataset, command
   line, git SHA passed in); JSON encoding; Markdown with headline, both pooled tables,
   per-Reference-Night table, sweep table, "Reference Nights left out".
   - Blocked by: 5
   - Seam: harness library · Files: `src/SleepAccuracy/Sweep.swift`, `src/SleepAccuracy/Report*.swift`,
     `tests/SleepAccuracyTests/ReportTests.swift`
   - Done when: the sweep criterion and the two report-content criteria pass.
   - Note from task 5: `EpochAgreement` stores its four counts and computes the rates, so its
     synthesized `Codable` writes counts only. The JSON must also carry sensitivity,
     specificity, accuracy and κ (custom `encode(to:)` or a report type). Pooled scores also
     have `wakeBoutCountError` (not in the spec's list) and no pooled mean Wake Bout length:
     decide what the report shows.
8. [x] **Slice: Strap transfer run.** Fixture-CSV reader in the library (same header as
   `NightFixture`); per night two inputs (turn, Tilt), share of turn-active seconds also
   Tilt-active, minute agreement at ≥ 10 active seconds, Time Asleep/Sleep Onset/Final Wake
   from each and differences; its own Markdown/JSON section.
   - Blocked by: 2, 7
   - Seam: harness library · Files: `src/SleepAccuracy/StrapTransferReport.swift`,
     `src/SleepAccuracy/HistoryRecordCSV.swift`, `src/SleepAccuracy/MarkdownCells.swift` (report
     number formats shared with task 7), `tests/SleepAccuracyTests/StrapTransferTests.swift`
   - Left for later (outside this plan's files): the transfer run copies spec 003's 30-second
     and 10-second minute rules as its own constants, and `HistoryRecordCSV` parses the same
     format as the test helper `NightFixture`; making the SerenixCore constants public and
     merging the two readers would stop them drifting.
   - Done when: the vertical-rotation night gives share 0% and more wake minutes on the turn
     series; the report has both series' values and their differences.
9. [x] **Slice: the `sleep-accuracy` executable.** Parse `walch`/`strap`, `--data`, `--out`,
   `--threshold`/`--sweep`; run `git rev-parse HEAD` (else "unknown"); compute everything before
   writing either file; non-zero exit with usage on bad arguments. Argument parsing lives in the
   library (tested); `main.swift` only does I/O.
   - Blocked by: 6, 8
   - Note from task 7: `AccuracyReport.sweep` returns nil for an empty threshold list, and
     `RunStamp` takes no thresholds (the run fills them in), so parse `--sweep` once and reject
     an empty list with the usage message.
   - Seam: harness library (argument parsing) · Files: `src/SleepAccuracy/HarnessArguments.swift`,
     `src/sleep-accuracy/main.swift`, `tests/SleepAccuracyTests/HarnessArgumentsTests.swift`; the
     Strap folder reader went into `HistoryRecordCSV.nights(in:)` (tested) so `main.swift` decides
     nothing.
   - Found when run by hand: on the 28–29 Oct fixture the transfer run gives 90% of turn-active
     seconds also Tilt-active; the Walch-motion research note reports 92.3% for the same file. Its
     figure matches taking the floats as (w, x, y, z) and the vertical as R·z; the harness takes
     (x, y, z, w) and Rᵀ·z. All four conventions agree within ~2 points and the turn is the same.
     Which is right is the map's open question (are `d[41:57]` a quaternion, in what order); a
     still-in-several-positions test on the Strap settles it.
   - Not checked: a run on Windows (git lookup reads `Path` case-insensitively; confirm the stamp
     shows a SHA there).
   - Done when: no `--out` → usage error, nothing written.
10. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
    `swift build` green; every spec criterion checked; `git status` shows no dataset files.
    By hand on the developer machine: download sleep-accel 1.0.0 to a folder outside the repo,
    run `sleep-accuracy walch --sweep …`, confirm every recording is kept or listed; run
    `sleep-accuracy strap` on a folder holding copies of the two fixture night CSVs.
    - Blocked by: 9
    - Carried to the PR checklist: the macOS CI job builds the app. Posting the baseline on #82
      happens after merge (the ticket's own work).

## Done when
- All tasks checked, every success criterion in spec 019 met, suite green.

## Verification
- `swift test` (all `SerenixCoreTests` unchanged and green, plus new `SleepLabellingTests`,
  `TiltTests` and `SleepAccuracyTests`), lint and build on Linux.
- By hand: the Walch and Strap runs above produce Markdown + JSON in `--out`.
- CI on the PR: Linux job (lint/build/test) and macOS `.ipa` build.
