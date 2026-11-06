# Plan: 016 — Food logging and Macro Targets

**For spec:** specs/016-food-logging-and-macro-targets.md
**Type:** feature
**Branch:** feat/food-and-macros

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
Two seams, as the spec says. The **Food view** (`FoodView`, public, new) is a pure function in
the shape of `BodyView`: Food Entries, Complete Days, the Calorie Target and overrides, the
Weigh-ins and current Weight Goal, the Profile's height, the Day shown, a time and a time zone
in; everything the Food view on the Body tab shows out. It builds a `BodyView` internally for
Trend Weight, so the two never disagree. It grows one slice at a time, starting with a Day's
Intake. The **Body data file** (`BodyDataFile`, existing) moves to version 2 in its own slice.
A new value type `FoodEntry` lives in its own file, in kcal, grams and UTC. Every constant is
named and cites issue #54 and `docs/research/macro-targets-by-goal.md`.

The shell: the Body tab gains a Weight | Food switch; the Food view, a Food Entry sheet and a
targets sheet. Food Entries, Complete Days, the Calorie Target and overrides are Body data (ADR
0008), but their SwiftData models go in a **second store file, `Food.store`**, its own container
inside `BodyStore`, not in `Body.store`. Builds from `main` (spec 015) already open `Body.store`
knowing only Weigh-ins and Weight Goals, and opening a store with models a build doesn't know
strips them; a separate file is the same protection ADR 0008 gives the Body store as a whole.
Body data is never logged. The tracer bullet builds the whole path (switch, store
model, sheet, the Day's Intake on screen) so later slices only add to it.

No prefactor: `BodyView`, `BodyStore` and `BodyDataFile` take additions only. Tasks share
`FoodView.swift`, `BodyStore.swift` and the Food screen, so they run in order; none is
independent.

New tests go in `tests/SerenixCoreTests/FoodViewTests.swift` (new) and the existing
`tests/SerenixCoreTests/BodyDataFileTests.swift`. Expected values are the spec's literals.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer bullet):** a Day's Intake. `FoodEntry` (time, kcal, optional protein, fat,
   carbs, optional name); `FoodView` returns the shown Day's entries (newest first) and Intake
   (blank macros count 0), each entry on the local Day of its time. Shell: the Weight | Food
   switch, a `StoredFoodEntry` model in a new `Food.store` container in `BodyStore`, the Food view listing the Day's entries
   and Intake, a date picker for past Days, and the Food Entry sheet (add only).
   - Seam: Food view · Files: `src/SerenixCore/FoodEntry.swift` (new),
     `src/SerenixCore/FoodView.swift` (new), `tests/SerenixCoreTests/FoodViewTests.swift` (new),
     `src/SerenixApp/BodyStore.swift`, `src/SerenixApp/BodyScreen.swift`,
     `src/SerenixApp/FoodScreen.swift` (new), `src/SerenixApp/FoodEntrySheet.swift` (new)
   - Built: `Food.store` belongs to a small `FoodStore` of its own (`src/SerenixApp/FoodStore.swift`,
     new) instead of a second container inside `BodyStore`; `MainTabs.swift` creates it. Later
     tasks' "`BodyStore.swift`" means `FoodStore.swift` for food data.
     After review: the Food view follows today past midnight (`pickedDay`, nil is today), and
     user-facing text says "Food Entries", not the avoided "food log". Task 2 must key the list
     rows by `FoodEntryRow.id`, not the list offset, before adding edit and delete.
   - Done when: criteria "500 kcal + 700 kcal give 1,200 kcal and 30/0/0 g" and "23:30 counts
     that Day, 00:30 the next".
2. [x] **Slice:** limits, edit and delete. `FoodEntry.refusal(now:)`: over 5,000 kcal, a macro
   over 500 g, a name over 40 characters, or a future time is refused with a message; 0 kcal is
   fine. Shell: the sheet shows the refusal and edits an existing entry; swipe to delete.
   - Seam: Food view · Files: `FoodEntry.swift`, `FoodViewTests.swift`, `BodyStore.swift`,
     `FoodScreen.swift`, `FoodEntrySheet.swift`
   - Built: the rows sit in a scroll view, not a List, so delete is a "Delete Food Entry" button
     in the edit sheet (and on holding a row), not a swipe. Negative values are refused too (the
     spec's 0 lower bound). The edit sheet's time picker keeps the entry on its Day. Messages
     are built from the limit constants.
   - Done when: criterion "over 5,000 kcal, a macro over 500 g, or in the future is refused; 0
     kcal is accepted".
3. [x] **Slice:** Complete Days. `FoodView` says whether the shown Day is complete and whether it
   can be (not with no entries); a Complete Day with no entries left is not complete. Shell: a
   `StoredCompleteDay` model, the Day complete toggle.
   - Seam: Food view · Files: `FoodView.swift`, `FoodViewTests.swift`, `BodyStore.swift`,
     `FoodScreen.swift`
   - Built: `StoredCompleteDay` in `Food.store`; after an edit or delete the store keeps only the
     marked Days that still have an entry (`FoodView.completeDays`), so a re-added entry doesn't
     bring a mark back. Task 7's import must check Complete Days against the same rule.
   - Done when: criterion "no entries can't be marked; deleting the last entry leaves it not
     complete; editing keeps it complete".
4. [x] **Slice:** Calorie Target. Its refusal outside 800–6,000; `FoodView` gives "left" or
   "over" against it, and nothing when there's no target. Shell: a stored Calorie Target (one
   current value), the targets sheet (Calorie Target only for now) behind a gear, the calories
   line on the Food view.
   - Seam: Food view · Files: `FoodView.swift`, `FoodViewTests.swift`, `BodyStore.swift`,
     `FoodScreen.swift`, `src/SerenixApp/FoodTargetsSheet.swift` (new)
   - Built: the refusal and "left or over" live in `src/SerenixCore/CalorieTarget.swift` (new);
     the target is a `StoredFoodTargets` row in `Food.store`, which task 6's overrides join.
     After review: the limit tests live in `CalorieTargetTests.swift`, mirroring the new file; the
     limit messages share one formatter (`limitText`). PR phone check: an older build from this
     branch opened against `Food.store` drops the stored targets.
   - Done when: criteria "799 and 6,001 refused, 800 and 6,000 accepted", "1,450 of 2,000 is 550
     left; 2,120 is 120 over", and the no-target half of "no Weigh-ins / no Calorie Target".
5. [x] **Slice:** suggested Macro Targets. Protein 2.2 g/kg losing, 1.6 g/kg otherwise, on Trend
   Weight or, with height and BMI over 30, the weight at BMI 25; fat 25% of the Calorie Target;
   carbs the rest, with the under-130 g warning and the "protein and fat use up the Calorie
   Target" message at 0; none without Trend Weight. Shell: the three macro bars.
   - Seam: Food view · Files: `FoodView.swift`, `FoodViewTests.swift`, `FoodScreen.swift`
   - Built: the rules live in `src/SerenixCore/MacroTargets.swift` (new); the Food screen now also
     takes the Body store (Weigh-ins, Weight Goal) and the Profile (height), so `BodyScreen.swift`
     passes them in.
     After review: protein and fat using up the target exactly also says "none left for carbs";
     the screen's 130 g comes from `MacroTargets.lowCarbsGrams`; Trend Weight comes from
     `BodyView.trend(of:in:)` directly. On a past Day the bars use today's targets (the spec's
     "current Trend Weight"); tested through the Food view, so no `MacroTargetsTests.swift`.
   - Done when: criteria "80 kg losing: 176 / 55.6 / 199", "80 kg gaining or holding: 128 / 55.6
     / 247", "100 kg, 175 cm: 168.4 g; no height 220 g", "1,500: 105.3 g with the warning",
     "1,000 at 100 kg: carbs 0 with the message", and the no-Weigh-ins half of "no Weigh-ins / no
     Calorie Target".
6. [ ] **Slice:** overrides. Protein and fat set in grams replace the suggestions; carbs fill the
   rest; an override leaving carbs below 0 is refused; "Use suggested" clears both. Shell: the
   override fields and "Use suggested" in the targets sheet, stored with the Calorie Target.
   - Seam: Food view · Files: `FoodView.swift`, `FoodViewTests.swift`, `BodyStore.swift`,
     `FoodTargetsSheet.swift`
   - Done when: criterion "150 g and 70 g at 2,000 give 192.5 g carbs; below 0 refused; Use
     suggested restores 176 g and 55.6 g".
7. [ ] **Slice:** backup version 2. `BodyData` gains Food Entries, Complete Days, the Calorie
   Target and overrides; the file writes version 2 and reads 1 and 2; import adds and skips
   Food Entries and Complete Days by the spec's duplicate rule, takes the file's targets only
   when none is set here, and `refusal` covers out-of-limit Food Entries and targets. Shell:
   `BodyStore.allData()` and `add(_:)` carry the new data.
   - Seam: Body data file · Files: `src/SerenixCore/BodyDataFile.swift`,
     `tests/SerenixCoreTests/BodyDataFileTests.swift`, `BodyStore.swift`
   - Done when: criteria "version 2 round-trips everything", "a version 1 file imports",
     "partly-here counts; the file's Calorie Target only when none is set", "a 5,001 kcal Food
     Entry imports nothing".
8. [ ] **Verify:** `swift test` green, `swift format lint --strict --recursive src tests
   Package.swift` clean, `swift build` clean; every `SerenixCore` success criterion in spec 016
   matched to a test and ticked. Carried to the PR checklist (need the PR): the macOS CI build,
   and the by-hand phone checks: the Weight | Food switch, logging, editing and deleting on today
   and a past Day, the targets sheet and "Use suggested", the Day complete toggle surviving a
   relaunch, and export then import on a fresh install restoring food data.

## Done when
- All tasks checked, every success criterion in spec 016 met, suite green.
