# 012 — Sleep tab

**Status:** draft
**Last updated:** 2026-11-04 (lanes and chart restyled from the graphs prototype's variant E:
gradient block with Wake Bout notches, one-picture chart in the accent colour, smoothed curve)

## Problem
Everything Serenix knows about a night's sleep fits in one Sleep popup about one Night. The
patterns that matter most, such as Sleep Debt building over a week, bedtimes drifting, how broken
the night was, and when to go to bed tonight, have nowhere to show. Spec 002 left a tab bar and a
Sleep screen for a later spec.

## Goal
A tab bar with **Today** and **Sleep**. The Sleep tab opens on a plain-words read of the Night,
then the week as one lane per Night on a shared clock axis (each Night's Heart Rate Trace and Wake
Bouts open inside its lane), then a bedtime to aim for tonight, then what stood out about the
Night.

## User stories
1. As a Strap owner, I want the Sleep tab to tell me in words how the Night went against what I
   needed, before any chart.
2. As a Strap owner, I want to know when to be asleep tonight to get the sleep I need, so I can
   act on my Sleep Debt rather than just read it.
3. As a Strap owner, I want to see my heart rate through any Night of the week, against my
   Sleeping HR, so I can see how it settled.
4. As a Strap owner, I want to see when I woke in the night and for how long, not only a total.
5. As a Strap owner, I want to see a week of Nights side by side on one clock, so short and
   irregular Nights stand out and I can see Sleep Debt building.
6. As a Strap owner, I want the Day I pick to stay picked when I switch tabs.
7. As a Strap owner looking at an old Night, I want the parts that are still known to show, and
   a plain note for what isn't kept.
8. As a Strap owner, I want the Sleep Score and its parts one tap away from the Sleep tab.

## Behavior
For the Day shown, D (spec 002: today, or the Day picked). Clock times are local, in the Today
view's time zone. Durations are written as the Time Asleep tile writes them ("7h 45m"), except the
Summary's gap (below).

**Tab bar.** Two tabs, **Today** (the `sun.max` symbol) and **Sleep** (`moon.zzz`). Today is the
default, and the selected tab is drawn in the accent colour. On iOS 26 and later it is the
system's floating tab bar: a translucent glass capsule inset above the bottom edge, the selected
tab on a lighter pill inside it, with the screen's content scrolling under it and nothing cut off
behind it at the end of a scroll. On iOS 17 and 18 it is the system's standard tab bar. It is
never a hand-drawn imitation of either. The Day shown is shared: picking a
Day on either tab's week strip or date picker shows it on both, and coming back from the
background shows today on both (spec 002). Both tabs have spec 002's top bar (avatar and
profile menu, calendar button) and sync pill. Today doesn't change: its Sleep Score ring and Time
Asleep tile still open the Sleep popup.

**Sleep tab**, top to bottom: the top bar, the week strip (as on Today), then the **Summary**,
**Your week**, **Tonight** (only when D is today) and **What stood out**. When D has no Night,
the Summary is replaced by spec 002's message ("No Night yet" for today, "No Night recorded"
otherwise) and What stood out is left out; Your week and Tonight still show.

**Summary.** About the Night dated D. Its label is "Last night" when D is today and the date
otherwise (as the week strip names Days). Against the Night's own Sleep Need (spec 009):
- Time Asleep **15 min or more short** of it: "You slept 7h 45m, 45 minutes short of what you
  needed."
- **15 min or more over** it: "You slept 8h 30m, 30 minutes more than you needed."
- The gap is in whole minutes, written "45 minutes" under an hour and "1h 45m" from an hour up
  ("1h 0m" at exactly an hour), never "0h 45m".
- Otherwise: "You slept 8h 0m, about what you needed."
- Without a Time Asleep it reads "Time Asleep wasn't worked out for this Night." (Every Night has
  a Sleep Need, spec 009.)
- The gap is taken from Time Asleep and Sleep Need each in whole minutes, as shown, so 7 h 45 m
  30 s against 8h 0m reads "You slept 7h 46m, about what you needed."
- Under the sentence: a **Sleep Score ›** button that opens the Sleep popup, and "23:00 – 07:00"
  (Sleep Onset – Final Wake; left out when either is missing).

**Your week.** A card titled "Your week" with "avg 7h 40m · Sleep Debt 2h 22m" beside the title:
the mean Time Asleep of the Nights dated D − 6 to D, and the Sleep Debt of that week (spec 009;
"· Sleep Debt" left out when it is 0, and "avg" left out with no Nights). Under it, lanes on one
clock axis from 20:00 to 10:00, widened to whole hours to fit any Night outside it, with faint
lines and labels every 2 hours ("22", "00", "02" …) under the last lane:
- **Tonight lane** (first, only when D is today and there is a bedtime): a dashed bar from Be
  asleep by to the usual wake time (see Tonight), with the Be asleep by time at its right.
- **One lane per Day**, D first, then D − 1 back to D − 6. Each is named by its weekday's short
  name ("Tue"), except D, named "Last" when D is today. A Day with no Night reads "no Night".
- A Night's lane shows Time in Bed as a soft track, Sleep Onset to Final Wake as one unbroken
  block on it, shaded from the lighter accent colour at Sleep Onset to the accent colour at Final
  Wake, each Wake Bout as an amber notch standing a little above and below the block, and its
  Time Asleep at the right, in amber when 15 min or more short of its own Sleep Need.
- **Opening a lane.** Tapping a Night's lane opens its chart under it and closes any other;
  tapping the open lane closes it. D's lane is open when the tab is shown (when D has a Night).
- **The chart**, from the start to the end of Time in Bed (or Sleep Onset to Final Wake when
  Time in Bed is missing), one picture with no separate band:
  - Sleep Onset to Final Wake shaded behind everything in the lighter accent colour, labelled
    "asleep 23:00" at its top left and "07:00" at its top right;
  - each Wake Bout as an amber column across the chart's height;
  - the Heart Rate Trace as a smooth curve in the accent colour with a fill fading from it down
    to the chart's foot, broken where a step is missing. Each step is drawn at its **smoothed
    value**: the mean of the steps within 3 either side (15 minutes), each weighted by
    e^(−d²/(2·1.6²)) for its distance d in steps, missing steps left out; a missing step stays
    missing. The curve passes through every smoothed value and never rises above or dips below
    the two it joins;
  - a dotted line at the Night's Sleeping HR with a "52 bpm" tag at its right end; no line or
    tag without a Sleeping HR;
  - the y-axis from the lowest step − 3 bpm to the highest + 3 (the steps as kept, not
    smoothed), widened to take in the Night's Sleeping HR so its line is always on the chart,
    with no gridlines or bpm labels;
  - under it, hour ticks every 2 hours at their clock positions (none at the chart's ends);
  - under the chart: "Woke 2 times · 15 min awake" ("Woke 1 time", "Didn't wake" with none; the
    total is the Sleep popup's minutes awake, Final Wake − Sleep Onset − Time Asleep, spec 002)
    and **Sleep Score ›**, which opens the Sleep popup for that Night.
- **Not kept:** a Night with no Heart Rate Trace opens to "Heart rate isn't kept for Nights older
  than 30 days." in place of the chart, and its lane has no Wake Bout notches. Its Time Asleep
  and block still show.

**Tonight.** Only when D is today, as a card in the accent colour under Your week.
- **Usual wake time:** the median of the Final Wake clock times of the Nights dated D − 6 to D,
  compared the shortest way round the clock (spec 010, Sleep Consistency).
- **Tonight's Sleep Need:** the Sleep Need (spec 009) of the Night that will be dated D + 1,
  whose week is D − 6 to D.
- **Be asleep by** = usual wake time − tonight's Sleep Need, on the clock.
- Reads "To get 8h 0m before your usual 07:00 wake, be asleep by 23:00."
- With fewer than **3** Nights with a Final Wake in D − 6 to D, it reads only "A bedtime to aim
  for appears after 3 Nights", and there is no Tonight lane.

**What stood out.** About the Night dated D; a card of up to three rows, each a line and a
smaller detail, in this order:
- **Wake Bouts:** "Woke 2 times · 15 min awake" (as under the chart), with the Wake Bouts as the
  detail, oldest first: "02:10 · 8 min · 04:30 · 7 min". Left out when Wake Bouts aren't kept.
- **Bedtime:** against the usual Sleep Onset, the median of the Sleep Onset clock times of the
  Nights dated D − 7 to D − 1 (shortest way round the clock): "Fell asleep 40 min earlier than
  usual" or "… later than usual" when more than 30 min apart, otherwise "Fell asleep around your
  usual time"; the detail is "Usual 23:00, last night 23:40" ("that night" when D isn't today).
  Left out with fewer than 3 such Nights or no Sleep Onset.
- **Heart rate:** "Heart rate settled to 52 bpm" (the Night's Sleeping HR), detail "Its lowest
  stretch: your Sleeping HR". Left out without a Sleeping HR.
- With no rows, the card is left out.

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
- **`SerenixCore`: Sleep view.** A pure value, like the Today view, built from the stored Nights,
  the Day shown, now, the time zone and the birth year. It holds the week strip; the Summary (its
  label, sentence and onset–wake text, or the no-Night message); Your week (its title texts, the
  clock axis and its labels, the Tonight lane, and 7 lanes, each with its name, asleep block,
  Wake Bout notches, Time Asleep text and short flag, and the Night's chart: range, trace steps
  with their smoothed values, Sleeping HR line and tag, y-axis, asleep shading and its labels,
  Wake Bout columns, hour ticks and the "Woke" text, or the not-kept note);
  Tonight (its sentence, or the "after 3 Nights" text, or nothing when D isn't today); and What
  stood out (its rows). Which lane is open is the shell's state; the Sleep view says which lane
  opens first. It reuses Sleep Need and Sleep Debt (spec 009) and Sleep Consistency's
  shortest-way-round median (spec 010). The 15-minute and 30-minute thresholds and the
  smoothing's reach (3 steps) and width (1.6 steps) are named constants (unit and source: this
  spec). Smoothing is for drawing only: the stored Heart Rate Trace, Sleeping HR and the y-axis
  use the steps as kept.
- **`SerenixCore`: Night rebuilds** gains the one-off queue: given the stored Nights, now and the
  time zone, the Nights to rebuild because they have no Heart Rate Trace and are still due.
- **Shell.** A tab container holds the Day shown (moved out of the Today screen) and the
  back-from-background reset, and shows the Today screen and a new Sleep screen. The stored
  Night gains the two optional fields (a lightweight SwiftData migration). The one-off queue runs
  once after the update. The Sleep screen draws the Sleep view, holds which lane is open (reset to
  the Sleep view's first open lane when the Day shown changes), draws the smoothed values as a
  monotone curve (it never overshoots between two values), and opens the existing Sleep popup
  from the Sleep Score buttons.
- **iOS 26 SDK.** The tab bar stays SwiftUI's own tab view; the iOS 26 look comes from building
  against the iOS 26 SDK, not from code. The macOS CI job builds with Xcode 26 (it built with
  Xcode 16.4 and the iOS 18.5 SDK, which keeps the old tab bar even on iOS 26). The deployment
  target stays iOS 17. Building against the new SDK also gives the app's other system controls
  (sheets, navigation and toolbars, menus, the date picker) their iOS 26 look, so the popups and
  the profile menu are checked on the phone with it.
- Follows ADR 0002 (logic in `SerenixCore`). Storing two more values per Night is easy to
  reverse, and the layout is easy to change again. Moving CI to Xcode 26 updates ADR 0003's build
  setup.

## Seams under test
- **Nights from History Records (`SerenixCore`)**, spec 003's seam, fed hand-built History
  Records and the fixture night. Catches the Heart Rate Trace (steps, the non-zero mean, the
  150-record rule, its span) and the Wake Bouts. Misses storing them.
- **Night rebuilds (`SerenixCore`)**, spec 003's seam, fed stored Nights, now and a time zone.
  Catches which Nights the one-off queue picks. Misses running it once.
- **Sleep view (`SerenixCore`)**, fed hand-built Nights with Heart Rate Traces and Wake Bouts,
  the Day shown, now, the time zone and a birth year. Catches the Summary, Your week, Tonight and
  What stood out as above. Misses drawing (smoothing, colours), opening and closing lanes, the
  tab bar and the shared Day shown, checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`). Unless a criterion says otherwise: times in Europe/London (GMT, so local
equals UTC); now 3 Nov 2026 08:12, so today is 3 Nov; no birth year (Usual Need 8 h). Expected
values worked by hand from the rules above.

Heart Rate Trace and Wake Bouts (Nights from History Records):
- [x] A Night whose Time in Bed is 23:00–07:00 has a Heart Rate Trace of 96 steps, the first
      starting at 23:00 and each 5 minutes after the last.
- [x] A step of 300 records at 60 bpm reads 60; 150 at 50 and 150 at 70 read 60; 150 at 60 and
      150 at 0 read 60; 149 at 60 and 151 at 0 is missing.
- [x] A Night whose Sleep Period has wake minutes 02:00 to 02:07 and no other wake has one Wake
      Bout, starting 02:00, 8 minutes long.
- [x] The fixture night's Wake Bouts add up to its Final Wake − Sleep Onset − Time Asleep, in
      minutes, and its Sleep Onset, Final Wake, Time in Bed and Time Asleep are unchanged
      (spec 003).

Night rebuilds (one-off queue):
- [x] With now 30 Nov 2026 12:00, stored Nights dated 31 Oct and 1 Nov with no Heart Rate Trace and
      29 Nov with one queue only 1 Nov (its History Records start exactly 30 days earlier, as in
      spec 003's example; 31 Oct's start before that).

Summary (Sleep view; a Night dated 3 Nov with Sleep Onset 23:00, Final Wake 07:00, and Nights
dated 27 Oct to 2 Nov each with Time Asleep 8 h, so its Sleep Need is 8h 0m):
- [x] With Time Asleep 7 h 45 m, its label is "Last night" and it reads "You slept 7h 45m, 15
      minutes short of what you needed." and "23:00 – 07:00".
- [x] With Time Asleep 7 h 50 m it reads "You slept 7h 50m, about what you needed."; with
      8 h 30 m, "You slept 8h 30m, 30 minutes more than you needed."
- [x] With Time Asleep 6 h 9 m it reads "You slept 6h 9m, 1h 51m short of what you needed."; with
      7 h 0 m, "You slept 7h 0m, 1h 0m short of what you needed."
- [x] With no Time Asleep it reads "Time Asleep wasn't worked out for this Night."
- [x] With 1 Nov shown, its label is that Day's name as the week strip writes it; with no Night on
      3 Nov, the Summary reads "No Night yet" and there is no What stood out, and with none on
      1 Nov, "No Night recorded".

Your week (Sleep view; Nights dated 1 Nov with Time Asleep 6 h, 2 and 3 Nov with 8 h, each Sleep
Onset 23:00, Final Wake 07:00, Time in Bed 22:50–07:10):
- [x] It has 7 lanes, 3 Nov first, then 2 Nov back to 28 Oct, named "Last", "Mon", "Sun", "Sat",
      "Fri", "Thu", "Wed"; 28 to 31 Oct read "no Night".
- [x] Its title reads "avg 7h 20m · Sleep Debt 2h 0m".
- [x] Each Night's bar runs 23:00 to 07:00 on a 20:00 to 10:00 axis labelled "22", "00", "02",
      "04", "06", "08"; a Night from 19:30 widens it to 19:00.
- [x] 1 Nov's Time Asleep reads "6h 0m" and is marked short (Sleep Need 8h 0m); 2 Nov's "8h 0m"
      (Sleep Need 8h 30m) is marked short; 3 Nov's (Sleep Need 8h 30m) is marked short.
- [x] 3 Nov's lane opens first; with no Night on 3 Nov, no lane opens first.
- [x] With 2 Nov shown, the lanes are 2 Nov back to 27 Oct and 2 Nov's is named "Mon".
- [x] With no Night in the week, the title reads only "Your week".

A Night's lane and chart (Sleep view; the Night dated 3 Nov has Time in Bed 22:50–07:10, Sleep
Onset 23:00, Final Wake 07:00, Time Asleep 7 h 45 m, Sleeping HR 52, and Wake Bouts at 02:10 for
8 min and 04:30 for 7 min):
- [ ] Its block runs 23:00–07:00, unbroken, with notches at 02:10–02:18 and 04:30–04:37, on a
      track 22:50–07:10.
- [x] Its chart runs 22:50 to 07:10, with hour ticks at 00:00, 02:00, 04:00 and 06:00.
- [ ] The Sleeping HR line is at 52 with the tag "52 bpm"; with no Sleeping HR there is no line
      or tag.
- [x] The y-axis runs from the lowest step − 3 to the highest + 3 (steps 50 to 70: 47 to 73); a
      missing step breaks the line.
- [x] A Sleeping HR outside the steps widens the y-axis to take it in: steps 50 to 70 with
      Sleeping HR 44 run 41 to 73.
- [ ] The chart has no gridlines.
- [ ] Smoothed values (to 2 dp): steps all 60 but one of 74 draw that step at 63.58, the steps
      1, 2 and 3 away at 62.95, 61.64 and 60.62, and the rest at 60; a missing step among 60s
      stays missing and its neighbours draw at 60; the y-axis still runs from the steps as kept
      (60 to 74: 57 to 77).
- [ ] The asleep shading runs 23:00 to 07:00, labelled "asleep 23:00" and "07:00"; the Wake Bout
      columns run 02:10–02:18 and 04:30–04:37; under the chart it reads "Woke 2 times · 15 min
      awake".
- [x] One Wake Bout reads "Woke 1 time"; none reads "Didn't wake".
- [x] With no Time in Bed, the chart runs 23:00 to 07:00 and the bar has no track.
- [ ] With no Heart Rate Trace, its chart is "Heart rate isn't kept for Nights older than 30
      days.", its block has no notches, and its Time Asleep still reads "7h 45m".

Tonight (Sleep view; Nights dated 28 Oct to 3 Nov, each Sleep Onset 23:00, Final Wake 07:00):
- [x] With Time Asleep 8 h each, it reads "To get 8h 0m before your usual 07:00 wake, be asleep
      by 23:00." and the Tonight lane runs 23:00 to 07:00.
- [x] With Time Asleep 7 h each (Sleep Debt 7 h, Sleep Need capped at 9 h), it reads "To get
      9h 0m before your usual 07:00 wake, be asleep by 22:00."
- [x] With only Nights dated 1, 2 and 3 Nov, Final Wakes 06:50, 07:10 and 07:00 and Time Asleep
      8 h, it reads "… your usual 07:00 wake, be asleep by 23:00."
- [x] With only Nights dated 2 and 3 Nov, it reads only "A bedtime to aim for appears after 3
      Nights", and there is no Tonight lane.
- [x] With 2 Nov shown, there is no Tonight.

What stood out (Sleep view; the 3 Nov Night above, and Nights dated 28 Oct to 2 Nov each with
Sleep Onset 23:00):
- [x] Its rows read "Woke 2 times · 15 min awake" / "02:10 · 8 min · 04:30 · 7 min", "Fell asleep
      around your usual time" / "Usual 23:00, last night 23:00", and "Heart rate settled to 52
      bpm".
- [x] With 3 Nov's Sleep Onset at 23:40, the bedtime row reads "Fell asleep 40 min later than
      usual"; at 22:20, "Fell asleep 40 min earlier than usual"; at 23:30, "around your usual
      time".
- [x] With only 2 earlier Nights, there is no bedtime row; with no Wake Bouts kept, no Wake Bouts
      row; with no Sleeping HR, no heart rate row.

Build and phone:
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app with Xcode 26 against the iOS 26 SDK (its log names `iPhoneOS26`).
- [ ] On the phone (by hand, iOS 26): the tab bar is a floating glass capsule above the bottom
      edge with the selected tab on a lighter pill in the accent colour; both tabs' content
      scrolls under it, and the last card can be scrolled fully clear of it.
- [ ] On the phone (by hand, iOS 26): the Today popups, the Sleep popup, the profile menu and the
      date picker still open, read and close as before under the new SDK.
- [ ] On the phone (by hand): installed over the previous build, the tab bar shows Today and
      Sleep; picking a Day on one tab shows it on the other; backgrounding and reopening shows
      today on both.
- [ ] On the phone (by hand): the Sleep tab reads Summary, Your week (Last night's lane open, its
      trace smooth), Tonight, What stood out; tapping another lane opens its chart and closes the
      first; tapping it again closes it.
- [ ] On the phone (by hand): recent Nights show a Heart Rate Trace and Wake Bouts after the
      one-off rebuild; a Night older than 30 days shows the "not kept" note.
- [ ] On the phone (by hand): the Summary's and a lane's Sleep Score buttons open the Sleep popup.

## Non-goals (explicitly out of scope)
- Sleep stages, and Trends (its own tab and spec).
- Scrubbing the chart, marking the lowest heart rate, and HRV, respiratory rate, skin
  temperature or SpO2 through the night.
- More than three What stood out rows, or ranking them by how unusual they are.
- A minimum Wake Bout length, or merging short ones (tuning).
- Reminders or notifications for the bedtime.
- A custom tab bar, more tabs, a search tab, or an accessory above the tab bar (like the
  "Capture" button in iOS 26 apps); minimising the tab bar on scroll.
- Redesigning other screens for iOS 26 beyond what the new SDK changes on its own.
- Changing the Sleep popup (being redesigned separately) or the Today tab.
- Pruning History Records after 30 days (never built; see Notes).
- Naps.

## Open questions
- **Every number is an assumption** (5-minute steps, 150 records, 3 Nights, the 20:00–10:00
  axis, 15 min short or over, 30 min from the usual bedtime). Tune with real Nights.
- **Lane order.** Newest first, under the Tonight lane, as in the prototype. Assumed over oldest
  first so Last night sits next to Tonight.
- **Week strip.** The prototype left it out; this spec keeps it so picking a Day works as on
  Today.
- **Xcode 26 on CI.** Assumed available on GitHub's macOS runners (a `macos-26` image, or Xcode
  26 selected on `macos-15`); the plan's first task confirms which, and that the Swift 6 shell
  still compiles under it.
- **Sleeping HR against the trace.** Sleeping HR is the lowest *sustained* heart rate, so the
  lowest 5-minute step can sit a little above or below the dotted line. Assumed fine without a
  separate "lowest" marker.

## Notes
- Prototype: branch `prototype/sleep-screen-concepts`, file
  `src/SerenixApp/Prototype/sleep-screen-concepts-prototype.html`, variant E ("B + C: Night then
  week") with B's purple Tonight card. Serve the folder (`python -m http.server`, or the
  `prototypes` launch config on that branch) and open it with `?variant=E`. A (one big Night
  chart), B (sentence and insights only), C (week lanes only), D (24-hour dial) and F (week lanes
  picking the Night shown below) were the alternatives. The first build's stacked layout
  (branch `prototype/sleep-screen`, variant A) was rejected after it was built: its charts read
  poorly and the three sections didn't connect.
- Graphs prototype: branch `prototype/sleep-graphs`, file
  `src/SerenixApp/Prototype/sleep-graphs-prototype.html`, variant E ("B, smoother"): B's lane
  block with Wake Bout notches and its accent-coloured chart, with the smoothed monotone curve.
  A (as first built: gapped pills, red line over a separate band), C (heart rate as a colour
  strip and bars) and D (sparkline lanes, thin line with pins) were the alternatives.
- Spec 002 deferred the tab bar and the Sleep screen to this spec. The earlier home-screen
  prototype's Sleep tab (variant C) put score chips and metric tiles there; this spec doesn't.
- Extends spec 003: Nights from History Records also produce the Heart Rate Trace and Wake
  Bouts, and Night rebuilds gain the one-off queue. Reuses spec 009 (Sleep Need and Sleep Debt)
  and spec 010 (Sleep Consistency's median). Terms: Heart Rate Trace, Wake Bout (GLOSSARY.md).
- `docs/architecture.md` says History Records are kept 30 days, but nothing deletes them yet.
  This spec still treats Nights older than 30 days as having no Heart Rate Trace, as spec 003's
  rebuild rule does.
