# Plan: 014 — Weight trend and goals

**For spec:** specs/014-weight-trend-and-goals.md
**Type:** feature
**Branch:** feat/weight-trend

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
Two seams, both new in `SerenixCore`, as the spec says. The **Body view** (`BodyView`, public) is
a pure function in the shape of `TodayView` and `SleepView`: Weigh-ins, Weight Goals, Profile
units, a time and a time zone in; everything the weight screen shows out. It grows one slice at
a time, starting with Trend Weight alone. The **Body data file** (`BodyDataFile`) handles JSON
backup and import, and last the Happy Scale CSV. New value types `WeighIn` and `WeightGoal` live
in their own files, in kg and UTC. Every constant is named and cites its issue (#50, #51, #61)
and research note.

The shell gets a Body tab after Sleep, a Body store as a **separate SwiftData container** (ADR
0008) that only the Body models live in, and sheets that save what the user enters and pass
stored values to `BodyView`. The tracer bullet builds that whole path (tab, store, Weigh-in sheet,
Trend Weight on screen) so every later slice only adds to it. Body data is never logged.

No prefactor: nothing existing needs reshaping. `Profile` gains fields in task 4, with existing
`ProfileTests` untouched (new fields are optional with defaults).

New tests go in `tests/SerenixCoreTests/BodyViewTests.swift` and
`tests/SerenixCoreTests/BodyDataFileTests.swift`. Expected values are the spec's literals.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer):** Trend Weight from daily Weigh-ins. `WeighIn`, and `BodyView` returning
   Trend Weight points (α = 1 − 0.9^Δd), the lowest Weigh-in per Day counting, no point on Days
   without one. Shell: Body tab after Sleep, its own SwiftData container, the + sheet (last
   weight prefilled, editable date and time), the large Trend Weight and last Weigh-in.
   - Seam: Body view · Files: `src/SerenixCore/WeighIn.swift` (new), `src/SerenixCore/BodyView.swift`
     (new), `tests/SerenixCoreTests/BodyViewTests.swift` (new), `src/SerenixApp/BodyStore.swift`
     (new), `src/SerenixApp/BodyScreen.swift` (new), `src/SerenixApp/MainTabs.swift`,
     `src/SerenixApp/SerenixApp.swift`
   - Done when: spec criteria "80.0 then 79.0 → 80.0 then 79.9", "3 Days later → 79.729", "two
     Weigh-ins on one Day", "Days without a Weigh-in have no point".
2. [x] **Slice:** gaps and validation. Restart after more than 14 Days with a break; refuse
   Weigh-ins under 20 kg, over 350 kg or in the future with a message. Shell: the Weigh-in list,
   with edit and delete.
   - Seam: Body view · Files: `WeighIn.swift`, `BodyView.swift`, `BodyViewTests.swift`,
     `src/SerenixApp/BodyScreen.swift`, `src/SerenixApp/WeighInList.swift` (new),
     `src/SerenixApp/BodyStore.swift` (edit and delete by row)
   - Done when: criteria "15 Days restarts, 14 does not" and "under 20, over 350 or future is
     refused".
3. [x] **Slice:** the chart. Points per range (1W, 1M, 3M, 6M, All) with line breaks; empty
   states (no Weigh-ins, one Weigh-in). Shell draws the chart and range chips.
   - Seam: Body view · Files: `BodyView.swift`, `BodyViewTests.swift`,
     `src/SerenixApp/BodyScreen.swift`, `src/SerenixApp/WeightChartCard.swift` (new)
   - Done when: the spec's chart ranges and empty/early states hold in the Body view's output
     (tests per range, no Weigh-ins, one Weigh-in).
4. [x] **Slice:** units and Profile. `Profile` gains height (cm) and Units (kg default, lb, st
   and lb); `BodyView` formats every weight in the chosen units. Shell: Height and Units rows in
   the Profile menu, kept with the Profile.
   - Seam: Body view · Files: `src/SerenixCore/Profile.swift`, `BodyView.swift`,
     `BodyViewTests.swift`, `ProfileTests.swift`, `src/SerenixApp/ProfileStore.swift`,
     `src/SerenixApp/ProfileMenu.swift`, and the screens that show weights: `BodyScreen.swift`,
     `WeighInList.swift`, `MainTabs.swift`, `WeightChartCard.swift`; unit conversions in
     `src/SerenixCore/WeightUnits.swift` (new, with `WeightUnitsTests.swift`) and the refusal in
     the user's units in `WeighIn.swift` (both after review)
   - Done when: criterion "82.4 kg shows as 82.4 kg, 181.7 lb, 12 st 13.7 lb".
5. [x] **Slice:** Weekly Rate. Latest Trend Weight minus the Trend Weight 7 or more Days earlier,
   per week; none without that span or across a restart.
   - Seam: Body view · Files: `BodyView.swift`, `BodyViewTests.swift`, `src/SerenixApp/BodyScreen.swift`,
     and its text in `WeightUnits.swift` / `WeightUnitsTests.swift`
   - Done when: criterion "falling 0.5 kg over 7 Days gives −0.5 kg a week; none without 7 Days".
6. [ ] **Slice:** Weight Goal to lose or gain, Pace by rate. `WeightGoal` (direction from Goal vs
   Start Weight, Start Weight and date defaulting to Trend Weight and today); Pace bands for lose
   and gain; each rate option with its share and band; Aggressive and Too fast still save.
   Shell: the Weight Goal sheet (gear), the Rate and Goal cards, and a "Set a goal" card when
   there is none; ended Weight Goals kept in the Body store.
   - Seam: Body view · Files: `src/SerenixCore/WeightGoal.swift` (new), `BodyView.swift`,
     `BodyViewTests.swift`, `src/SerenixApp/BodyStore.swift`, `src/SerenixApp/BodyScreen.swift`,
     `src/SerenixApp/WeightGoalSheet.swift` (new)
   - Done when: criteria "lose Pace bands at 80 kg", "gain Pace bands at 80 kg", "a Pace in the
     Aggressive or Too fast band can still be saved".
7. [ ] **Slice:** Pace by date. Pace worked out from today's Trend Weight to the date; earliest
   allowed date at 1% a week; quick picks at 0.5% and 0.75%. Shell: date mode in the sheet.
   - Seam: Body view · Files: `WeightGoal.swift`, `BodyView.swift`, `BodyViewTests.swift`,
     `src/SerenixApp/WeightGoalSheet.swift`
   - Done when: criterion "earliest allowed date at 1%; quick picks at 0.5% and 0.75%".
8. [ ] **Slice:** pace badge and Settling in. Settling in while the goal is under 14 Days old or
   Weigh-ins span under 14 Days; then On pace / A bit behind / Off pace / Too fast.
   - Seam: Body view · Files: `BodyView.swift`, `BodyViewTests.swift`, `src/SerenixApp/BodyScreen.swift`
   - Done when: criteria "13 Days old shows Settling in, day 13 of 14", "−0.45 / −0.44 / −0.29 /
     +0.1 at Pace 0.5", "Too fast at 80 kg but On pace at 140 kg".
9. [ ] **Slice:** Ease the goal. Offered after 7 Days in a row Off pace or Too fast, with the
   slower or nearer rate option, or the projected date for a date Pace. Shell: the offer on the
   Rate card, applying it edits the Weight Goal.
   - Seam: Body view · Files: `BodyView.swift`, `BodyViewTests.swift`, `src/SerenixApp/BodyScreen.swift`
   - Done when: criterion "offered after 7 Days; 6 is not enough".
10. [ ] **Slice:** Milestones and progress. Milestones at multiples of 1, 2 or 5 kg (2, 5, 10 lb)
    between Start and Goal Weight; progress %, change since start, to go. Shell: the Milestones
    card and step choice in the sheet.
    - Seam: Body view · Files: `WeightGoal.swift`, `BodyView.swift`, `BodyViewTests.swift`,
      `src/SerenixApp/BodyScreen.swift`, `src/SerenixApp/WeightGoalSheet.swift`
    - Done when: criteria "Milestones 86, 84, 82, 80; 86 and 84 passed at 83.9", "50%, 5.0 kg
      lost, 5.0 to go", and the lb-unit Milestone steps.
11. [ ] **Slice:** Reached, hold and ending goals. Trend Weight reaching Goal Weight marks Reached
    and ends the goal; hold goals with an editable band (In band / Above band / Below band, no
    badge, projection or Milestones); changing direction or removing ends the goal. Shell: the
    celebration and one-tap hold, hold in the sheet.
    - Seam: Body view · Files: `WeightGoal.swift`, `BodyView.swift`, `BodyViewTests.swift`,
      `src/SerenixApp/BodyScreen.swift`, `src/SerenixApp/WeightGoalSheet.swift`, `src/SerenixApp/BodyStore.swift`
    - Done when: criteria "Reached on Trend Weight, not a raw Weigh-in", "hold at 78 ± 1",
      "changing direction ends the goal and keeps it".
12. [ ] **Slice:** projected and planned dates. Projection from Weekly Rate, hidden during
    Settling in or when Weekly Rate is zero or away; planned date; "All" extends to the
    projection. Shell: the Goal card dates and the dashed projection.
    - Seam: Body view · Files: `BodyView.swift`, `BodyViewTests.swift`,
      `src/SerenixApp/BodyScreen.swift`, `src/SerenixApp/WeightChartCard.swift`
    - Done when: criterion "projection hidden …; 10 weeks at 83 kg, Goal 78, −0.5".
13. [ ] **Slice:** JSON backup and import. `BodyDataFile` encodes all Body data (versioned) and
    decodes it; an import adds new entries and skips exact duplicates, with counts; an
    unreadable file returns a typed error and imports nothing. Shell: Export (share sheet) and
    Import (file picker, confirmation) rows in the Profile menu.
    - Blocked by: 11
    - Seam: Body data file · Files: `src/SerenixCore/BodyDataFile.swift` (new),
      `tests/SerenixCoreTests/BodyDataFileTests.swift` (new), `src/SerenixApp/ProfileMenu.swift`,
      `src/SerenixApp/BodyStore.swift`
    - Done when: criteria "export then import gives identical data", "add and skip counts",
      "truncated or wrong-format file imports nothing".
14. [ ] **Slice:** Happy Scale CSV import. **Waits for a real Happy Scale export from the owner**
    (spec open question), which becomes the fixture. Read it into Weigh-ins, ignoring its trend;
    same confirmation and duplicate rule. Shell: the import accepts CSV.
    - Blocked by: 13
    - Seam: Body data file · Files: `BodyDataFile.swift`, `BodyDataFileTests.swift`,
      `tests/SerenixCoreTests/Fixtures/happy-scale-export.csv` (new), `src/SerenixApp/ProfileMenu.swift`
    - Done when: criterion "a real Happy Scale CSV export reads into the expected Weigh-ins".
15. [ ] **Verify:** `swift test` green, `swift format lint --strict --recursive src tests
    Package.swift` clean, `swift build` clean; every `SerenixCore` success criterion in spec 014
    checked. Carried to the PR checklist (need the PR): the macOS CI build, and the by-hand phone
    checks — Body tab and sheets, the other-branch build keeping every Weigh-in and Weight Goal
    (ADR 0008), Height and Units changing display only, export and import on a fresh install.
    - Blocked by: 12, 14

## Done when
- All tasks checked, every success criterion in spec 014 met, suite green.
