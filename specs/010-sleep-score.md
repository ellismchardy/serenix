# 010 — Sleep Score

**Status:** built
**Last updated:** 2026-11-02 (built)
**Issue:** https://github.com/ellismchardy/serenix/issues/35 (map: https://github.com/ellismchardy/serenix/issues/31)

## Problem
The Today screen's left ring, the Sleep popup's first row and the Readiness popup's Sleep Score
row are all built (spec 002), but Sleep Score itself is never worked out, so every Night shows
"—". The ring meant to answer "how well did I sleep?" is empty.

## Goal
Each Night gets a Sleep Score from 0 to 100, from its Sleep Sufficiency, Sleep Efficiency and
Sleep Consistency, using the formula decided in issue #35. The Sleep popup shows each part as
its own ring, with what it was measured from.

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
out of 100; the Sleep popup's Sleep Score row and the Readiness popup's Sleep Score row show the
number.

**Sleep popup.** Under its Sleep Score row, three small rings side by side, in the accent colour
like the Sleep Score ring: **Sleep Sufficiency**, **Sleep Efficiency** and **Sleep
Consistency**. Each fills to its part out of 100 and shows it as a whole number (halves up),
with the part's name and, below, its detail:
- Sleep Sufficiency: Time Asleep "of" Sleep Need, as the Time Asleep tile writes them ("6h 0m of
  8h 0m").
- Sleep Efficiency: the share asleep as a whole percentage, halves up ("89% asleep").
- Sleep Consistency: the minutes off, rounded to whole minutes, in hours and minutes as the
  Readiness popup's differences write them ("35m off your usual", "1h 10m off your usual").

A part left out has an empty ring and "—", with the detail "Needs 3 Nights" for Sleep
Consistency and "—" for Sleep Efficiency. The rest of the popup (Time in Bed, Sleep Onset, Final
Wake, Time Asleep, Sleep Need, Sleep Debt, minutes awake) doesn't change. With Sleep Score
missing, the three rings read "—" too.

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
  detail.
- **`SerenixCore`: Night** loses its Sleep Score field; the Today view gets Sleep Score from the
  Sleep Score function instead (as spec 008 did for Readiness).
- **Shell.** The Sleep popup view draws the three small rings and their details, reusing the
  Sleep Score ring's drawing at a smaller size. The stored Night never had a Sleep Score, so
  nothing in SwiftData changes.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own name, 0–100). No new ADR: every
  constant is easy to change.

## Seams under test
- **Today view (`SerenixCore`)**, the seam of specs 002, 008 and 009, fed hand-built Nights with
  Time Asleep, Sleep Onset and Final Wake, a time zone and an optional birth year. Through the
  Sleep Score ring's text and fill, the Sleep popup and the Readiness popup it catches each
  part's formula and ends, the midnight wrap, the window and the 3-Night minimum, left-out parts
  and re-weighting, rounding, missing, and the popup's rings and details. It misses drawing,
  checked by hand on the phone (ADR 0002).

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

Missing and where it shows:
- [x] A Night with no Time Asleep reads "—" with the ring empty, and the Sleep popup's three
      rings read "—".
- [x] The Readiness popup's Sleep Score row shows the Night's Sleep Score ("96" for Time Asleep
      7 h 36 m, with spec 008's usual HRV and Sleeping HR and four earlier Nights).
- [x] No `SerenixCore` type still carries a stored Sleep Score on a Night.

Build and phone:
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): installed over the previous build, past Nights show a Sleep Score
      on the ring, and the Sleep popup shows three small rings with their details under the
      Sleep Score.
- [ ] On the phone (by hand): a Night after fewer than 3 earlier Nights shows Sleep Consistency
      empty with "Needs 3 Nights".

## Non-goals (explicitly out of scope)
- Sleep stages, time to fall asleep, and Sleeping HR or HRV as inputs (Sleeping HR is already
  in Readiness).
- A band or colour for Sleep Score (spec 002 keeps the ring in the accent colour), and Sleep
  Score in Readiness.
- Naps, and Sleep Score history or trends.
- Writing Sleep Score to Apple Health (it has no such type).
- Tuning the weights, the 95/75% and 2 h ends, and the 3-Night minimum against real Nights:
  after this ships.

## Open questions
- **Every number is an assumption** (0.6 / 0.2 / 0.2, 95%, 75%, 2 h, 3 Nights). Tune them once
  there are a few weeks of real Nights, changing constants and tests together.
- **Small rings colour.** Assumed the accent colour, like the Sleep Score ring, since none of
  the parts has a band.

## Notes
- Decision: issue #35. Evidence: `docs/research/sleep-score-without-stages.md`. Terms: Sleep
  Sufficiency, Sleep Efficiency, Sleep Consistency (GLOSSARY.md).
- Builds on spec 002 (ring, Sleep popup, Readiness popup's Sleep Score row) and spec 009 (Sleep
  Need, the 7-Night window).
- Map: issue #31. This is the map's last spec.
