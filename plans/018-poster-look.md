# Plan: 018 — Poster look

**For spec:** specs/018-poster-look.md
**Type:** feature
**Branch:** feat/poster-look

> Disposable. Once every task is merged, move this file to plans/done/.
> Before the first `/execute`, fast-forward `feat/poster-look` (checked out in worktree
> `pensive-nash-4fa6c8`) to the commit that adds this plan, with `git merge --ff-only`.

## Context
Spec 018 restyles Today, Sleep, Body and their popups and sheets in prototype concept M: a
Swiss-poster look with a headline number and a short verdict on every tab. The core gains one
pure verdict mapping; everything else is shell drawing, checked by hand on the phone (ADR 0002).

Decisions taken while planning (user, 2026-11-14):
- **Today:** the Rings layout *becomes* concept M as the spec's Today section describes (no ring
  graphics). Story keeps its timeline, drawn in the Poster look, under the same Readiness
  headline.
- **"TONIGHT."**: the Sleep headline on **today** with no Night yet; an earlier Day with no
  Night gives "NO NIGHT.".
- **Metric "N TO GO."**: N = `Baseline.minEarlierNights` (3) − earlier Nights, matching spec
  011's "(n so far)". Readiness keeps n/4 (N = 4 − Nights so far).
- **Sleep tab** follows the spec as written: three columns (Time Asleep, Sleep Need, Sleep
  Debt, values already worked out for the Sleep popup), the shown Night's chart as its own
  section, and the spec's section order. Lane taps keep working.

## Approach
**Core.** A `Verdict` value in `src/SerenixCore/Verdict.swift`: `text` (capitals, full stop)
and `kind` (`.state` / `.waiting`). Each view that owns a headline gains one public verdict
field, worked out from values it already has, so the shell only draws:
- `TodayView.readinessVerdict` from `night`, `calibratingNightsSoFar` (TodayView.swift:115,
  now kept), `readinessBand` and the local `hasHRV` (:256).
- `SleepView.sleepScoreVerdict`: SleepView has no score today. It gains the Sleep Score (built
  with `SleepScore(of:among:sleepNeed:timeZone:)` as TodayView.swift:131 does) and whether the
  Day is today (from its week strip). Thresholds 67 / 34 are named constants citing the spec.
- `BodyView.weightVerdict` from `trendWeight`, `goalCard.status` (`PaceStatus`, `PaceBadge`)
  and `goalCard.holdState` (WeightGoal.swift:407, :417, :607).
- `FoodView.intakeVerdict` from `intake.kilocalories`, `calorieTarget` (already the applied
  one under Adapt, FoodView.swift:152), `isComplete`, `entries`, and a new `today: Day` input
  (FoodView has no notion of today; FoodScreen.swift:33 works it out). ±10% is a named
  constant.
- `LoadPopup.verdict` reusing the bands `easierBelow` / `harderFrom` / `muchHarderFrom`
  (Popups.swift:759) and the same order as `comparisonText` (:768): no typical Load first, then
  no Load.
- `MetricPopup.verdict` following `verdict(_:value:)`'s order (Popups.swift:500): missing →
  SpO2 → Calibrating → Zone. A nil Zone with a formed Baseline gives none.

Tests sit in each view's existing test file (TodayViewTests, SleepViewTests, BodyViewTests,
FoodViewTests, LoadPopupTests, plus a Metric popup block in TodayViewTests), reusing their
helpers (`todayView(...)`, `calibratedNightsBeforeNov1`, `sleepView(...)`, `bodyView(...)`,
`foodView(...)`, `fourDaysBeforeNov1`). Expected texts are the spec's literals.

**Shell: expand → migrate → contract.** Task 1 adds the Poster pieces in a new
`src/SerenixApp/Poster.swift` beside the old `Theme`: palette (light paper `#F2F0EB`, ink
`#111111`, red `#E3241B`, green `#138A4B`, amber `#C27C0E`, hairline `#C9C6BD`, track
`#DEDAD0`, secondary `#555555`, waiting `#8A877E`; dark paper `#0B0B0B`, ink `#F2F0EB`,
hairline `#2A2A2A`, red/green/amber unchanged), as dynamic `UIColor`s like Theme.swift:34;
type scale on system SF (heavy, condensed italic via `.width(.condensed)`); rule widths
(6 / 2 / 1 pt). Shared views: `Masthead`, `RuledSection` (name left, note right), `PosterTag`
(white on colour), `PosterHeadline` (number, verdict in red or waiting grey, caption),
`PosterBar` (track, fill, optional tick), `SegmentedBar`, `BlockButton`. Screens migrate one
task at a time; the last shell task deletes `Theme`'s purple tokens, `themeCard`, `popupCard`
and the ring views nothing uses any more.

Popups stay system sheets (TodayPopups.swift:47) with the Poster paper as
`presentationBackground`, a short heavy grab bar and the masthead.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice (tracer bullet):** `Verdict` and the Readiness verdict; the Poster pieces; the
   Today headline. Core: `Verdict`, `TodayView.readinessVerdict`. Shell: `Poster.swift`; the
   ScreenChrome top bar becomes the masthead ("Serenix · Today", Day on the right; the avatar,
   calendar and bell kept as small ink icons in it); Today draws `PosterHeadline` (n/4 while
   Calibrating) with the verdict.
   - Seam: verdict mapping (TodayView) · Files: `src/SerenixCore/Verdict.swift` (new),
     `src/SerenixCore/TodayView.swift`, `tests/SerenixCoreTests/TodayViewTests.swift`,
     `src/SerenixApp/Poster.swift` (new), `src/SerenixApp/ScreenChrome.swift`,
     `src/SerenixApp/TodayScreen.swift`
   - Done when: criterion "Ready, Steady, Take it easy … 2 TO GO., NO HRV., NO NIGHT." and the
     state/waiting marking for these.
   - Built: no Night is checked before Calibrating; "NO HRV." uses the Night's HRV (0 counts as
     none), and Readiness missing with HRV present gives no verdict. The button style is
     `BlockButtonStyle`. Until task 2, Rings shows Readiness twice (headline and ring). The
     masthead dropped spec 002's greeting; the user chose to drop it for good (2026-11-14), so
     task 13 removes the unused greeting code.
2. [x] **Slice:** Today's Rings layout as concept M: Load section (`PosterBar` 0 to 2× typical
   Load, tick at typical, spec 006 sentence as note; number alone while typical Load is
   learned), Sleep Score and Time Asleep side by side, Nightly Metrics and Resting HR as rows
   with Zone tags, the Readiness message as a ruled section with ✕, week strip restyled. Taps
   open the same popups.
   - Seam: hand check · Files: `TodayScreen.swift`, `WeekStripView.swift`,
     `MetricTileView.swift`, `BaselineComparisonRow.swift`, `src/SerenixCore/TodayView.swift`
     only if the Today Load bar needs a public fill (reuse `LoadPopup.loadBarFill`'s rule)
   - Done when: phone criterion "Today's Load section … tick at typical Load … number alone".
   - Built: no core change (the bar uses `LoadPopup.loadBarFill`; tick at 0.5 as the Load popup
     does). "vs your Baseline" rows dropped: each metric row's tag carries the difference, and
     the Calibrating line is the section's note. Without a Night: no Sleep Score / Time Asleep
     section, and Resting HR under a "Resting HR" heading. Tile views and
     `BaselineComparisonRow` deleted; `NightlyMetric.icon` and `Zone.colour` (now Poster
     colours) moved to `MetricLook.swift`. `ReadinessBand.colour` stays system colours until
     task 13.
3. [x] **Slice:** Story in the Poster look under the Readiness headline: timeline as ruled rows,
   dots in ink/red/Zone colours, Zone pills as `PosterTag`, Load bar as `PosterBar`.
   - Files: `StoryBodyView.swift`, `TodayScreen.swift`
   - Done when: phone criterion for Today (Story) in Light and Dark.
   - Built: each step sits under a heavy rule like a section, square dots on a hairline; the
     Sleep Score ring became a 40 pt number labelled "SLEEP SCORE". No change to
     `TodayScreen.swift` was needed. `ScoreRing` now has no callers (task 13); This morning's
     dot uses `ReadinessBand.colour`, still system colours until task 13.
4. [x] **Slice:** the block tab bar: Today, Sleep, Body as three equal cells under a heavy
   rule, the current one solid ink with paper text (custom bar over the tab content, replacing
   `TabView`'s `.tabItem`).
   - Blocked by: 1 · Files: `MainTabs.swift`, `Poster.swift`
   - Done when: phone criterion "block tab bar" on all three tabs.
   - Built: `TabView(selection:)` kept with its bar hidden on each tab, the Poster bar under
     it, so each tab keeps its state. Re-tapping the current tab no longer pops Body back from
     All Weigh-ins (spec 012 never asked for it). PR checklist: the system bar stays hidden
     after pushing All Weigh-ins and on tab switches; no content cut off above the bar. Spec
     012's Tab bar paragraph ("never a hand-drawn imitation", Non-goal "A custom tab bar")
     now contradicts spec 018; raised with the user.
5. [x] **Slice:** Sleep Score verdict and the Sleep headline: `SleepView` gains the Sleep Score
   and `sleepScoreVerdict` (TONIGHT. today without a Night); the tab draws the headline (caption
   spec 012's Summary sentence) and Time Asleep, Sleep Need, Sleep Debt in three columns (Debt
   red over zero).
   - Blocked by: 1 · Seam: verdict mapping (SleepView) · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: criterion "Sleep Score 67, 34, 33 … NO NIGHT., TONIGHT.".
   - Built: `Verdict.sleepScore(_:)` is public so `VerdictTests.swift` (new) can test the band
     edges; `SleepView` gains `sleepScoreVerdict`, `sleepScoreText` (one source for number and
     verdict) and `hasSleepDebt`. The Summary card became the headline, captioned
     "<label>: <sentence>", then the three columns and Sleep Onset – Final Wake; the columns
     show only with a Night (PR checklist). The column texts still come from the Sleep popup.
6. [x] **Slice:** Sleep sections in the Poster look and the spec's order: the shown Night's chart
   as its own section (Heart Rate Trace red, Wake Bouts amber columns, dotted Sleeping HR), Your
   week (solid bars, short Time Asleep amber), What stood out (rows with tags), Tonight (solid
   ink block).
   - Files: `SleepScreen.swift`
   - Done when: phone criterion for Sleep in Light and Dark; lane taps still open.
   - Built: the shown Night's chart section uses `SleepWeek.firstOpenLane` (doc reworded), so no
     lane opens by itself; tapping the shown Night's lane still repeats its chart under it.
     What stood out has no tags: the user dropped them from spec 018 (2026-11-14), and also
     had spec 018 say it replaces spec 012's tab bar and first open lane, and state the section
     order as built.
7. [x] **Slice:** Weight verdict and Body Weight screen: `BodyView.weightVerdict`; Weight | Food
   segmented bar, masthead "Serenix · Body", headline, chart, Rate and Goal columns, Hold,
   Milestones bar, No Weight Goal section, All Weigh-ins row (spec's *Weight* list).
   - Blocked by: 1 · Seam: verdict mapping (BodyView) · Files: `src/SerenixCore/BodyView.swift`,
     `tests/SerenixCoreTests/BodyViewTests.swift`, `BodyScreen.swift`, `WeightChartCard.swift`
   - Done when: criterion "Each pace badge and hold state … SETTLING IN., NO GOAL., NO WEIGH-IN."
     and phone criterion for Body Weight's columns, Hold and Milestones.
   - Built: `Verdict.pace(_:)` / `hold(_:)` are public, tested in `VerdictTests.swift`;
     `BodyView.weightVerdict` is tested for each waiting case, Settling in, On pace, In band and
     the no-verdict case. Milestone cells scroll when they don't fit. The chart still dashes
     Goal Weight (now green): spec 018's "next Milestone dashed in green" contradicts its own
     "nothing a tab shows changes"; wording fix raised with the user. `BandLabel` (the Goal
     column's Pace band tag) moves to `PosterTag` in task 9 with `WeightGoalSheet.swift`.
8. [x] **Slice:** Intake verdict and the Food view: `FoodView` takes `today`, gains
   `intakeVerdict`; the spec's *Food* list (Day row, headline and caption lines incl. the
   Expenditure line, calorie bar, macro rows, Day complete row, Food Entry rows, red Log button).
   - Seam: verdict mapping (FoodView) · Files: `src/SerenixCore/FoodView.swift`,
     `tests/SerenixCoreTests/FoodViewTests.swift`, `ExpenditureTests.swift` (call sites only),
     `FoodScreen.swift`
   - Done when: criteria "Intake at 90%, 110%, 89%, 111% …" and "With Adapt on … 2,000 …
     ON TARGET. … Adapt off UNDER.", and phone criterion for Body Food.
   - Built: `today` is optional on `FoodView` (nil treats the Day shown as past), so
     `ExpenditureTests` / `MacroTargetsTests` stay untouched; the shell passes the one today it
     reads. "LOGGED." (no Calorie Target) is a state verdict, as the criteria mark only LOGGING.
     and NOTHING LOGGED. waiting; it wins over LOGGING. (tested). Body headlines share
     `Poster.bodyHeadlineSize`.
9. [x] **Slice:** the sheets in the Poster look: Targets (spec's *Targets sheet* list, Activity
   Level as a four-cell `SegmentedBar`, floor message amber with Ease the goal / Change my
   Pace), Weigh-in, Weight Goal (segmented pickers, Pace band tags), Food Entry; primary button
   ink block, destructive red.
   - Files: `FoodTargetsSheet.swift`, `FoodEntrySheet.swift`, `WeightGoalSheet.swift`,
     `BodyScreen.swift` (WeighInSheet), `WeighInList.swift`
   - Done when: phone criterion for the targets sheet; Ease the goal, Change my Pace and Day
     complete still work.
   - Built: `posterForm()` / `posterRows()` put each form on the paper with hairline rows;
     Save is a solid ink block and Remove goal / Delete Food Entry red blocks at the foot of
     each form (`SheetActions`), Cancel stays in the toolbar. `SegmentedBar` gains a VoiceOver
     `label`. `BandLabel` uses `PosterTag`; `CapsuleTag` deleted. The Hold band picker stays a
     system menu picker. PR checklist: 0.5% and 0.75% each set their own date. Open: whether
     the four sheets also get the popups' grab bar and masthead (spec 018 lists Sheets under
     Popups) — raised with the user; task 10 can add them.
10. [x] **Slice:** Load popup verdict and the popup chrome: `LoadPopup.verdict`; every popup
    gets Poster paper, grab bar and masthead (popup name left, Night or Day right); the Load
    popup's sections ruled (bar vs typical, How hard split bar and HR Zone rows, When hourly
    bars, Highest HR / Max HR used); Live HR keeps its place.
    - Blocked by: 1 · Seam: verdict mapping (LoadPopup) · Files: `src/SerenixCore/Popups.swift`,
      `tests/SerenixCoreTests/LoadPopupTests.swift`, `TodayPopups.swift`
    - Done when: criterion "Load popup's verdict … EASIER DAY. … LEARNING. … NO LOAD.".
    - Built: a private `Comparison` in `LoadPopup` gives the sentence and the verdict one set of
      bands; `LoadPopup.typicalLoadTick` is public and used by Today and the popup. The
      masthead's right side is each popup's own wording ("Today" on today's Load popup, the
      metric's Night text, Resting HR's Day) or the Day shown; the old popup headings are gone.
      While typical Load is learned the popup shows no bar (the headline has the Load), so
      `learningLoadText` is unused (task 13). HR Zones are grey, blue, green, amber, red
      (prototype M). PR checklist: VoiceOver can still close a popup with the system drag
      indicator hidden.
11. [x] **Slice:** Nightly Metric verdict and the Metric and Resting HR popups:
    `MetricPopup.verdict` (ABOUT USUAL. / UNUSUAL. / WAY OFF.; SpO2 HEALTHY. / A BIT LOW. /
    LOW.; N TO GO. against 3 earlier Nights; NO DATA.); Zone scale flat segments with marker and
    Baseline tick, Last 14 Nights blocks, three fact columns. Resting HR: no verdict.
    - Seam: verdict mapping (MetricPopup) · Files: `Popups.swift`, `TodayViewTests.swift`,
      `TodayPopups.swift`
    - Done when: criterion "A Nightly Metric popup's verdict …".
    - Built: a private `Reading` in `MetricPopup` decides once for spec 011's sentence and the
      verdict (no Zone against a formed Baseline gives none, tested). The sentence is the
      headline's caption with its last words in the Zone colour, the status word a tag under
      it; the Zone section shows only with a scale. Resting HR: headline with its sentence, no
      verdict. Blocks, facts, What it is, Your Zones and What moves it are ruled sections.
12. [ ] **Slice:** Readiness and Sleep Score popups in the Poster look: band scale flat
    segments with marker and "usual 70" tick, Why rows with tags and thin gauges, Your week flat
    bars; Sleep Score parts as rows with big number and thin bar (no nested rings), Time Asleep
    red bar with Sleep Need marker, Sleep Period timeline (Time in Bed grey, usual times dashed
    green). Headlines reuse tasks 1 and 5's verdicts.
    - Blocked by: 5, 11 · Files: `TodayPopups.swift`
    - Done when: phone check of both popups in Light and Dark.
13. [ ] **Contract:** delete `Theme`'s purple tokens, `themeCard`, `popupCard`, `ScoreRing` /
    `RingArc` if unused; point Onboarding, ProfileMenu, DebugView and SyncPillView's remaining
    Theme uses at the Poster palette; app-wide tint to ink. `grep` finds no `Theme.accent`.
    Remove the greeting the masthead replaced (user, 2026-11-14): `TodayView.greeting` /
    `greetingName`, `Profile.greeting(at:in:)` and their tests (`ProfileTests.swift`,
    `TodayViewTests.swift`), as the spec no longer shows it. Also remove core fields nothing
    draws any more (check with grep first; Story may still use some): `VsBaseline`
    comparisons, `TodayView.readinessFill` / `loadFill` / `sleepScoreFill`, the tiles'
    `gauge`, and their tests; rename `gridTiles` to rows. Files add
    `src/SerenixCore/TodayView.swift` and its tests.
    - Blocked by: 3, 4, 6, 9, 12 · Files: `Theme.swift`, `SerenixApp.swift`,
      `OnboardingScreen.swift`, `ProfileMenu.swift`, `SyncPillView.swift`, `ScoreRing.swift`
    - Done when: phone criterion "no rounded cards or shadows, and no purple anywhere".
14. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
    `swift build` green; every core success criterion checked; each verdict asserted as state
    or waiting.
    - Blocked by: 13
    - Carried to the PR checklist: macOS CI app build; the phone checks in Light and Dark (Today
      Rings and Story, Sleep, Body Weight, Body Food, targets sheet, every popup, every tap that
      opened a popup or sheet before).

## Verification
- Core: `swift test` runs every verdict case at the spec's literals; `swift format lint
  --strict` and `swift build` clean on Windows.
- Shell: macOS CI builds the `.ipa`; sideload and walk the PR checklist on the phone in Light
  and Dark, with Appearance switched between them.

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
