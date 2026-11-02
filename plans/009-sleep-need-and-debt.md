# Plan: 009 — Sleep Need and Sleep Debt

**For spec:** specs/009-sleep-need-and-debt.md (and the unchecked criteria in specs/008-readiness.md)
**Type:** feature
**Branch:** feat/sleep-need-and-debt

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
One seam, the Today view (`TodayView`, public), as both specs say. A new pure Sleep Need function
in `src/SerenixCore/SleepNeed.swift` takes the Night's Day, the stored Nights and the birth year
and returns Usual Need, Sleep Debt, Sleep Need and how many Nights counted. Every constant is
named and cites issue #34 and `docs/research/sleep-need-and-debt.md`. `TodayView` works it out
once for the Day shown and hands it to the Sleep popup (two new rows) and, in the last slice, to
Readiness and the Readiness popup in place of `Readiness.timeAsleepMark`. Nothing is stored, so
`StoredNight` and SwiftData don't change; the shell only passes `profile.birthYear` into the
Today view and draws the two new Sleep popup rows.

The Readiness switch (task 4) changes numbers existing tests rely on. In
`tests/SerenixCoreTests/ReadinessTests.swift` the default Night is 7 h and the earlier Nights
have no Time Asleep; spec 008 now makes both 8 h, so the fixture changes and the Time Asleep,
"all four off" and popup-row tests take the spec's new literals. In
`tests/SerenixCoreTests/TodayViewTests.swift`, `readinessShowsItsNumberAndBand` picks HRV,
Sleeping HR and Time Asleep to land exactly on 100 / 67 / 66 / 34 / 33 / 1 against the 7 h mark;
its Time Asleep values are re-worked by hand against Sleep Need 8 h so each row still lands on
the same number and band (same assertions, new inputs). Any other Today view test whose
Readiness moves is re-derived the same way.

New tests go in a new `tests/SerenixCoreTests/SleepNeedTests.swift`, driven through the Today
view with its own private `todayView` helper, as `ReadinessTests.swift` does.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer):** Sleep Need from Usual Need alone — Usual Need 8 h, Sleep Debt 0, Sleep
   Need 8 h; the Sleep popup gains Sleep Need and Sleep Debt rows after Time Asleep, with the
   caption "No earlier Nights"; the shell's Sleep popup view draws the two rows.
   - Seam: Today view · Files: `SleepNeed.swift` (new), `Popups.swift` (`SleepPopup`),
     `TodayView.swift`, `SleepNeedTests.swift` (new), `src/SerenixApp/TodayPopups.swift`
   - Done when: spec 009 criterion "With no earlier Nights, the Sleep popup shows Sleep Need
     '8h 0m', Sleep Debt '0h 0m' and 'No earlier Nights'".
2. [x] **Slice:** Sleep Debt — the Nights dated D − 7 to D − 1 (D left out), skipping Nights with
   no plausible Time Asleep; the sum of (Usual Need − Time Asleep), floored at 0; Sleep Need =
   Usual Need + ¼ of Sleep Debt, capped at +1 h; the caption "Your last N Nights" / "Your last
   1 Night".
   - Seam: Today view · Files: `SleepNeed.swift`, `Popups.swift`, `SleepNeedTests.swift`
   - Done when: spec 009 criteria "6 h and 9 h … '1h 0m' … '8h 15m'", "Four earlier Nights of
     6 h … '9h 0m' (capped)", "all 9 h … '0h 0m' … '8h 0m'", "The Night shown with no Time
     Asleep still shows … '8h 15m'", the three Window and skipping criteria, and "Adding an
     earlier Night of 6 h on 14 Nov … '8h 30m'".
3. [x] **Slice:** Usual Need by age — `TodayView` gains a `birthYear` input (default nil, so
   existing callers and tests don't change); 7.5 h when D's year minus the birth year is 65 or
   more; the shell passes `profile.birthYear`.
   - Seam: Today view · Files: `SleepNeed.swift`, `TodayView.swift`, `SleepNeedTests.swift`,
     `src/SerenixApp/TodayScreen.swift`
   - Done when: spec 009 criteria "Birth year 1961 … '7h 30m'; 1962 … '8h 0m'", "Birth year
     1961 with one earlier Night of 6 h 30 m … '1h 0m' … '7h 45m'", and "The same Nights give
     Sleep Need '8h 0m' with no birth year and '7h 30m' with birth year 1961".
4. [ ] **Slice:** Readiness against Sleep Need — `Readiness.score` takes the Night's Sleep Need
   in place of `timeAsleepMark` (constant removed); the Readiness popup's Time Asleep row shows
   Sleep Need as its reference ("8h 0m") and the difference against it. Rewrites the tests that
   used the 7 h mark, as described in Approach.
   - Seam: Today view · Files: `Readiness.swift`, `Popups.swift` (`ReadinessPopupRow`),
     `TodayView.swift`, `ReadinessTests.swift`, `TodayViewTests.swift`
     (`readinessShowsItsNumberAndBand` and any other Readiness literal that moves),
     `SleepNeedTests.swift`
   - Done when: spec 008's unchecked criteria (Time Asleep 6 h → 54, 7 h 59 m → 70, 10 h → 70;
     all four off → 7; the popup's Time Asleep row "7h 30m", "8h 0m", "−30m" / "+1h 10m" /
     "±0"); spec 009's Readiness criteria (62 with "8h 0m", "9h 0m", "−1h 0m"; 66, Steady);
     whole suite green.
5. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every automated success criterion in specs 009 and 008 checked.
   - Done when: the above pass and the criteria are ticked. Carried to the PR checklist (they
     need the PR): the macOS CI build, and by hand on the phone — the Sleep popup's Sleep Need
     and Sleep Debt rows match the Nights before; setting a birth year 65+ years back lowers
     Sleep Need by 30 m straight away and the Readiness popup's reference follows (spec 009);
     spec 008's two phone checks still hold.

## Done when
- All tasks checked, every success criterion in specs 009 and 008 met, suite green.
