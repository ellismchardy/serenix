# Plan: 008 — Readiness

**For spec:** specs/008-readiness.md
**Type:** feature
**Branch:** feat/readiness

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
One seam, the Today view (`TodayView`, public), as the spec says. A new pure Readiness function
in `src/SerenixCore/Readiness.swift` takes the Night, the Nights and the Days' Loads and returns
Calibrating / missing / a whole number; `TodayView` calls it where it now reads
`night?.readiness`. It reuses `Baseline` (median and Spread; Sleeping HR gains a Spread) and
`typicalLoad(for:among:)` for the previous Day. Every constant is named and cites issue #18.

The stored field `Night.readiness` is used by 24 calls in
`tests/SerenixCoreTests/TodayViewTests.swift` (band, advice, popup and calibrating tests) to
inject a Readiness. Removing it is a wide change, so it goes **expand → migrate → contract**:
task 1 computes Readiness only when the Night has no stored one (a temporary bridge), task 2
rewrites those tests to Nights whose inputs give the Readiness they need (hand-worked literals)
and deletes the field and the bridge. The shell's `StoredNight` never had a Readiness, so storage
doesn't change; only the Readiness popup view changes, for the new rows.

New Readiness tests go in a new `tests/SerenixCoreTests/ReadinessTests.swift`, driven through
the Today view (its own private `todayView` helper, as `LoadPopupTests.swift` does).

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer, expand):** Readiness from HRV, Sleeping HR and Time Asleep — scores
   (HRV on ln with its Spread, Sleeping HR against a typical Spread of 2.5 bpm, Time Asleep
   short of 7 h), clamp ±3, weights 0.5 / 0.25 / 0.15 re-weighted to add to 1 (no Days yet, so
   Load is always dropped), the curve, halves-up rounding; missing with no HRV. `TodayView` uses
   it when the Night has no stored Readiness (bridge, removed in task 2).
   - Seam: Today view · Files: `Readiness.swift` (new), `Baseline.swift` (Sleeping HR typical
     Spread), `TodayView.swift`, `ReadinessTests.swift` (new)
   - Done when: Score criteria "usual Night reads 70, Ready" (first sentence), "HRV 50 … 38 …
     HRV 72 … 90", "HRV 20 … 8", "Sleeping HR 57 … 43 … 48 … 85", "Time Asleep 5 h … 54 …";
     criterion "A Night with no HRV reads '—'"; "with three [earlier Nights], it reads a number".
2. [x] **Migrate and contract:** remove `Night.readiness` and the bridge. Every test that set
   `readiness:` now builds a Night whose HRV / Sleeping HR / Time Asleep give the Readiness it
   needs (e.g. the band table's 100, 67, 66, 34, 33, 0; the advice tests' Ready / Steady /
   Take it easy), with each input value worked by hand and committed as a literal. Same
   assertions, so no behavior is weakened.
   - Seam: Today view · Files: `Night.swift`, `TodayView.swift`, `Readiness.swift`,
     `TodayViewTests.swift` (the 24 `readiness:` uses, incl. `readinessShowsItsNumberAndBand`,
     `aNightWithoutScoresShowsDashesAndNoBand`, the calibrating, popup and advice tests)
   - Done when: criterion "No `SerenixCore` type still carries a stored Readiness on a Night";
     criterion "with two earlier Nights … Calibrating, '2/4'"; whole suite green.
3. [x] **Slice:** a dropped Sleeping HR — a Night with HRV but no Sleeping HR drops that input
   and re-weights the rest.
   - Seam: Today view · Files: `Readiness.swift`, `ReadinessTests.swift`
   - Done when: criterion "HRV 50 with no Sleeping HR reads 26".
4. [x] **Slice:** Sleeping HR's measured Spread — with ≥ 7 earlier Nights, scaled MAD floored at
   1 bpm (named constants beside HRV's and respiratory rate's); Sleeping HR's Zone unchanged.
   - Seam: Today view · Files: `Baseline.swift`, `ReadinessTests.swift`
   - Done when: the three "Sleeping HR's Spread" criteria (54 → 60 / 43; MAD 1.4826 → 34; Zones
     54 In range and 56 Watch against seven of 52).
5. [x] **Slice:** the previous Day's Load — the Day before the Night's date, against
   `typicalLoad(for:)` that Day; −(Load − typical) / 20 above typical, 0 at or below, clamped;
   dropped when that Day has no Load or typical Load is calibrating. `TodayView` passes its Days.
   - Seam: Today view · Files: `Readiness.swift`, `TodayView.swift`, `ReadinessTests.swift`
   - Done when: Score criteria "usual Night … still reads 70" (Load 40), "14 Nov at Load 65 …
     65 … 85, 61 … 200 … 56", "All four off at once … 10"; criteria "only three Days … 70 … no
     Load on 14 Nov, also 70" and "Readiness follows the Days … 70 … 61". Time Asleep "6 h 59 m
     reads 70; 9 h reads 70" if not already covered in task 1.
6. [x] **Slice:** the Readiness popup's Time Asleep row — rows no longer tied to a Nightly
   Metric (each carries its own name), HRV and Sleeping HR unchanged, then Time Asleep with
   reference "7h" and an h/m difference ("−30m", "+1h 10m", "±0"). The shell's popup view shows
   the row name from `SerenixCore`.
   - Seam: Today view · Files: `Popups.swift`, `TodayView.swift`, `ReadinessTests.swift`,
     `TodayViewTests.swift` (popup row tests, if the row's shape changes),
     `src/SerenixApp/TodayPopups.swift`
   - Done when: popup criterion "lists HRV, Sleeping HR, Time Asleep … 6h 30m … +1h 10m … ±0"
     (the Time Asleep part).
7. [x] **Slice:** the Readiness popup's Yesterday's Load row — the previous Day's Load,
   "Typical N" or "Calibrating", signed difference as in spec 006; "—" when the Load is missing.
   - Seam: Today view · Files: `Popups.swift`, `TodayView.swift`, `ReadinessTests.swift`
   - Done when: popup criteria: the four rows in order, and "Yesterday's Load 85 over typical 45
     … +40 … −5 … '—' … 'Calibrating'".
8. [x] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every automated success criterion in spec 008 checked and ticked.
   - Carried to the PR checklist (need the PR / the phone): the macOS CI job builds the app;
     installed over the previous build, past Nights show a Readiness, band colour and message;
     the Readiness popup shows four rows matching the tiles and the previous Day's Load popup.

## Done when
- All tasks checked, every automated success criterion in the spec met, suite green; the CI
  build and phone checks listed on the PR.
