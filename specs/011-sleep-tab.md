# 011 — Sleep tab

**Status:** approved
**Last updated:** 2026-11-03 (approved)

## Problem
Everything Serenix knows about a night's sleep fits in one Sleep popup about one Night. The
patterns that matter most, such as Sleep Debt building over a week, bedtimes drifting, how broken
the night was, and when to go to bed tonight, have nowhere to show. Spec 002 left a tab bar and a
Sleep screen for a later spec.

## Goal
A tab bar with **Today** and **Sleep**. The Sleep tab shows three sections: **Tonight**, a
bedtime to aim for; **Last night**, the Night's Heart Rate Trace with its Wake Bouts; and **Your
week**, Time Asleep against Sleep Need and when you slept.

## User stories
1. As a Strap owner, I want to know when to be asleep tonight to get the sleep I need, so I can
   act on my Sleep Debt rather than just read it.
2. As a Strap owner, I want to see my heart rate through the night, against my Sleeping HR, so I
   can see how it settled.
3. As a Strap owner, I want to see when I woke in the night and for how long, not only a total.
4. As a Strap owner, I want to see a week of Time Asleep against Sleep Need, so I can see debt
   building and being paid back.
5. As a Strap owner, I want to see when I fell asleep and woke across the week, so irregular
   nights stand out.
6. As a Strap owner, I want the Day I pick to stay picked when I switch tabs.
7. As a Strap owner looking at an old Night, I want the parts that are still known to show, and
   a plain note for what isn't kept.
8. As a Strap owner, I want the Sleep Score and its parts one tap away from the Sleep tab.

## Behavior
For the Day shown, D (spec 002: today, or the Day picked). Clock times are local, in the Today
view's time zone.

**Tab bar.** Two tabs, **Today** (the `sun.max` symbol) and **Sleep** (`moon.zzz`). Today is the
default, and the selected tab is drawn in the accent colour. The Day shown is shared: picking a
Day on either tab's week strip or date picker shows it on both, and coming back from the
background shows today on both (spec 002). Both tabs have spec 002's top bar (avatar and
profile menu, calendar button) and sync pill. Today doesn't change: its Sleep Score ring and Time
Asleep tile still open the Sleep popup.

**Sleep tab**, top to bottom: the top bar, the week strip (as on Today), then **Tonight** (only
when D is today), **Last night**, **Your week**. When D has no Night, Last night is replaced by
spec 002's message ("No Night yet" for today, "No Night recorded" otherwise); Tonight and Your
week still show.

**Tonight.** Only when D is today.
- **Usual wake time:** the median of the Final Wake clock times of the Nights dated D − 6 to D,
  compared the shortest way round the clock (spec 010, Sleep Consistency).
- **Tonight's Sleep Need:** the Sleep Need (spec 009) of the Night that will be dated D + 1,
  whose week is D − 6 to D.
- **Be asleep by** = usual wake time − tonight's Sleep Need, on the clock.
- Shows "Be asleep by 23:00", "Sleep Need 8h 0m", "You usually wake at 07:00", and, when there
  is Sleep Debt, "· 2h 0m of Sleep Debt this week" (that Sleep Debt, as the Time Asleep tile
  writes durations).
- With fewer than **3** Nights with a Final Wake in D − 6 to D, it shows only "A bedtime to aim
  for appears after 3 Nights".

**Last night.** About the Night dated D. Its title is "Last night" when D is today and the
date otherwise (as the week strip names Days). It shows:
- **Time Asleep**, "7h 45m asleep", and a **Sleep Score ›** button that opens the Sleep popup.
- **The chart**, from the start to the end of Time in Bed (or Sleep Onset to Final Wake when
  Time in Bed is missing):
  - the Heart Rate Trace as a line, broken where a step is missing;
  - a dotted line at the Night's Sleeping HR, labelled "Sleeping HR 52"; no line or label
    without a Sleeping HR;
  - the y-axis from the lowest step − 3 bpm to the highest + 3, with no other labels;
  - under it, a **sleep/wake band**: Sleep Onset to Final Wake in the accent colour, each Wake
    Bout in amber, with Sleep Onset's and Final Wake's clock times under its ends;
  - "In bed 22:50 · Up 07:10" (Time in Bed's start and end; left out without Time in Bed).
- **The Wake Bouts:** "Woke 2 times · 15 min awake" ("Woke 1 time", "Didn't wake" with none),
  then one row per Wake Bout, oldest first: its start ("02:10") and length ("8 min"). The total
  is the Sleep popup's minutes awake (Final Wake − Sleep Onset − Time Asleep, spec 002).
- **Not kept:** a Night with no Heart Rate Trace shows "Heart rate isn't kept for Nights older
  than 30 days." in place of the chart, band and Wake Bouts. Time Asleep, "In bed · Up" and the
  Sleep Score button still show.

**Your week.** The 7 Days D − 6 to D, oldest first, each named by its weekday's first letter,
with D's bars in the accent colour and the others lighter. A Day with no Night is an empty slot.
- **Time Asleep against Sleep Need:** per Night, a bar of its Time Asleep and a mark at its own
  Sleep Need (spec 009).
- **When you slept:** per Night, a bar from its Sleep Onset to its Final Wake on a clock axis
  from 20:00 to 10:00, widened to whole hours to fit any Night outside it.

**Heart Rate Trace** (stored with each Night). Built with the Night from its History Records
(spec 003). It covers Time in Bed in 5-minute steps from Time in Bed's start; the last step may
be shorter. A step's value is the mean heart rate of its History Records with a non-zero heart
rate, in bpm, unrounded; a step with fewer than **150** such records is missing. A Night with no
Time in Bed covers Sleep Onset to Final Wake instead.

**Wake Bouts** (stored with each Night). Built with the Night: each unbroken run of wake minutes
between Sleep Onset and Final Wake, from the same sleep/wake labelling that finds the Sleep
Period (spec 003), as its start and its length in whole minutes.

**Nights built before this ships.** After the update, Serenix queues one rebuild (spec 003,
Night rebuilds) for each stored Night that has no Heart Rate Trace and is still due by spec 003's
30-day rule, once. Rebuilt Nights gain a Heart Rate Trace and Wake Bouts. Older Nights keep none
and show the "not kept" note.

## Design decisions
- **`SerenixCore`: Night** gains an optional Heart Rate Trace (the steps' start times and
  values, missing steps included) and optional Wake Bouts; nil means not kept. **Nights from
  History Records** fills both, reusing the Sleep Period's minute labels. The sleep/wake labelling
  and Sleep Period results must not change (spec 003's hr-tracker parity). The 5-minute step and
  the 150-record minimum are named constants (unit and source: this spec).
- **`SerenixCore`: Sleep view (new).** A pure value, like the Today view, built from the stored
  Nights, the Day shown, now, the time zone and the birth year. It holds the week strip, Tonight
  (or its "after 3 Nights" text, or nothing when D isn't today), Last night (chart range, trace
  steps, Sleeping HR line, sleep/wake band segments, Wake Bout texts, or the not-kept note, or
  the no-Night message) and Your week (7 slots with their bars). It reuses Sleep Need (spec 009)
  and Sleep Consistency's shortest-way-round median (spec 010).
- **`SerenixCore`: Night rebuilds** gains the one-off queue: given the stored Nights, now and the
  time zone, the Nights to rebuild because they have no Heart Rate Trace and are still due.
- **Shell.** A tab container holds the Day shown (moved out of the Today screen) and the
  back-from-background reset, and shows the Today screen and a new Sleep screen. The stored
  Night gains the two optional fields (a lightweight SwiftData migration). The one-off queue runs
  once after the update. The Sleep screen draws the Sleep view; its Sleep Score button opens the
  existing Sleep popup.
- Follows ADR 0002 (logic in `SerenixCore`). No new ADR: storing two more values per Night is
  easy to reverse.

## Seams under test
- **Nights from History Records (`SerenixCore`)**, spec 003's seam, fed hand-built History
  Records and the fixture night. Catches the Heart Rate Trace (steps, the non-zero mean, the
  150-record rule, its span) and the Wake Bouts. Misses storing them.
- **Night rebuilds (`SerenixCore`)**, spec 003's seam, fed stored Nights, now and a time zone.
  Catches which Nights the one-off queue picks. Misses running it once.
- **Sleep view (`SerenixCore`, new)**, fed hand-built Nights with Heart Rate Traces and Wake
  Bouts, the Day shown, now, the time zone and a birth year. Catches Tonight, Last night and Your
  week as above. Misses drawing, the tab bar and the shared Day shown, checked by hand on the
  phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`). Unless a criterion says otherwise: times in Europe/London (GMT, so local
equals UTC); now 3 Nov 2026 08:12, so today is 3 Nov; no birth year. Expected values worked by
hand from the rules above.

Heart Rate Trace and Wake Bouts (Nights from History Records):
- [ ] A Night whose Time in Bed is 23:00–07:00 has a Heart Rate Trace of 96 steps, the first
      starting at 23:00 and each 5 minutes after the last.
- [ ] A step of 300 records at 60 bpm reads 60; 150 at 50 and 150 at 70 read 60; 150 at 60 and
      150 at 0 read 60; 149 at 60 and 151 at 0 is missing.
- [ ] A Night whose Sleep Period has wake minutes 02:00 to 02:07 and no other wake has one Wake
      Bout, starting 02:00, 8 minutes long.
- [ ] The fixture night's Wake Bouts add up to its Final Wake − Sleep Onset − Time Asleep, in
      minutes, and its Sleep Onset, Final Wake, Time in Bed and Time Asleep are unchanged
      (spec 003).

Night rebuilds (one-off queue):
- [ ] With now 3 Nov 2026 12:00, stored Nights dated 4 Oct and 5 Oct with no Heart Rate Trace and
      1 Nov with one queue only 5 Oct (4 Oct's History Records start more than 30 days earlier).

Tonight (Sleep view; Nights dated 28 Oct to 3 Nov, each Sleep Onset 23:00, Final Wake 07:00):
- [ ] With Time Asleep 8 h each, Tonight reads "Be asleep by 23:00", "Sleep Need 8h 0m", "You
      usually wake at 07:00", with no Sleep Debt text.
- [ ] With Time Asleep 7 h each (Sleep Debt 7 h, Sleep Need capped at 9 h), it reads "Be asleep
      by 22:00", "Sleep Need 9h 0m" and "· 7h 0m of Sleep Debt this week".
- [ ] With only Nights dated 1, 2 and 3 Nov, Final Wakes 06:50, 07:10 and 07:00 and Time Asleep
      8 h, the usual wake time is 07:00 and it reads "Be asleep by 23:00".
- [ ] With only Nights dated 2 and 3 Nov, Tonight reads only "A bedtime to aim for appears after
      3 Nights".
- [ ] With 2 Nov shown, there is no Tonight.

Last night (Sleep view; the Night dated 3 Nov has Time in Bed 22:50–07:10, Sleep Onset 23:00,
Final Wake 07:00, Time Asleep 7 h 45 m, Sleeping HR 52, and Wake Bouts at 02:10 for 8 min and
04:30 for 7 min):
- [ ] Its title is "Last night", it reads "7h 45m asleep", the chart runs 22:50 to 07:10, and
      it shows "In bed 22:50 · Up 07:10".
- [ ] The Sleeping HR line is at 52 and labelled "Sleeping HR 52"; with no Sleeping HR there is
      no line or label.
- [ ] The y-axis runs from the lowest step − 3 to the highest + 3 (steps 50 to 70: 47 to 73); a
      missing step breaks the line.
- [ ] The sleep/wake band runs 23:00 to 07:00 with Wake Bouts 02:10–02:18 and 04:30–04:37, and
      the list reads "Woke 2 times · 15 min awake", "02:10 · 8 min", "04:30 · 7 min".
- [ ] One Wake Bout reads "Woke 1 time"; none reads "Didn't wake".
- [ ] With no Time in Bed, the chart runs 23:00 to 07:00 and there is no "In bed · Up".
- [ ] With no Heart Rate Trace, it shows "Heart rate isn't kept for Nights older than 30 days.",
      no chart, band or Wake Bouts, and still "7h 45m asleep".
- [ ] With 1 Nov shown, its title is that Day's name as the week strip writes it; with no Night
      on 3 Nov, it reads "No Night yet", and with none on 1 Nov, "No Night recorded".

Your week (Sleep view; Nights dated 1 Nov with Time Asleep 6 h, 2 and 3 Nov with 8 h, each
23:00–07:00):
- [ ] It has 7 slots, 28 Oct to 3 Nov, oldest first; 28 to 31 Oct are empty.
- [ ] Time Asleep against Sleep Need reads 1 Nov 6h 0m against 8h 0m, 2 Nov 8h 0m against
      8h 30m, 3 Nov 8h 0m against 8h 30m.
- [ ] When you slept runs each Night 23:00 to 07:00 on a 20:00 to 10:00 axis; a Night from 19:30
      widens it to 19:00.
- [ ] 3 Nov's bars are marked as the Day shown; with 2 Nov shown, the slots are 27 Oct to 2 Nov
      and 2 Nov's are marked.

Build and phone:
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): installed over the previous build, the tab bar shows Today and
      Sleep; picking a Day on one tab shows it on the other; backgrounding and reopening shows
      today on both.
- [ ] On the phone (by hand): recent Nights show a Heart Rate Trace, sleep/wake band and Wake
      Bouts after the one-off rebuild; a Night older than 30 days shows the "not kept" note.
- [ ] On the phone (by hand): Tonight shows on today's Sleep tab, and the Sleep Score button
      opens the Sleep popup.

## Non-goals (explicitly out of scope)
- Sleep stages, and Trends (its own tab and spec).
- Scrubbing the chart, marking the lowest heart rate, and HRV, respiratory rate, skin
  temperature or SpO2 through the night.
- A minimum Wake Bout length, or merging short ones (tuning).
- Reminders or notifications for the bedtime.
- Changing the Sleep popup (being redesigned separately) or the Today tab.
- Pruning History Records after 30 days (never built; see Notes).
- Naps.

## Open questions
- **Every number is an assumption** (5-minute steps, 150 records, 3 Nights, the 20:00–10:00
  axis). Tune with real Nights.
- **Sleeping HR against the trace.** Sleeping HR is the lowest *sustained* heart rate, so the
  lowest 5-minute step can sit a little above or below the dotted line. Assumed fine without a
  separate "lowest" marker.

## Notes
- Prototype: branch `prototype/sleep-screen`, file
  `src/SerenixApp/Prototype/sleep-screen-prototype.html`, variant A ("Stacked"). Serve the folder
  (`python -m http.server`) and open it with `?variant=A`. B and C were the rejected week-first and
  Night/Week-switch layouts. An earlier version that only moved the Sleep popup onto a screen was
  rejected as adding nothing over the popup.
- Spec 002 deferred the tab bar and the Sleep screen to this spec. The earlier home-screen
  prototype's Sleep tab (variant C) put score chips and metric tiles there; this spec doesn't.
- Extends spec 003: Nights from History Records also produce the Heart Rate Trace and Wake
  Bouts, and Night rebuilds gain the one-off queue. Reuses spec 009 (Sleep Need) and spec 010
  (Sleep Consistency's median). Terms: Heart Rate Trace, Wake Bout (GLOSSARY.md).
- `docs/architecture.md` says History Records are kept 30 days, but nothing deletes them yet.
  This spec still treats Nights older than 30 days as having no Heart Rate Trace, as spec 003's
  rebuild rule does.
