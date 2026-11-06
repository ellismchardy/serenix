# Plan: 006 — Load popup redesign (sentence and bar against typical Load)

**For spec:** specs/006-load-popup.md
**Type:** improvement
**Branch:** feat/load-popup-redesign

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
Spec 006 was built, then changed (commit da1ffca on `feat/load-popup-redesign`) to variant C of
`prototype/load-popup-ui`: the popup now opens with a sentence and a Load bar comparing the Day to
typical Load, then the HR Zone mix (one split bar, rows Zone 5 first), then the hourly bars, then
Highest HR and Max HR used. Only the unticked criteria are planned; Load of a Day, Typical Load,
Protocol, Live HR pill and the existing Today view behavior stay as built.

## Approach
All new logic goes into `LoadPopup` in `src/SerenixCore/Popups.swift`, which already has
`typicalLoad(for:among:)` (`TypicalLoad.value` / `.calibrating`) and the Day's `load`, so each
new field is worked out from values already in its `init`. No prefactor needed. The shell's
`LoadPopupView` (`src/SerenixApp/TodayPopups.swift:956`) is then redrawn to only draw these
fields. Every Core task tests at the **Today view** seam in
`tests/SerenixCoreTests/LoadPopupTests.swift`, through `loadPopup` on the Today view, as the
existing tests there do.

## Tasks (ordered; each is one vertical slice, green and committable on its own)
1. [x] **Slice: the sentence.** Add `LoadPopup.comparisonText: String`: the four bands from Load ÷
   typical Load (<0.8, <1.2, <1.5, ≥1.5), "Learning your typical Load" while calibrating, "No Load
   this Day" with the Day's Load missing, and typical Load 0 (Load 0 usual, else much harder). Band
   edges are named constants with a comment pointing at spec 006.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`, `tests/SerenixCoreTests/LoadPopupTests.swift`
   - Done when: the sentence criterion (typical 50 with Loads 39, 40, 59, 60, 74, 75; fewer than 4
     Days; Load missing; typical 0 with Loads 0 and 5) passes.
2. [x] **Slice: the Load bar.** Add `LoadPopup.loadBarFill: Double?`: Load ÷ (2 × typical), capped
   at 1; 0 with the Day's Load missing; nil while calibrating; typical 0 gives 0 for Load 0, 1 for
   any other. The marker always sits at the middle, so no field for it.
   - Seam: Today view · Files: same as task 1
   - Done when: the Load bar criterion (25 → 0.25, 100 → 1.0, 130 → 1.0; missing → 0; calibrating
     → nil; typical 0) passes, and the "texts still come with the sentence, typical line and Load
     bar" criterion passes (a no-records Day and a not-available Day both have `comparisonText`,
     `typicalText` and `loadBarFill`).
3. [x] **Slice: HR Zone mix and row order.** Reverse `zoneRows` to Zone 5 first; add
   `LoadPopup.zoneMix: [LoadPopupZoneShare]` (zone + share, HR Zone 1 to 5, only zones with time,
   empty with none). Rewrite the existing order tests (`zoneRowsRunFromHRZone1To5WithTheirLabels`
   and the share/time-text order expectations near lines 168–225) to the new order — the spec
   changed, so this is not weakening a test.
   - Seam: Today view · Files: same as task 1
   - Done when: the mix criterion (Zone 2 30m + Zone 4 90m → shares 0.25, 0.75, none for others;
     rows Zone 5 first; no time → no mix) passes, and the existing zone-time-text criterion
     ("42m", "1h 05m") still passes in the new order.
4. [x] **Shell: redraw `LoadPopupView`** as variant C: pill + date header; a card with the sentence,
   `typicalText`, the Load bar (fill from `loadBarFill`, Load written at its end, "typical" marker
   at the middle, hidden when nil) and `lastSyncText`; "How hard" with the split bar from `zoneMix`
   and the rows; "When" with the existing `hourlyBars` chart; a small card with Highest HR and Max
   HR used. Note still replaces items 3–5. Checked by hand (ADR 0002); no tests.
   - Files: `src/SerenixApp/TodayPopups.swift`
   - Done when: `swift build` of `SerenixCore` is green and the drawing uses only `LoadPopup`
     fields (no logic in the view); phone check carried to the PR checklist.
5. [x] **Slice: the Day's Load while typical Load is learned.** Add
   `LoadPopup.learningLoadText: String?`: "Load 40" ("Load —" with the Load missing, from the
   ring's `loadText`) while typical Load is calibrating; nil with a typical Load. Draw it in the
   shell's against-typical card in place of the Load bar. Also fix the stale "Heart rate zones"
   doc comment on `LoadPopupZoneRow.label` (the heading is now "How hard").
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`, `tests/SerenixCoreTests/LoadPopupTests.swift`, `src/SerenixApp/TodayPopups.swift`
   - Done when: the criterion "with fewer than 4 Days, a Load of 40 shows "Load 40" in place of
     the Load bar…" passes.
6. [x] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every unticked Today view criterion ticked in the spec.
   - Carried to the PR checklist: macOS CI app build, and the by-hand phone check of the redrawn
     popup in its new order (plus the other unticked by-hand checks the spec still lists).

## Done when
- All tasks checked, every unticked Today view criterion in spec 006 met, suite green.

## Verification
- Locally on Windows: `swift test` (new LoadPopupTests pass, existing ones green), lint, `swift build`.
- On the PR: macOS CI builds the `.ipa`; sideload and open the Load popup on today and on an
  earlier Day, a no-records Day and a calibrating profile, comparing against
  `prototype/load-popup-ui` `?variant=C`.
