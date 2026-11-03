# 010 — Sleep Score

**Status:** built
**Last updated:** 2026-11-03 (built: Sleep popup redrawn as prototype variant C)
**Issue:** https://github.com/ellismchardy/serenix/issues/35 (map: https://github.com/ellismchardy/serenix/issues/31)

## Problem
The Today screen's left ring, the Sleep popup's first row and the Readiness popup's Sleep Score
row are all built (spec 002), but Sleep Score itself is never worked out, so every Night shows
"—". The ring meant to answer "how well did I sleep?" is empty.

## Goal
Each Night gets a Sleep Score from 0 to 100, from its Sleep Sufficiency, Sleep Efficiency and
Sleep Consistency, using the formula decided in issue #35. The Sleep popup shows each part as
one of three nested rings, and draws what each was measured from: the Night on a timeline
against the user's usual times, and Time Asleep against Sleep Need.

## User stories
1. As a Strap owner, I want a Sleep Score every morning, so the left ring says something.
2. As a Strap owner, I want how much I slept against my Sleep Need to count most.
3. As a Strap owner who woke a lot in the night, I want a broken night to score lower than an
   unbroken one of the same length.
4. As a Strap owner who went to bed much later than usual, I want that to show in the score.
5. As a Strap owner who sleeps around midnight, I want 23:50 and 00:10 to count as 20 minutes
   apart, not most of a day.
6. As a new Strap owner, I want a Sleep Score from my first Night, even before Sleep Consistency
   has enough Nights to compare against.
7. As a Strap owner, I want the Sleep popup to show each part's score and what it came from, so
   I can see why the number is what it is.
8. As a Strap owner, I want to see when I slept against when I usually sleep, and how much I
   slept against what I needed, so the parts make sense at a glance.
9. As a Strap owner who sleeps 03:00 to 12:00, I want the timeline to fit my Night, not cut it
   off.

## Behavior
For a Night dated D (spec 002: the local date of its Final Wake). Clock times are local, in the
Today view's time zone. Each part is a score from 0 to 100, kept unrounded until shown.

**Sleep Sufficiency.** Time Asleep ÷ the Night's Sleep Need (spec 009) × 100, at most 100. E.g.
6 h against 8 h is 75.

**Sleep Efficiency.** The share of the Sleep Period asleep: Time Asleep ÷ (Final Wake − Sleep
Onset). 100 at 95% or more, falling in a straight line to 0 at 75%, and 0 below. E.g. 8 h asleep
in a 9 h Sleep Period (88.9%) is 69.4.

**Sleep Consistency.** The Nights dated D − 7 to D − 1 (D left out) that have both a Sleep Onset
and a Final Wake count. For each of Sleep Onset and Final Wake: take the signed difference
between tonight's clock time and each counting Night's, the shortest way round the clock
(between −12 h and +12 h), and the size of their median is how far off tonight was. "Minutes
off" is the mean of the two. 100 at 0 minutes off, falling in a straight line to 0 at 2 h off,
and 0 beyond. E.g. Sleep Onset 30 min and Final Wake 40 min later than usual: 35 min off, 70.8.
Tonight at 00:10 against 23:50, 23:40 and 00:20 is +20, +30 and −10 minutes: 20 min off.

**Sleep Score.** 0.6 × Sleep Sufficiency + 0.2 × Sleep Efficiency + 0.2 × Sleep Consistency,
from unrounded parts, rounded to a whole number with halves up.

**Missing and left out.**
- **Missing** ("—", the ring empty) when the Night has no plausible Time Asleep (as the Time
  Asleep tile treats it).
- **Sleep Efficiency is left out** when the Night has no Sleep Onset or Final Wake, or Time
  Asleep is longer than Final Wake − Sleep Onset (the Sleep popup's minutes awake then reads
  "—", spec 002).
- **Sleep Consistency is left out** when the Night shown has no Sleep Onset or Final Wake, or
  fewer than **3** Nights count.
- The parts left are re-weighted to add to 1 (e.g. 0.75 / 0.25 without Sleep Consistency). Sleep
  Score is never Calibrating.

**Always current.** Sleep Score is worked out whenever the Today view is, from the stored Nights
and the Profile's birth year (through Sleep Need), and never stored. Nights no longer carry a
stored Sleep Score.

**Where it shows.** The Sleep Score ring (accent colour, no band, spec 002) fills to the score
out of 100; the Sleep popup's top card and the Readiness popup's Sleep Score row show the
number.

**Sleep popup.** Three cards, top to bottom. It has no list of plain rows: every value the list
held (spec 002, spec 009) is in a card.

1. **Sleep Score.** The Sleep Score as a big number ("—" when missing), and on the right three
   nested rings, each filling to its part out of 100: **Sleep Sufficiency** outside, **Sleep
   Efficiency** in the middle, **Sleep Consistency** inside, in three shades of the accent
   colour, strongest outside (darkest in Light, brightest in Dark). Under the number a key
   names each part with its shade and its score as a whole number (halves up). A part left
   out, and every part when Sleep Score is missing, has an empty ring and "—" in the key.
2. **When you slept.** A timeline of the Night, with Sleep Consistency's detail beside its
   heading, and below it a caption with Time in Bed (start–end), the minutes awake and Sleep
   Efficiency's detail. On the timeline:
   - Time in Bed as a light band; not drawn when the Night has no Time in Bed.
   - The Sleep Period as an accent bar from Sleep Onset to Final Wake, each end labelled with
     its clock time.
   - The user's **usual Sleep Onset** and **usual Final Wake** as dashed lines, each labelled
     "usual" and its clock time: tonight's clock time minus the median signed difference Sleep
     Consistency works out for it, so the gap drawn is the one Sleep Consistency measured.
     Drawn only when Sleep Consistency isn't left out.
   - The axis starts at the earliest time drawn, rounded down to the whole local hour, and ends
     at the latest, rounded up (a time on the hour stays), with the local hour labelled every
     2 hours from the start ("22", "00", "02"). Positions are shares of the axis, 0 to 1.
   - With no Sleep Onset or Final Wake, the card reads "No Sleep Period for this Night" in
     place of the timeline; the caption stays.
3. **How much you slept.** A bar for Time Asleep with a marker for Sleep Need, on a scale of
   whichever is longer: the bar fills to Time Asleep ÷ that and the marker sits at Sleep Need
   ÷ that (so 6 h against 8 h fills 0.75 with the marker at the end, and 9 h against 8 h fills
   the bar with the marker at 0.89). With no Time Asleep the bar is empty and the marker at the
   end. Under it "8h 0m asleep" and "needed 8h 0m" (as the Time Asleep tile writes them, "—"
   for no Time Asleep), and Sleep Debt with its caption (spec 009).

Each part's detail:
- Sleep Sufficiency: Time Asleep "of" Sleep Need, as the Time Asleep tile writes them ("6h 0m of
  8h 0m").
- Sleep Efficiency: the share asleep as a whole percentage, halves up ("89% asleep"); "—" when
  left out.
- Sleep Consistency: the minutes off, rounded to whole minutes, in hours and minutes as the
  Readiness popup's differences write them ("35m off your usual", "1h 10m off your usual");
  "Needs 3 Nights" when left out.

With Sleep Score missing, the details read "—".

## Design decisions
- **`SerenixCore`: Sleep Score (new).** A pure function: given the Night, the Nights before it,
  its Sleep Need (spec 009) and the time zone, it returns each part (or left out) and the Sleep
  Score, or missing. The weights 0.6 / 0.2 / 0.2, Sleep Efficiency's 95% and 75%, Sleep
  Consistency's 2 h and 3 Nights are named constants, each citing issue #35 and
  `docs/research/sleep-score-without-stages.md` ("assumption: tune with real Nights"). The 7-Night
  window reuses Sleep Need's.
- **`SerenixCore`: Today view** works out Sleep Score once for the Night shown from the Sleep
  Need it already has, and uses it for the ring, the Sleep popup and the Readiness popup.
- **`SerenixCore`: Sleep popup** gains the three parts, each with its score text, ring fill and
  detail, and decides everything the cards draw: the timeline's axis start and end and its hour
  labels with their positions, the positions of Time in Bed, Sleep Onset, Final Wake and the
  usual Sleep Onset and Final Wake (each absent when not drawn), and the Time Asleep bar's fill
  and Sleep Need marker. Sleep Score exposes the median signed differences it already works out,
  so the usual times are never worked out a second way.
- **`SerenixCore`: Night** loses its Sleep Score field; the Today view gets Sleep Score from the
  Sleep Score function instead (as spec 008 did for Readiness).
- **Shell.** The Sleep popup view draws the three cards from those positions and texts, and
  works nothing out; the nested rings reuse the Sleep Score ring's drawing. The stored Night
  never had a Sleep Score, so nothing in SwiftData changes.
- **Look** from prototype variant C (`?variant=C`, branch `prototype/sleep-score-popup-ui`).
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own name, 0–100). No new ADR: every
  constant is easy to change.

## Seams under test
- **Today view (`SerenixCore`)**, the seam of specs 002, 008 and 009, fed hand-built Nights with
  Time Asleep, Sleep Onset and Final Wake, a time zone and an optional birth year. Through the
  Sleep Score ring's text and fill, the Sleep popup and the Readiness popup it catches each
  part's formula and ends, the midnight wrap, the window and the 3-Night minimum, left-out parts
  and re-weighting, rounding, missing, and the popup's rings, details, timeline positions, usual
  times and Sleep Need bar. It misses drawing, checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`). Unless a criterion says otherwise: the Night shown is dated 15 Nov
2026 with Sleep Onset 23:00 on 14 Nov, Final Wake 07:00 and Time Asleep 8 h; no earlier Nights
(so Sleep Need 8 h, and Sleep Consistency left out); no birth year; times in Europe/London (GMT,
so local equals UTC). "Earlier Nights" for Sleep Consistency carry only a Sleep Onset and Final
Wake, so they don't change Sleep Need. Expected values worked by hand from the rules above.

Score and Sleep Sufficiency:
- [x] The default Night reads 100, the ring fills to 1.0, and the Sleep popup shows Sleep
      Sufficiency "100" ("8h 0m of 8h 0m"), Sleep Efficiency "100" ("100% asleep") and Sleep
      Consistency "—" ("Needs 3 Nights").
- [x] Time Asleep 6 h with Final Wake 05:18 (95.2% asleep) reads 81: Sleep Sufficiency "75"
      ("6h 0m of 8h 0m"), Sleep Efficiency "100".
- [x] Time Asleep 7 h 36 m (95% of 23:00–07:00) reads 96, and the ring fills to 0.96.
- [x] After four earlier Nights of Time Asleep 6 h (Sleep Need 9 h, spec 009), the default Night
      reads 92, with Sleep Sufficiency "89" ("8h 0m of 9h 0m").

Sleep Efficiency:
- [x] Sleep Onset 22:00 (8 h asleep in 9 h) reads 92, with Sleep Efficiency "69" ("89% asleep").
- [x] Sleep Onset 20:00 (8 h asleep in 11 h, 72.7%) reads 75, with Sleep Efficiency "0".
- [x] A Night with no Sleep Onset and Time Asleep 6 h reads 75 (Sleep Sufficiency alone), with
      Sleep Efficiency "—" ("—").
- [x] Sleep Onset 23:30 (Time Asleep 8 h longer than 7 h 30 m) reads 100, with Sleep Efficiency
      "—".

Sleep Consistency (earlier Nights dated 14, 13 and 12 Nov, each 23:00 to 07:00 unless said):
- [x] Tonight at 23:00 to 07:00 reads 100, with Sleep Consistency "100" ("0m off your usual").
- [x] Tonight at 23:30 to 07:40 (Time Asleep 8 h) reads 94, with Sleep Consistency "71" ("35m off
      your usual").
- [x] Tonight at 01:00 to 09:00 reads 80, with Sleep Consistency "0" ("2h 0m off your usual").
- [x] Earlier Sleep Onsets 23:50, 23:40 and 00:20 with Final Wakes 08:10, and tonight at 00:10 to
      08:10, read 98, with Sleep Consistency "92" ("10m off your usual").
- [x] With only two earlier Nights, or three where one has no Final Wake, Sleep Consistency is
      "—" ("Needs 3 Nights") and the Night reads 100.
- [x] An earlier Night dated 8 Nov counts and one dated 7 Nov doesn't: 13 Nov, 12 Nov and 8 Nov
      at 01:00 to 09:00 give Sleep Consistency "0"; 13 Nov, 12 Nov and 7 Nov leave it "—".

Sleep popup timeline (positions are shares of the axis, to 3 decimal places):
- [x] The default Night with Time in Bed 22:40 to 07:15 has an axis from 22:00 to 08:00, hours
      "22", "00", "02", "04", "06", "08" at 0, 0.2, 0.4, 0.6, 0.8 and 1.0, Time in Bed from 0.067
      to 0.925, Sleep Onset "23:00" at 0.1 and Final Wake "07:00" at 0.9, no usual times, and
      Sleep Consistency's detail "Needs 3 Nights".
- [x] The default Night with no Time in Bed has no Time in Bed on the timeline, and an axis from
      23:00 to 07:00 (times on the hour aren't rounded out), hours "23", "01", "03", "05", "07".
- [x] With earlier Nights dated 14, 13 and 12 Nov at 23:00 to 07:00 and tonight at 23:30 to 07:40,
      the usual Sleep Onset is "23:00" at 0 and the usual Final Wake "07:00" at 0.889, on an axis
      from 23:00 to 08:00, with Sleep Onset at 0.056 and Final Wake at 0.963.
- [x] With earlier Sleep Onsets 23:50, 23:40 and 00:20, Final Wakes 08:10, and tonight at 00:10
      to 08:10, the usual Sleep Onset is "23:50" and the usual Final Wake "08:10", on an axis
      from 23:00 to 09:00.
- [x] A Night from 03:00 to 12:00 on 15 Nov (Time Asleep 8 h, no Time in Bed) has an axis from
      03:00 to 12:00, hours "03", "05", "07", "09", "11", and Final Wake at 1.0.
- [x] A Night with no Sleep Onset has no timeline (the popup reads "No Sleep Period for this
      Night").

Sleep popup Sleep Need bar:
- [x] The default Night fills to 1.0 with the marker at 1.0, reading "8h 0m asleep" and "needed
      8h 0m".
- [x] Time Asleep 6 h (Final Wake 05:18) fills to 0.75 with the marker at 1.0.
- [x] Time Asleep 9 h with Sleep Onset 22:00 (Sleep Need 8 h) fills to 1.0 with the marker at
      0.889.
- [x] A Night with no Time Asleep is empty with the marker at 1.0, reading "—" asleep.

Missing and where it shows:
- [x] A Night with no Time Asleep reads "—" with the ring empty, and the Sleep popup's three
      nested rings are empty, with every part's score and detail "—".
- [x] The Readiness popup's Sleep Score row shows the Night's Sleep Score ("96" for Time Asleep
      7 h 36 m, with spec 008's usual HRV and Sleeping HR and four earlier Nights).
- [x] No `SerenixCore` type still carries a stored Sleep Score on a Night.

Build and phone:
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): installed over the previous build, past Nights show a Sleep Score
      on the ring, and the Sleep popup shows the three cards (Sleep Score with nested rings,
      When you slept, How much you slept) and no list of plain rows, in Light and Dark.
- [ ] On the phone (by hand): a Night after fewer than 3 earlier Nights shows Sleep Consistency's
      inner ring empty, "Needs 3 Nights", and no usual-time lines.

## Non-goals (explicitly out of scope)
- Sleep stages, time to fall asleep, and Sleeping HR or HRV as inputs (Sleeping HR is already
  in Readiness).
- A band or colour for Sleep Score (spec 002 keeps the ring in the accent colour), and Sleep
  Score in Readiness.
- Naps, and Sleep Score history or trends.
- Writing Sleep Score to Apple Health (it has no such type).
- Drawing wake bouts inside the Sleep Period on the timeline (they aren't stored), and any
  change to the Sleep Score ring or the Readiness popup.
- Tuning the weights, the 95/75% and 2 h ends, and the 3-Night minimum against real Nights:
  after this ships.

## Open questions
- **Every number is an assumption** (0.6 / 0.2 / 0.2, 95%, 75%, 2 h, 3 Nights). Tune them once
  there are a few weeks of real Nights, changing constants and tests together.

## Notes
- Decision: issue #35. Evidence: `docs/research/sleep-score-without-stages.md`. Terms: Sleep
  Sufficiency, Sleep Efficiency, Sleep Consistency (GLOSSARY.md).
- Builds on spec 002 (ring, Sleep popup, Readiness popup's Sleep Score row) and spec 009 (Sleep
  Need, the 7-Night window).
- Changes spec 002: its Sleep popup becomes the three cards above (spec 009's Sleep Need and
  Sleep Debt rows move into the third), and the stored Nights no longer carry a Sleep Score
  (worked out here, as spec 008 did for Readiness).
- The popup's design was chosen from four variants in a throwaway prototype: variant C ("Night
  timeline"), branch `prototype/sleep-score-popup-ui`, file
  `src/SerenixApp/Prototype/sleep-popup-prototype.html` (`?variant=C`). Its fixed 21:00–11:00
  axis and its usual times (fixed per sample Night) were replaced by the rules above.
- Map: issue #31. This is the map's last spec.
