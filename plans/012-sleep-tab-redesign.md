# Plan: 012 — Sleep tab redesign (variant E) and the iOS 26 tab bar

**For spec:** specs/012-sleep-tab.md
**Type:** improvement
**Branch:** feat/sleep-screen

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
>
> The branch is the one the first build is on (PR ellismchardy/serenix#43, not yet merged): the
> user chose to rework the PR rather than merge the stacked layout first. The first build's plan
> is `plans/done/012-sleep-tab.md`.

## Approach
Only the unticked criteria are planned; the Heart Rate Trace, Wake Bouts, one-off rebuild queue,
Sleeping HR line and y-axis rules already exist and keep their tests. The spec change was
committed with the spec (`git diff 2e99b38 -- specs/012-sleep-tab.md` shows it). The Sleep view's
shape changes from Tonight / Last night / Your week to Summary / Your week (lanes, each with its
Night's chart) / Tonight / What stood out. Each slice adds or reshapes one part of the Sleep view
at its seam and redraws that part in `SleepScreen`, so the tab works after every task. Where a
part replaces an old one (Last night's header, the two week charts, the old Tonight texts), the
slice rewrites or removes the old tests as part of its red→green cycle. The tab bar needs no code:
building with Xcode 26 gives SwiftUI's tab view the floating glass look, so it's a CI change.
Existing Sleep view code: `src/SerenixCore/SleepView.swift` (`SleepView`, `SleepTonight`,
`SleepWeek`/`SleepWeekDay`, `SleepLastNight`, `SleepChart`), drawn by
`src/SerenixApp/SleepScreen.swift`.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Chore: build the app with Xcode 26.** Point the macOS CI job at Xcode 26 and the iOS 26
   SDK (a `macos-26` runner, or `xcode-select` to Xcode 26 on `macos-15`: confirm which image has
   it from GitHub's runner-images readme), keeping the iOS 17 deployment target. Amend ADR 0003's
   build setup with a dated note. Fix anything Xcode 26's Swift compiler rejects in the shell.
   - Seam: none in `SerenixCore` (CI configuration; spec's Build criterion) · Files:
     `.github/workflows/ci.yml`, `docs/adr/0003-ci-builds-and-sideloading-instead-of-a-mac.md`,
     `src/SerenixApp/` only if the new compiler needs it.
   - Done when: the workflow selects Xcode 26 and `swift test` / lint / build are still green.
     The CI log naming `iPhoneOS26` is checked on the next push (carried to the PR checklist).
2. [x] **Slice: Summary.** `SleepView.summary`: the label ("Last night" or the date), the
   sentence against the Night's own Sleep Need (short / about / more, 15-minute named constant;
   the gap as "45 minutes" under an hour and "1h 51m" from an hour; no Time Asleep) and
   "23:00 – 07:00"; the no-Night message in its place. The
   Sleep screen draws it as the first card under the week strip, with its Sleep Score › button
   opening the Sleep popup, in place of Last night's title and "7h 45m asleep" header.
   - Blocked by: none
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the five Summary criteria pass; Last night's old title and "asleep" text tests
     are rewritten to the Summary's.
3. [ ] **Slice: Your week lanes.** Reshape `SleepWeek` into lanes: D first, then back to D − 6,
   named "Last" / weekday short names / "no Night"; each Night's bar segments (Sleep Onset to
   Final Wake split at Wake Bouts), its Time in Bed track, its Time Asleep text and short flag
   (15 min or more under its own Sleep Need); the 20:00–10:00 axis widened to whole hours with
   labels every 2 hours; the title text ("avg 7h 20m · Sleep Debt 2h 0m", or just "Your week");
   and which lane opens first. The Sleep screen draws the lanes card in place of the Time Asleep
   against Sleep Need and When you slept charts (no opening yet).
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the seven Your week criteria and "Its bar runs 23:00–02:10, 02:18–04:30 and
     04:37–07:00, on a track 22:50–07:10" pass; the old week-slot and bar tests are rewritten.
4. [ ] **Slice: a lane's chart.** Each Night's lane carries its chart (moved from
   `SleepLastNight`): range, steps, Sleeping HR line, y-axis, plus bpm gridlines (every 5, every
   10 over a 30 bpm span), hour ticks every 2 hours inside the range, the "Woke 2 times · 15 min
   awake" text, or the not-kept note (and no bar gaps). The Sleep screen opens and closes a lane
   on tap (one at a time, reset to the first open lane when the Day shown changes), draws the
   trace as a smooth line with a soft fill and the Sleeping HR label under its right end, shades
   Wake Bouts and draws the gapped band, and a Sleep Score › button under it. `SleepLastNight`
   and its "In bed · Up" text and Wake Bout list go.
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the lane-and-chart criteria pass (chart range and hour ticks, gridlines, band
     and "Woke" text, no Time in Bed, no Heart Rate Trace); the already-ticked Sleeping HR,
     y-axis and "Woke 1 time" tests pass against the lane's chart; the old Last night tests are
     moved or removed.
5. [ ] **Slice: Tonight card and lane.** `SleepTonight` becomes the sentence "To get 8h 0m before
   your usual 07:00 wake, be asleep by 23:00." (or the "after 3 Nights" text) and the Tonight
   lane's range (Be asleep by to the usual wake, none without a bedtime). The Sleep screen draws
   the dashed Tonight lane at the top of Your week and the purple Tonight card under it.
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the four unticked Tonight criteria pass, and "With 2 Nov shown, there is no
     Tonight" still does; the old Be asleep by / Sleep Need / usual wake / Sleep Debt text tests
     are rewritten.
6. [ ] **Slice: What stood out.** `SleepView.standouts`: up to three rows for the Night dated D
   (Wake Bouts with their times, bedtime against the usual Sleep Onset of D − 7 to D − 1 with
   the 30-minute named constant and 3-Night minimum, heart rate settled to the Sleeping HR),
   each left out when its data is missing; none without a Night. The Sleep screen draws the card
   last.
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the three What stood out criteria pass.
7. [ ] **Verify:** full suite + lint + typecheck green; every automated success criterion in
   spec 012 checked; nothing left of `SleepLastNight` or the old week charts. Carried to the PR
   checklist (need a push and the phone): the CI log naming `iPhoneOS26`, and the six by-hand
   phone checks (tab bar and shared Day, the floating tab bar, popups and menus under the new
   SDK, the new Sleep tab order and lane opening, the rebuilt Nights and not-kept note, and the
   Sleep Score buttons).
   - Blocked by: 1, 6

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
