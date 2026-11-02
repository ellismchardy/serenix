# Plan: 010 — Sleep Score

**For spec:** specs/010-sleep-score.md
**Type:** feature
**Branch:** feat/sleep-score

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
One seam, the Today view (`TodayView`, public), as the spec says. A new pure Sleep Score
function in `src/SerenixCore/SleepScore.swift` takes the Night, the stored Nights, its Sleep
Need (spec 009, already worked out once in `TodayView`) and the time zone, and returns each part
(or left out) and the Sleep Score, or missing. Every constant is named and cites issue #35 and
`docs/research/sleep-score-without-stages.md`; the 7-Night window reuses
`SleepNeed.debtWindowDays`. `TodayView` calls it where it now reads `night?.sleepScore`, for the
ring, the Sleep popup and the Readiness popup's Sleep Score row.

The stored field `Night.sleepScore` is set by hand in about 23 places in
`tests/SerenixCoreTests/TodayViewTests.swift` (ring text and fill, the Sleep popup, the
Readiness popup's Sleep Score row, a missing-score case) to inject a Sleep Score. The shell's
`StoredNight` never had one. Removing it is a wide change, so as with Readiness in plan 008 it
goes **expand → migrate → contract**: task 1 works Sleep Score out only when the Night has no
stored one (a temporary bridge); task 2 rewrites those tests to Nights whose Time Asleep, Sleep
Onset and Final Wake give the Sleep Score they need (hand-worked literals, e.g. 84 and 71), then
deletes the field and the bridge. Same assertions, so no behavior is weakened.

New tests go in a new `tests/SerenixCoreTests/SleepScoreTests.swift`, driven through the Today
view with its own private `todayView` helper, as `SleepNeedTests.swift` does.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer, expand):** Sleep Score from Sleep Sufficiency and Sleep Efficiency —
   Sufficiency (Time Asleep ÷ Sleep Need, capped at 100), Efficiency (95% → 100 down to 75% → 0,
   left out without Sleep Onset or Final Wake or when Time Asleep exceeds the Sleep Period),
   Sleep Consistency always left out for now, re-weighted 0.75 / 0.25, halves-up rounding;
   missing without plausible Time Asleep. `TodayView` uses it for the ring text and fill when the
   Night has no stored Sleep Score (bridge, removed in task 2).
   - Seam: Today view · Files: `SleepScore.swift` (new), `TodayView.swift`,
     `SleepScoreTests.swift` (new)
   - Done when: the score numbers and ring fill of spec 010's criteria "The default Night reads
     100, the ring fills to 1.0", "Time Asleep 6 h … reads 81", "7 h 36 m … reads 96, and the
     ring fills to 0.96", "four earlier Nights of Time Asleep 6 h … reads 92", the four Sleep
     Efficiency criteria (92, 75, 75, 100), and "A Night with no Time Asleep reads '—' with the
     ring empty".
2. [ ] **Migrate and contract:** remove `Night.sleepScore` and the bridge. Every test that set
   `sleepScore:` now builds a Night whose Time Asleep / Sleep Onset / Final Wake give the Sleep
   Score it needs, each input worked by hand and committed as a literal; the Readiness popup's
   Sleep Score row reads the worked-out score.
   - Seam: Today view · Files: `Night.swift`, `TodayView.swift`, `SleepScore.swift`,
     `TodayViewTests.swift` (the `sleepScore:` uses, incl. `sleepScoreShowsItsNumber`, the ring
     fill, Sleep popup and Readiness popup tests), `SleepScoreTests.swift`
   - Done when: criteria "The Readiness popup's Sleep Score row shows the Night's Sleep Score
     ('96' …)" and "No `SerenixCore` type still carries a stored Sleep Score on a Night"; whole
     suite green.
3. [ ] **Slice:** Sleep Consistency — the Nights dated D − 7 to D − 1 with both Sleep Onset and
   Final Wake; per time, the signed shortest-way-round difference from each (−12 h to +12 h),
   the size of their median; the mean of the two; 100 at 0 minutes down to 0 at 2 h; left out
   with fewer than 3 such Nights or when the Night shown lacks either time; weights 0.6 / 0.2 /
   0.2. Clock times are local in the Today view's time zone.
   - Seam: Today view · Files: `SleepScore.swift`, `SleepScoreTests.swift`
   - Done when: the Sleep Score numbers of the six Sleep Consistency criteria (100, 94, 80, the
     midnight 98, the two/three-Nights cases at 100, and the 8 Nov / 7 Nov window).
4. [ ] **Slice:** the Sleep popup's part rings — `SleepPopup` gains the three parts, each with
   its whole-number score text (or "—"), ring fill and detail ("6h 0m of 8h 0m", "89% asleep",
   "35m off your usual", "Needs 3 Nights", "—"); with Sleep Score missing all three read "—".
   The shell's Sleep popup view draws three small `ScoreRing`s in the accent colour under the
   Sleep Score row, with names and details.
   - Seam: Today view · Files: `Popups.swift` (`SleepPopup`), `TodayView.swift`,
     `SleepScore.swift`, `SleepScoreTests.swift`, `src/SerenixApp/TodayPopups.swift`,
     `src/SerenixApp/ScoreRing.swift` (a size option, if it has none)
   - Done when: the popup parts of every criterion that names them (default: "100" / "8h 0m of
     8h 0m", "100" / "100% asleep", "—" / "Needs 3 Nights"; "75" / "6h 0m of 8h 0m"; "89" /
     "8h 0m of 9h 0m"; "69" / "89% asleep"; "0"; "—" / "—"; "100" / "0m off your usual"; "71" /
     "35m off your usual"; "0" / "2h 0m off your usual"; "92" / "10m off your usual"; "Needs 3
     Nights"; and the three "—" with Sleep Score missing).
5. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every automated success criterion in spec 010 checked.
   - Done when: the above pass and the criteria are ticked. Carried to the PR checklist (they
     need the PR): the macOS CI build, and by hand on the phone — past Nights show a Sleep Score
     on the ring and the Sleep popup shows three small rings with details; a Night after fewer
     than 3 earlier Nights shows Sleep Consistency empty with "Needs 3 Nights".

## Done when
- All tasks checked, every success criterion in spec 010 met, suite green.
