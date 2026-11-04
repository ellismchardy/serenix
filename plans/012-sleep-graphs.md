# Plan: 012 — Sleep tab graphs restyle (graphs prototype variant E)

**For spec:** specs/012-sleep-tab.md
**Type:** improvement
**Branch:** feat/sleep-screen

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.
>
> Same branch as the first build and the redesign (PR ellismchardy/serenix#43, not yet merged),
> so the restyle ships with them. Earlier plans: `plans/done/012-sleep-tab.md`,
> `plans/done/012-sleep-tab-redesign.md`.

## Approach
Only the six unticked criteria under "A Night's lane and chart" are planned (the rest of spec
012 is built); `git diff 2e99b38..HEAD -- specs/012-sleep-tab.md` won't isolate it, so use
`git show 9c88c5a -- specs/012-sleep-tab.md` for exactly what changed. The look comes from
`prototype/sleep-graphs`, variant E. Three slices, each at the Sleep view seam and redrawn in
`SleepScreen`: the lane (one block with Wake Bout notches instead of gapped segments), the
chart's smoothed values (Core) drawn as a monotone curve (shell), then the chart's one-picture
layout (asleep shading with labels, "52 bpm" tag, no gridlines, no band row). Each slice
rewrites the tests for the look it replaces, as the spec now asks. All three touch the same
files, so they run in order.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice: the lane's block and notches.** `SleepLane.asleepSegments` becomes
   `asleep: DateInterval?` (Sleep Onset to Final Wake, unbroken) and `wakeNotches:
   [DateInterval]` (each Wake Bout, clamped to the block; empty without a Heart Rate Trace or
   with Wake Bouts not kept). The Sleep screen draws the Time in Bed track, the block shaded
   from the lighter accent to the accent, and amber notches standing above and below it.
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: "Its block runs 23:00–07:00, unbroken, with notches at 02:10–02:18 and
     04:30–04:37, on a track 22:50–07:10" and the not-kept criterion ("its block has no
     notches") pass; the old `asleepSegments` tests are rewritten.
2. [x] **Slice: the chart's smoothed values.** Each `SleepChartStep` gains `smoothedBPM:
   Double?`: the Gaussian-weighted mean of the steps within 3 either side (weight
   e^(−d²/(2·1.6²))), missing steps left out, a missing step staying missing; reach and width
   are named constants. The y-axis keeps using the steps as kept. The Sleep screen draws the
   smoothed values as a monotone (Fritsch–Carlson) curve in place of the Catmull-Rom line.
   - Blocked by: 1
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the smoothed-values criterion passes (63.58 / 62.95 / 61.64 / 60.62 / 60, the
     missing step, and the 57–77 axis).
3. [x] **Slice: the chart as one picture.** `SleepChart` drops `gridlines`, gains the asleep
   labels ("asleep 23:00", "07:00") and changes `sleepingHRLabel` to the "52 bpm" tag. The Sleep
   screen draws, in the accent colour: the asleep shading behind everything with its labels,
   Wake Bout columns, the curve with a fill fading to the chart's foot, the dotted Sleeping HR
   line with its tag, and the hour ticks under the chart; the separate band row and bpm labels
   go.
   - Seam: Sleep view · Files: `src/SerenixCore/SleepView.swift`,
     `tests/SerenixCoreTests/SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: "The Sleeping HR line is at 52 with the tag '52 bpm'", "The chart has no
     gridlines" and "The asleep shading runs 23:00 to 07:00, labelled … ; the Wake Bout columns
     … ; under the chart it reads 'Woke 2 times · 15 min awake'" pass; the gridline and
     "Sleeping HR 52" tests are rewritten.
4. [ ] **Verify:** full suite + lint + typecheck green; every automated success criterion in
   spec 012 checked; no `asleepSegments`, `gridlines` or band row left. Carried to the PR
   checklist: the macOS CI build and the phone check that the lanes and open chart match the
   graphs prototype's variant E in both themes.
   - Blocked by: 3

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
