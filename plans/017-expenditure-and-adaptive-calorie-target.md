# Plan: 017 — Expenditure and the adaptive Calorie Target

**For spec:** specs/017-expenditure-and-adaptive-calorie-target.md
**Type:** feature
**Branch:** feat/adaptive-calorie-target

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
Both seams already exist. The **Food view** (`FoodView`) gains the Profile's birth year and sex
(height it already takes), and reads the Activity Level and Adapt switch from `FoodTargets`. A
new pure `Expenditure` calculation in `SerenixCore` does the arithmetic (starting estimate,
window figure, easing, suggestion, floor); the Food view calls it with the Food Entries,
Complete Days and Weigh-ins it already has, and Trend Weight from the Body view's own rule. The
**Body data file** needs no version change: `FoodTargets`' new fields are optional, so a version
2 file still reads.

Time stays an input: "today" and the current year come from the Food view's `now` and time zone,
never `Date()` in the core. Every constant is named and cites issue #52 and
`docs/research/adaptive-calorie-expenditure.md` (Mifflin-St Jeor from
`docs/research/calories-burned-from-heart-rate.md`).

The shell adds the Activity Level picker, the Adapt switch, the suggestion and floor message to
the targets sheet, and the Expenditure line to the Food view. `StoredFoodTargets` gains two
optional fields in `Food.store` (ADR 0008).

Spec note: the floor's "spec 015's Ease the goal offer" is read as: show the Rate card's easier
goal when spec 015 offers one, otherwise a "Change my Pace" button that opens the Weight Goal
sheet. Spec 015's offer only appears after 7 Days off pace, so the button covers the rest.

New tests go in `tests/SerenixCoreTests/ExpenditureTests.swift` (new, through the Food view) and
the existing `BodyDataFileTests.swift`. Expected values are the spec's literals.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer bullet):** the starting estimate. `ActivityLevel` (four cases and
   factors) and an optional Activity Level on `FoodTargets` (nil reads as Light); the Food view
   takes birth year and sex and returns Expenditure with source "from your Profile", the resting
   rate, and why there's none. Shell: the Activity Level picker in the targets sheet, the field
   on `StoredFoodTargets`, and the Expenditure line on the Food view.
   - Seam: Food view · Files: `src/SerenixCore/Expenditure.swift` (new),
     `src/SerenixCore/FoodTargets.swift`, `src/SerenixCore/FoodView.swift`,
     `tests/SerenixCoreTests/ExpenditureTests.swift` (new), `src/SerenixApp/FoodStore.swift`,
     `src/SerenixApp/FoodScreen.swift`, `src/SerenixApp/FoodTargetsSheet.swift`
   - Built: a Profile with no sex reads as "prefer not to say" (the spec doesn't cover nil;
     tested). The targets sheet's footer names what the starting estimate lacks. The Food view
     already words the "from your last 21 Days" source; task 3 must build that from the
     window's named constant, not a typed 21.
   - Done when: criteria "male/female/prefer not to say at 80 kg, 180 cm, 30", "the other
     three Activity Levels", "no height, birth year or Weigh-in".
2. [x] **Slice:** a window's figure and whether it has enough data. The 21 Days ending on a Day;
   mean Intake of its Complete Days plus Trend Weight's fall × 7,700 ÷ the Days between its
   first and last Weigh-in Days; the 10 / 8 / 14 thresholds. The Food view returns today's
   window figure (shown in the targets sheet as how Expenditure was worked out).
   - Seam: Food view · Files: `Expenditure.swift`, `FoodView.swift`, `ExpenditureTests.swift`,
     `FoodTargetsSheet.swift`
   - Built: the window ends on the Day shown (the spec's "Days up to the one shown"). Tests also
     pin the window's edges and the restart rule (spec Open questions). The Food view's "last N
     Days" wording now comes from `FoodView.expenditureWindowDays` (task 1's note), and Trend
     Weight is worked out once per Food view.
   - Done when: criteria "2,000 with Trend Weight unchanged; incomplete Days left out",
     "2,385", "9 / 7 / 13 isn't enough".
3. [ ] **Slice:** easing. Expenditure seeds from the starting estimate on the first Day with
   enough data and moves 10% a Day toward each Day's figure; a Day without enough data holds it.
   The source turns to "from your last 21 Days". Shell: the Food view line's wording follows the
   source.
   - Seam: Food view · Files: `Expenditure.swift`, `FoodView.swift`, `ExpenditureTests.swift`,
     `FoodScreen.swift`
   - Done when: criterion "2,402.75 then 2,362.475".
4. [ ] **Slice:** the suggested Calorie Target and its floor. Expenditure ∓ Pace × 7,700 ÷ 7,
   or Expenditure when holding or with no goal; rounded to 10, a floored one up; never under
   1,200 or the resting rate, with the not-reachable flag. Shell: the suggestion in the targets
   sheet, and the floor message with spec 015's easier goal or "Change my Pace".
   - Seam: Food view · Files: `Expenditure.swift`, `FoodView.swift`, `ExpenditureTests.swift`,
     `FoodTargetsSheet.swift`, `FoodScreen.swift`, `src/SerenixApp/BodyScreen.swift`
   - Done when: criteria "1,850 / 2,680 / 2,400", "1,620 floored, flagged; 1,200 with no
     resting rate".
5. [ ] **Slice:** Adapt. An optional Adapt switch on `FoodTargets` (nil reads as off); the Food
   view's applied Calorie Target is the suggestion when it's on and there is one, else the typed
   one, and the Macro Targets and "left/over" use it. Shell: the switch in the targets sheet and
   the field on `StoredFoodTargets`.
   - Seam: Food view · Files: `FoodTargets.swift`, `FoodView.swift`, `ExpenditureTests.swift`,
     `FoodStore.swift`, `FoodTargetsSheet.swift`
   - Done when: criterion "Adapt on: the suggestion; off: the typed one; on with no suggestion:
     the typed one".
6. [ ] **Slice:** backup. `FoodTargets`' Activity Level and Adapt round-trip in the Body data
   file; a file without them imports as Light and off.
   - Seam: Body data file · Files: `tests/SerenixCoreTests/BodyDataFileTests.swift`,
     `src/SerenixCore/BodyDataFile.swift` (only if the round trip needs it)
   - Done when: criterion "round-trip; a file without them imports as Light and off".
7. [ ] **Verify:** `swift test` green, `swift format lint --strict --recursive src tests
   Package.swift` clean, `swift build` clean; every `SerenixCore` success criterion in spec 017
   matched to a test and ticked. Carried to the PR checklist (need the PR): the macOS CI build,
   and the by-hand phone checks: the Expenditure line's two wordings, the Activity Level
   picker, the Adapt switch, the floor message with its easier goal or "Change my Pace", and an
   older build of this branch opened against `Food.store` dropping the two new settings.

## Done when
- All tasks checked, every success criterion in spec 017 met, suite green.
