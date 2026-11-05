# Plan: 002 — Readiness message reasons ranked by points

**For spec:** specs/002-today-screen.md (Readiness message)
**Type:** improvement
**Branch:** feat/readiness-message-priority

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
`ReadinessAdvice` builds its reasons from the Night's `Readiness.Breakdown`, the same one the
Readiness popup uses: inputs at −`ReadinessWhyRow.verdictPointsThreshold` (3) points or fewer,
stable-sorted by points so ties keep the `Readiness.Input.allCases` order. Reasons:
- HRV and Sleeping HR: as now, from the tiles.
- Time Asleep: "You slept <hoursMinutesText> less than your Sleep Need", from
  `breakdown.sleepShortfall`, rounded to minutes as in `ReadinessWhyRow.reason`.
- Load: "Yesterday's Load was high (<load>)".

"You slept" is lower-cased after the first reason, and `joined` handles four parts. `highLoad`
is deleted. `TodayView` passes `nightReadiness.breakdown`.

## Tasks
1. [ ] **Slice:** the reasons follow the points, and Time Asleep is one of them
   - Seam: `TodayView.readinessAdvice` · Files: `src/SerenixCore/ReadinessAdvice.swift`,
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`
   - Rewrite the Take it easy test around spec 012's "all four off" Night, with the four reasons
     in order. Replace the 54/55 high-Load tests with −3 (named) / −2 (not named) and a tie test.
     The "nothing off" Steady test's Night gets a full Sleep Need.
   - Done when: spec 002's new reasons criteria (all four off; −3 named, −2 not; ties) pass.
2. [ ] **Slice:** a Steady Night with Time Asleep around −8 and HRV −1 names only Time Asleep
   - Files: `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: spec 002's "Time Asleep −8 and HRV −1" criterion passes.
3. [ ] **Docs:** spec 002 example "1 h 10 m" → "1h 10m"; spec 005's Readiness advice notes that
   spec 002 now replaces the 55 mark.
4. [ ] **Verify:** `swift test`, `swift build`, lint green; every new spec 002 criterion ticked.

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
