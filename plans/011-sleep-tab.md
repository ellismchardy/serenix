# Plan: 011 — Sleep tab

**For spec:** specs/011-sleep-tab.md
**Type:** feature
**Branch:** feat/sleep-screen

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
Three seams, as the spec says. **Nights from History Records** (`nights(from:in:)`) gains the
Heart Rate Trace and Wake Bouts on `Night`, both worked out from what `SleepPeriod` already
computes: its sleep/wake labels. So
the first task is a **prefactor** that lets `SleepPeriod` keep each minute's asleep flag inside the
period (internal), changing no result: spec 003's
hr-tracker parity tests must stay green untouched. The Heart Rate Trace needs per-record
non-zero heart rates in 5-minute steps, so it's built from the sorted records directly, over
Time in Bed. Wake Bouts are the runs of **non-sleep** minutes between Sleep Onset and Final Wake —
a minute with no data counts as wake, the same as `timeAsleep` (which counts only `.sleep`
minutes), so the bouts always add up to minutes awake. Both go into `StoredNight` as optional
encoded fields (a lightweight SwiftData migration).

A new pure **Sleep view** (`src/SerenixCore/SleepView.swift`, public, like `TodayView`) holds
everything the Sleep tab shows, built from the stored Nights, the Day shown, now, the time zone
and the birth year. It reuses `WeekStrip`, `SleepNeed` (spec 009) and Sleep Consistency's
shortest-way-round median (spec 010, in `SleepScore.swift`; lift it to a shared internal helper
when Tonight needs it). The first Sleep view task is the vertical tracer: the shell's tab bar
(Today / Sleep), a tab container that owns the Day shown (moved out of `TodayScreen`, with the
back-from-background reset), and a Sleep screen drawing the week strip and Last night's header.
Later tasks add the chart and Wake Bouts, Tonight, Your week, and the one-off rebuild queue.

New tests: `tests/SerenixCoreTests/SleepViewTests.swift` (Sleep view seam) and additions to the
existing Nights and Night rebuild tests.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Prefactor:** `SleepPeriod` keeps, internally, whether each minute from Sleep Onset to
   Final Wake was asleep (`minuteIsAsleep`), and works Time Asleep out from it, so Wake Bouts can
   be read from it. No behavior change. (The minute table isn't needed: the Heart Rate Trace is
   built from the records, and the table's mean includes zero heart rates.)
   - Files: `SleepPeriod.swift`
   - Done when: the existing suite (incl. spec 003's fixture-night parity tests) is green and
     unchanged.
2. [ ] **Slice:** Heart Rate Trace — 5-minute steps over Time in Bed (Sleep Onset to Final Wake
   without it) from its start, last step possibly shorter; mean of non-zero heart rates; a step
   with fewer than 150 such records is missing; stored on `Night` and in `StoredNight`
   (optional, encoded).
   - Seam: Nights from History Records · Files: `Night.swift`, `Nights.swift`,
     `NightsTests.swift`, `src/SerenixApp/NightStore.swift`
   - Done when: spec 011 criteria "Time in Bed 23:00–07:00 has a Heart Rate Trace of 96 steps…"
     and "A step of 300 records at 60 bpm reads 60; …149 at 60 and 151 at 0 is missing".
3. [ ] **Slice:** Wake Bouts — runs of non-sleep minutes between Sleep Onset and Final Wake, each
   a start and a length in whole minutes; stored on `Night` and in `StoredNight`.
   - Seam: Nights from History Records · Files: `Night.swift`, `Nights.swift`,
     `NightsTests.swift`, `src/SerenixApp/NightStore.swift`
   - Done when: criteria "wake minutes 02:00 to 02:07 … one Wake Bout, starting 02:00, 8 minutes
     long" and "The fixture night's Wake Bouts add up to … and its Sleep Onset, Final Wake, Time
     in Bed and Time Asleep are unchanged".
4. [ ] **Slice (tracer):** the tab bar and the Sleep screen's skeleton — `SleepView` with the week
   strip and Last night's header (title "Last night" or the Day's name, "7h 45m asleep", "In bed
   22:50 · Up 07:10" or none, the no-Night messages); the shell's tab container (Today `sun.max`,
   Sleep `moon.zzz`, accent when selected) owning the shared Day shown and the
   back-from-background reset; a Sleep screen with the top bar, sync pill, week strip, header and
   a Sleep Score button opening the existing Sleep popup.
   - Seam: Sleep view · Files: `SleepView.swift` (new), `SleepViewTests.swift` (new),
     `src/SerenixApp/SerenixApp.swift`, `TodayScreen.swift`, a new `SleepScreen.swift` and tab
     container view, `WeekStripView.swift` / the date picker (moved out of `TodayScreen` to be
     shared)
   - Done when: criteria "Its title is 'Last night', it reads '7h 45m asleep', … 'In bed 22:50 ·
     Up 07:10'" (title, Time Asleep and In bed parts), "With no Time in Bed … no 'In bed · Up'",
     and "With 1 Nov shown, its title is that Day's name …; … 'No Night yet' … 'No Night
     recorded'".
5. [ ] **Slice:** Last night's chart and Wake Bouts — chart range (Time in Bed, or Sleep Onset to
   Final Wake), trace steps with gaps, y-axis lowest − 3 to highest + 3, the Sleeping HR line
   and label (none without), the sleep/wake band segments, the Wake Bout texts ("Woke 2 times ·
   15 min awake", rows, "Woke 1 time", "Didn't wake"), and the "not kept" note in place of
   chart, band and Wake Bouts; the shell draws them.
   - Seam: Sleep view · Files: `SleepView.swift`, `SleepViewTests.swift`,
     `src/SerenixApp/SleepScreen.swift` (chart view)
   - Done when: the remaining Last night criteria (chart range 22:50 to 07:10 and 23:00 to 07:00,
     Sleeping HR line, y-axis 47 to 73 and the broken line, band and list, one/none Wake Bouts,
     the "not kept" note).
6. [ ] **Slice:** Tonight — only when the Day shown is today; usual wake time (shortest-way-round
   median of Final Wakes, D − 6 to D), tonight's Sleep Need (the Night dated D + 1), "Be asleep
   by", the Sleep Debt text, and the 3-Night minimum; the shell draws the card.
   - Seam: Sleep view · Files: `SleepView.swift`, `SleepScore.swift` (lift the median helper),
     `SleepViewTests.swift`, `src/SerenixApp/SleepScreen.swift`
   - Done when: the five Tonight criteria (23:00; 22:00 with "9h 0m" and "· 7h 0m of Sleep
     Debt"; the 06:50/07:10/07:00 median; "after 3 Nights"; no Tonight with 2 Nov shown).
7. [ ] **Slice:** Your week — 7 slots D − 6 to D, empty slots, Time Asleep against each Night's
   own Sleep Need, Sleep Onset to Final Wake bars on the 20:00–10:00 axis widened to whole hours,
   the Day shown marked; the shell draws both charts.
   - Seam: Sleep view · Files: `SleepView.swift`, `SleepViewTests.swift`,
     `src/SerenixApp/SleepScreen.swift`
   - Done when: the four Your week criteria.
8. [ ] **Slice:** the one-off rebuild queue — given stored Nights, now and the time zone, the
   Nights with no Heart Rate Trace still due by spec 003's 30-day rule; the shell queues them
   once after the update (a stored flag).
   - Seam: Night rebuilds · Files: `NightRebuild.swift`, `NightRebuildTests.swift`,
     `src/SerenixApp/NightStore.swift`, `src/SerenixApp/StrapConnection.swift`
   - Done when: criterion "With now 3 Nov 2026 12:00, stored Nights dated 4 Oct and 5 Oct with no
     Heart Rate Trace and 1 Nov with one queue only 5 Oct".
9. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; every automated success criterion in spec 011 checked.
   - Done when: the above pass and the criteria are ticked. Carried to the PR checklist (they
     need the PR): the macOS CI build, and by hand on the phone — the tab bar and shared Day
     (picking on one tab shows on the other; back from background shows today on both); recent
     Nights show a Heart Rate Trace, band and Wake Bouts after the one-off rebuild, and an old
     Night shows the "not kept" note; Tonight shows on today's Sleep tab and the Sleep Score
     button opens the Sleep popup.

## Done when
- All tasks checked, every success criterion in spec 011 met, suite green.
