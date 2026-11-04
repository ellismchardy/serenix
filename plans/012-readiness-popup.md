# Plan: 012 — Readiness popup

**For spec:** specs/012-readiness-popup.md
**Type:** feature
**Branch:** feat/readiness-popup

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).

## Context
Spec 012 (approved) redraws the Readiness popup from prototype variant E: a ring with the band pill
and a verdict; a "Why, biggest effect first" list with each input's weight, points, reason and gauge;
7 week bars; and Sleep Score. Today `ReadinessPopup` (`src/SerenixCore/Popups.swift`) holds spec
008's table rows, and `Readiness.score` (`src/SerenixCore/Readiness.swift`) returns only the rounded
number. Its per-input scores and re-weighted weights stay inside the function.

## Approach
First, expose Readiness's workings without changing any behaviour: one breakdown (each input's
clamped score and re-weighted weight, plus Z) that `score` is built on. Also pull the Today view's
"Readiness for the Night dated D" logic (Baselines, Calibrating, Sleep Need, previous Day's Load) out
of `TodayView.init` so it can be reused for the week bars. Then grow `ReadinessPopup` with the new
fields next to the old ones (expand). Each new field is driven by Today view tests at the spec's one
seam. Last, switch the shell to the new fields and delete the old rows (contract).

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Prefactor:** `Readiness` gains a breakdown (inputs: HRV, Sleeping HR, Time Asleep, Load,
   each with a clamped score and re-weighted weight, or dropped; Z), and `score` is built from it.
   Extract the Today view's per-Night Readiness (Calibrating, Baselines, Sleep Need, previous Day's
   Load and typical Load) into one internal function that takes a Night date.
   - Files: `src/SerenixCore/Readiness.swift`, `src/SerenixCore/TodayView.swift`
   - Done when: existing suite still green, with no behaviour change.
2. [x] **Slice (tracer):** popup verdict and Why rows: name, weight text, value text, points
   (share of curve(Z) − curve(0), with the slope at Z = 0, and largest-remainder rounding to
   Readiness − 70), ordered by points with dropped inputs last. Add the new fields beside the old
   `rows`.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`, `src/SerenixCore/Readiness.swift`,
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift` (or a new
     `ReadinessPopupTests.swift`)
   - Done when: the criteria for the usual Night (weights and order), HRV 50, all four off, HRV 72 +
     6 h, cancelling inputs, and points adding up to Readiness − 70 pass.
3. [x] **Slice:** reasons and gauges: each row's reason (HRV and Sleeping HR from spec 008's row
   texts, Time Asleep short or enough, Load above or no more, the three dropped reasons) and gauge
   at 0.5 + score / 6, with none when dropped.
   - Seam: Today view · Files: same as 2
   - Done when: the criteria for "−17% against your usual 60 ms.", the clamped gauge at 0, Sleeping
     HR's gauge at 0.1667, dropped Sleeping HR, Typical Load calibrating, "Enough for your Sleep
     Need.", and "No more than your typical 45." pass.
4. [ ] **Slice:** Calibrating and Missing popups: no band and no Why rows; spec 002's Calibrating
   explanation, or "No HRV for this Night, so there's no Readiness." Sleep Score shows in both.
   - Seam: Today view · Files: same as 2
   - Done when: the Calibrating and No HRV criteria pass.
5. [ ] **Slice:** Your week: the Day shown and the 6 Days before, oldest first, with weekday label,
   Readiness or none (no Night, missing or Calibrating), band, and which Day is the one shown. Uses
   task 1's per-Night Readiness, so each Night is judged against its own Baselines.
   - Seam: Today view · Files: same as 2
   - Done when: the week criterion passes.
6. [ ] **Shell + contract:** redraw `ReadinessPopupView` in variant E's layout (ring card with pill
   and verdict, Why rows with gauges, week bars, Sleep Score) using the existing popup cards,
   `ScoreRing` and `ReadinessBand.colour`. Remove `rows`, `baselineNote` and `ReadinessPopupRow`
   if nothing else uses them, and rewrite or remove the tests that pinned spec 008's popup rows,
   which spec 012 supersedes.
   - Files: `src/SerenixApp/TodayPopups.swift`, `src/SerenixCore/Popups.swift`,
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`,
     `tests/SerenixCoreTests/ReadinessTests.swift`, `SleepNeedTests.swift`, `SleepScoreTests.swift`
     (wherever the old rows are asserted)
   - Done when: suite green with no references to the old rows; the shell compiles on CI.
7. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift` and
   `swift build` green; every automated criterion in spec 012 is ticked. Carried to the PR
   checklist: the macOS CI build, and the by-hand phone check (open from the ring, every section
   in Light and Dark, closes on a tap outside or a swipe down).

## Verification
- `swift test` (Windows): the Today view tests cover every number, order, reason, gauge and week
  bar in spec 012.
- Lint and typecheck as above.
- After `/ship`: the macOS CI job builds the `.ipa`; sideload it and check the popup by hand
  (ADR 0002/0003).

## Done when
- All tasks checked, every success criterion in spec 012 met, suite green.
