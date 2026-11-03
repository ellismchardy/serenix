# Plan: 011 — Metric popup

**For spec:** specs/011-metric-popup.md
**Type:** feature
**Branch:** feat/metric-popup

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
> On approval this is saved as `plans/011-metric-popup.md` (the branch already exists, holding
> the spec commit `2a435c7`).

## Context
Spec 011 (approved) replaces the Nightly Metric popup's line chart and 5-row list (spec 002)
with prototype variant E. Variant E has a Zone scale, a verdict sentence, 14 blocks coloured
by each Night's own Zone, facts, an exact "Your Zones" table, and fixed texts for "What it is"
and "What moves it". The spec also gives the Resting HR tile its own popup; until now it opened
none (spec 007). All content is decided in `SerenixCore` and tested at the Today view, the
spec's only seam. The shell only draws it, and that is checked by hand.

## Approach
Expand, then contract. Each core task adds new fields to `MetricPopup`
(`src/SerenixCore/Popups.swift`) beside the old `chart` / `recent` / `baseline` / `inRangeLow`
/ `inRangeHigh` fields. The shell keeps compiling on the macOS CI, and the suite stays green.
One shell task then redraws the popup from the new fields and deletes the old ones, along with
the tests that spec 011 supersedes.

Code to reuse:
- `MetricTile(metric, for:among:)` (`MetricTile.swift:30`), which gives `zone`, `statusText`,
  `differenceText`, `valueText` and `comparedBaseline`. Each earlier Night's own Zone is
  `MetricTile(metric, for: earlierNight, among: nights).zone`, because `Baseline` already looks
  only at earlier Nights.
- `Zone.inRangeLimits` (`Zone.swift:78`), the private cut-off constants, and `z(...)`.
- `Baseline` (`Baseline.swift`), which gives `median`, `spread`, `earlierNights`,
  `isCalibrating` and `minEarlierNights = 3`.
- From `Day.swift`: `Day.adding(days:)`, `Day.weekdayLetter`, `Day.text`.
- `formattedValue(of:_:)` and `wholeText`. `tenthsText` becomes internal.
- `DayLoad.restingHR` and `RestingHRTile` for the Resting HR popup.
- The `ReadinessAdvice` pattern (an enum namespace with a `switch` that returns literals) for
  the fixed texts.

## Tasks (ordered; each is one vertical slice, green and committable on its own)
1. [x] **Slice: heading, pill and verdict.** `MetricPopup` gains:
   - `nightText`: "Night of 2–3 Nov", or "Night of 31 Oct–1 Nov" across a month. This needs a
     new `Day` formatter.
   - `statusText`: the tile's status word.
   - `verdictText` and `verdictZone`, following the spec's rules for: with a Baseline (the
     tile's difference + "against your Baseline:" + the Zone phrase), SpO2's three levels,
     Calibrating (the metric's name and the earlier-Night count), and missing.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`, `src/SerenixCore/Day.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: these verdicts are exact, each with its Zone:
     - HRV 48 against Baseline 60 → "−20% against your Baseline: about usual for you."
     - Sleeping HR 57 against Baseline 52 → "+5 bpm against your Baseline: well outside your
       usual."
     - SpO2 93 → "A little low."
     - Calibrating HRV with 2 earlier Nights → "Calibrating: Serenix needs 3 earlier Nights
       with HRV to know what's usual for you (2 so far)."
     - Missing HRV → "No HRV for this Night." with value "—".
2. [x] **Slice: Zone scale.** `Zone` gains:
   - a scale position: 0.5 + z/(2×3.75) for HRV and respiratory rate, 0.5 + d/(2×7.5) for
     Sleeping HR, 0.5 + d/(2×0.9) for skin temperature, and (v−88)/12 for SpO2, clamped to 0–1;
   - the fixed segments per metric;
   - named constants for the 1.5× ends, each with a comment on its unit and source.

   `MetricPopup.scale` holds the segments, the value's position and the Baseline's position
   (nil for SpO2). It is nil without a Zone. The tile gauge is unchanged.
   - Seam: Today view · Files: `src/SerenixCore/Zone.swift`, `src/SerenixCore/Popups.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when the positions are right:
     - HRV 48 against 60 → 0.30
     - HRV 200 → 1 (Watch)
     - Sleeping HR 57 against 52 → 0.8333
     - Sleeping HR 40 → 0
     - skin temperature 34.3 against 33.8 → 0.7778
     - SpO2 93 → 0.4167, with no Baseline position

     Also: each metric's segments equal the spec table, and Calibrating or missing has no scale.
3. [x] **Slice: Your Zones rows.** `Zone` gains the Watch and Out of range limits per metric:
   - HRV W = exp(ln B − 2.5·Spread)
   - respiratory rate B ∓ 2.5·Spread
   - Sleeping HR B+3 and B+5
   - skin temperature B ± 0.3 and B ± 0.6
   - SpO2 92 and 95

   `MetricPopup` gains `zonesHeading` ("Your Zones · Baseline 62 ms", or "Zones" for SpO2) and
   three `zoneRows` (Zone, range text, marked). Rows are rounded as the metric's values are
   shown, and there are none without a Baseline (except SpO2). `tenthsText` becomes internal.
   - Seam: Today view · Files: `src/SerenixCore/Zone.swift`, `src/SerenixCore/Popups.swift`,
     `src/SerenixCore/MetricTile.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when these rows come out exactly as the spec writes them:
     - HRV against 60 with the typical Spread
     - Sleeping HR 57 against 52 (Out of range marked)
     - respiratory rate with spec 004's seven Nights
     - skin temperature against 33.8
     - SpO2 93 (Watch marked)

     Also: a Night missing HRV has rows with none marked, and Calibrating has none.
4. [x] **Slice: blocks and facts.** `MetricPopup.blocks` holds 14 entries, one for the Night
   shown's date and each of the 13 dates before it, oldest first. Each has `weekdayLetter` and
   a state: a Zone (that Night's own, from its tile), no Zone (Calibrating), or no value (no
   Night, or no value). The facts are:
   - `baselineText`: the value with its unit, or "Calibrating"; nil for SpO2;
   - `lowestText` and `highestText`: over the 14 blocks only, formatted as on the tile, "—"
     with none.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when:
     - the blocks cover 14 dates, oldest first, with the right initials;
     - Nights on 12 of those dates give 2 blocks with no value;
     - a Calibrating Night's block has no Zone;
     - an earlier Night that was Watch against its own Baseline is a Watch block, even though
       it is In range against the Night shown's Baseline;
     - Lowest and Highest ignore Nights older than the 14 dates and read "—" with none;
     - SpO2 has no Baseline fact.
5. [x] **Slice: metric texts.** A new `MetricTexts` namespace in `SerenixCore` gives
   `whatItIs` and `whatMovesIt` for each Nightly Metric and for Resting HR, copied word for
   word from the spec. `MetricPopup` exposes them.
   - Seam: Today view · Files: new `src/SerenixCore/MetricTexts.swift`,
     `src/SerenixCore/Popups.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: each metric's popup texts equal the spec's table exactly.
6. [x] **Slice: Resting HR popup (core).** The Today view gains `restingHRPopup`, present
   whenever the Resting HR tile is. It holds:
   - the date text ("Today" on today), and the value text as on the tile;
   - the sentence: "So far today. A stiller moment later today can still lower it." on today,
     none on an earlier Day, and "No Resting HR for this Day." with no Resting HR;
   - 14 Day blocks (initial, and whether it has a value), Lowest and Highest;
   - Resting HR's texts.

   Replace the "no public route to a Resting HR popup" comment in the Resting HR test, and
   update `RestingHRTile`'s doc comment.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`, `src/SerenixCore/TodayView.swift`,
     `src/SerenixCore/RestingHRTile.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: spec 011's three Resting HR popup criteria pass.
7. [x] **Shell: redraw the Nightly Metric popup, and contract.**
   - Rewrite `MetricPopupView` in variant E's layout from the new fields: heading, value and
     ✓ pill in the Zone colour, the scale (faded segments, the marker, the Baseline tick), the
     verdict with its last words in the Zone colour, the blocks (Zone colour, grey, or hatched,
     with the Night shown outlined), facts, What it is, Your Zones with the marked row bold,
     and What moves it.
   - Then delete `chart`, `recent`, `baseline`, `inRangeLow`, `inRangeHigh`,
     `MetricPopupPoint`, `MetricPopupEntry` and `recentNights`, which then has no caller.
   - Rewrite or remove the tests spec 011 supersedes: the chart, list, In range limits,
     baseline and SpO2 popup tests. Where a test checked In range limits through the popup
     (the respiratory rate and HRV Spread tests), check them through the new Zones rows
     instead, which test the same limits.
   - Seam: Today view (for the rewritten tests); the drawing is checked by hand.
   - Files: `src/SerenixApp/TodayPopups.swift`, `src/SerenixCore/Popups.swift`,
     `src/SerenixCore/RecentNights.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: the suite is green with no references to the old fields; `swift build` and lint
     are clean. The look is carried to the PR checklist.
8. [ ] **Shell: the Resting HR tile opens its popup.**
   - `TodayPopup` gains `.restingHR`.
   - In `TodayScreen`, the Resting HR tile becomes a plain-style `Button`, like the metric
     tiles, and `open(_:in:)` handles the new case.
   - A new `RestingHRPopupView` uses the same layout without a pill, scale or Zones.
   - Files: `src/SerenixApp/TodayPopups.swift`, `src/SerenixApp/TodayScreen.swift`
   - Done when: the shell compiles in CI. The tap and the look are carried to the PR checklist.
9. [ ] **Verify:** the full suite, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` are green, and every Today-view success criterion in spec 011 is checked.
   The macOS CI build and the by-hand phone checks (every tile opens its popup and closes; the
   scale, verdict colour, blocks and outline; Light and Dark) are carried to the PR checklist.

Tasks 2–6 all edit `Popups.swift` and `TodayViewTests.swift`, so none can run in parallel. Run
them in order with `/execute`.

## Done when
- All tasks are checked, every success criterion in spec 011 is met, and the suite is green.

## Verification
- `swift test`, `swift build` and lint run locally on Windows, and on Linux CI.
- The macOS CI job builds the `.ipa`. After sideloading, tap each metric tile and the Resting HR
  tile in Light and Dark, and compare the result with prototype variant E
  (`prototype/vital-signs-popup`).
