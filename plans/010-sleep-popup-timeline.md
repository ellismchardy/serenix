# Plan: 010 — Sleep popup timeline

**For spec:** specs/010-sleep-score.md
**Type:** improvement
**Branch:** feat/sleep-popup-timeline

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
> On approval this file is saved as `plans/010-sleep-popup-timeline.md` (the branch already
> exists, holding the approved spec commit `34d4842`).

## Context
Spec 010 was built (#40) with a plain Sleep popup: a Sleep Score row, three small rings, then a
list of rows. The user picked prototype variant C ("Night timeline", branch
`prototype/sleep-score-popup-ui`) and spec 010 now describes it: a top card with the Sleep Score
and three nested rings, a "When you slept" timeline against the usual times, and a "How much you
slept" bar of Time Asleep against Sleep Need. Only the unticked criteria are planned; the score
formulas are built and stay.

## Approach
`SerenixCore` decides every position and text; the SwiftUI shell only draws (ADR 0002). The
Sleep popup (`SleepPopup` in `src/SerenixCore/Popups.swift`) gains two values:
- `timeline: SleepTimeline?` — nil without Sleep Onset or Final Wake. Holds the axis start/end,
  hour labels (text + position), Sleep Onset and Final Wake (text + position), Time in Bed
  (start/end positions, optional) and usual Sleep Onset / Final Wake (text + position,
  optional). Positions are `(date − axisStart) / (axisEnd − axisStart)`. Axis: earliest drawn
  `Date` floored to the whole local hour, latest ceiled (on-the-hour stays); labels every 2 h of
  absolute time from the start while ≤ end, text = local hour "HH". Calendar in the Today view's
  time zone, as `clockText` already does.
- `sleepNeedBar: SleepNeedBar` — fill = Time Asleep ÷ max(Time Asleep, Sleep Need), marker =
  Sleep Need ÷ that; no Time Asleep → fill 0, marker 1; `asleepText` ("8h 0m asleep", "— asleep"
  as "—"), `neededText` ("needed 8h 0m").

The usual times come from Sleep Score's own medians (spec: never worked out a second way):
`SleepScore` keeps the signed median differences it already computes in `minutesOff(of:…)`
(`src/SerenixCore/SleepScore.swift`), and usual = tonight − difference. Existing text helpers
are reused: `clockText`, `durationText`, `hoursMinutesText`, `missingText`. Time in Bed is drawn
only when both ends exist and end > start (matching `timeInBedDurationText`'s existing rule).

The shell (`src/SerenixApp/TodayPopups.swift`, `SleepPopupView`) is rebuilt as three cards with
`themeCard()`; the nested rings reuse `ScoreRing`'s arc drawing; two new accent shades go in
`src/SerenixApp/Theme.swift` (prototype C's values: light `#B6A5FF`/`#D9CFFF`, dark
`#6E5BC4`/`#463B7A`, the strongest shade outside).

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Prefactor:** `SleepScore` keeps the median signed Sleep Onset and Final Wake
   differences (minutes, nil when Sleep Consistency is left out); `minutesOff` is the mean of
   their sizes. No behavior change.
   - Files: `src/SerenixCore/SleepScore.swift`
   - Done when: existing suite still green.
2. [x] **Slice (tracer):** the Sleep popup's timeline with axis, hour labels, Sleep Onset and
   Final Wake; nil without Sleep Onset. Shell: SleepPopupView becomes the three-card layout
   with the "When you slept" card drawing the axis, hours and the Sleep Period bar (or "No Sleep
   Period for this Night"), the heading with Sleep Consistency's detail, and the caption (Time in
   Bed start–end, minutes awake, Sleep Efficiency's detail). The other two cards keep today's
   content for now.
   - Seam: Today view (`SerenixCore`) · Files: `src/SerenixCore/Popups.swift` (or a new
     `src/SerenixCore/SleepTimeline.swift`), `tests/SerenixCoreTests/SleepScoreTests.swift`,
     `src/SerenixApp/TodayPopups.swift`
   - Done when: criteria "default Night with no Time in Bed: axis 23:00–07:00, hours 23…07",
     "03:00–12:00 Night: axis 03:00–12:00, hours 03…11, Final Wake at 1.0" and "no Sleep Onset:
     no timeline" pass.
3. [x] **Slice:** Time in Bed on the timeline, widening the axis.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift` (or `SleepTimeline.swift`),
     `tests/SerenixCoreTests/SleepScoreTests.swift`, `src/SerenixApp/TodayPopups.swift`
   - Done when: criterion "default Night with Time in Bed 22:40–07:15: axis 22:00–08:00, hours at
     0…1.0, Time in Bed 0.067–0.925, Sleep Onset 0.1, Final Wake 0.9, no usual times, 'Needs 3
     Nights'" passes.
4. [x] **Slice:** usual Sleep Onset and Final Wake on the timeline (from task 1's differences),
   widening the axis; drawn as dashed lines labelled "usual HH:MM".
   - Seam: Today view · Files: as task 3, plus `src/SerenixCore/SleepScore.swift` if the
     differences need exposing to the popup
   - Done when: criteria "23:30–07:40 against 23:00–07:00: usual 23:00 at 0, 07:00 at 0.889,
     axis 23:00–08:00, Sleep Onset 0.056, Final Wake 0.963" and "midnight wrap: usual 23:50 and
     08:10, axis 23:00–09:00" pass.
5. [ ] **Slice:** the Sleep Need bar, and the "How much you slept" card drawing it with
   "asleep"/"needed" texts and Sleep Debt with its caption.
   - Seam: Today view · Files: `src/SerenixCore/Popups.swift`,
     `tests/SerenixCoreTests/SleepScoreTests.swift`, `src/SerenixApp/TodayPopups.swift`
   - Done when: the four "Sleep Need bar" criteria pass (8 h of 8 h: 1.0/1.0; 6 h: 0.75/1.0;
     9 h against 8 h: 1.0/0.889; no Time Asleep: 0/1.0 and "—").
6. [ ] **Slice (shell):** the top card — big Sleep Score number, three nested rings (Sufficiency
   outside) in three accent shades, the key with each part's score; the plain rows list removed.
   No new `SerenixCore` logic: the "missing" criterion (empty rings, every score and detail "—")
   is already covered by `withNoTimeAsleepTheSleepPopupsThreeRingsReadDashAndAreEmpty`; extend
   it to assert each detail is "—" and tick it.
   - Seam: Today view (missing criterion); drawing by hand (ADR 0002) · Files:
     `src/SerenixApp/TodayPopups.swift`, `src/SerenixApp/Theme.swift`, possibly
     `src/SerenixApp/ScoreRing.swift`, `tests/SerenixCoreTests/SleepScoreTests.swift`
   - Done when: the missing criterion passes; the app target compiles in CI.
7. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every unticked spec 010 criterion ticked except those carried to the
   PR checklist: the macOS CI build and the two by-hand phone checks (three cards in Light and
   Dark, no plain rows; fewer than 3 earlier Nights shows the inner ring empty, "Needs 3 Nights"
   and no usual lines). Set spec 010 to `built`.
   - Blocked by: 6

## Done when
- All tasks checked, every success criterion in spec 010 met, suite green.

## Verification
- Each slice: its new test fails first, then `swift test` green.
- End: full suite, lint, build; CI's macOS job builds the `.ipa`; sideload and check the popup
  on the phone against prototype C (`?variant=C`) in Light and Dark.
