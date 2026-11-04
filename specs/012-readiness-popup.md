# 012 — Readiness popup

**Status:** approved
**Last updated:** 2026-11-04 (approved: header redrawn as a band scale, prototype variant B)

## Problem
The Readiness popup (specs 002 and 008) shows the number, the band word and a table of four
rows: value, reference and difference. It says what each input was, but not which one mattered.
A user who reads 34 can't tell whether a short night or a drop in HRV cost them the points, and
the popup doesn't show whether today is a one-off or part of a run.

## Goal
The Readiness popup shows the number large in its band's colour on a scale of the three bands,
says in one sentence what pulled it down, lists the four inputs from the biggest effect to the
smallest (each with its points, a plain reason and a gauge), and shows the last 7 Days of
Readiness.

## User stories
1. As a Strap owner, I want the popup to name the input that cost me the most, so that I don't
   have to work it out from a table.
2. As a Strap owner, I want each input's points, which add up to how far I am from a usual Night
   (70), so that I can see how much each one counted.
3. As a Strap owner, I want each input in a plain sentence ("2h 15m short of your Sleep Need"),
   so that I know what the number means without reading a reference column.
4. As a Strap owner, I want a gauge per input from worse to better, so that I can see at a glance
   how far each one was from usual.
5. As a Strap owner, I want my last 7 Days of Readiness, so that I can see whether today is a
   one-off or a run.
6. As a Strap owner with no Load yesterday, or no Sleeping HR last night, I want that input shown
   as left out with the reason, not as a guess.
7. As a new Strap owner who is still Calibrating, I want the popup to keep saying how many Nights
   it still needs.
8. As a Strap owner, I want to see where my number sits among Take it easy, Steady and Ready, and
   against a usual Night (70), so that I know how close I am to the next band.

## Behavior
**Opening.** Tapping the Readiness ring opens the popup for the Night shown, as in spec 002. It
slides up and closes like the other popups.

**Top to bottom.**
1. **Heading:** "Readiness" and the Day shown's date.
2. **Band scale card:**
   - the number, large, in the band's colour, with the band word (spec 002) beside it;
   - the **verdict** under them;
   - a **band scale**: a bar from 0 to 100 in three segments, Take it easy (0 to 0.34), Steady
     (0.34 to 0.67) and Ready (0.67 to 1), each in its band's colour. The Night's band is at
     full colour and the others are faded. A **marker** sits at Readiness / 100, and a tick at
     0.70 is labelled "usual 70". The band words sit under their segments.
3. **Why, biggest effect first:** under that heading, one row per input (HRV, Sleeping HR, Time
   Asleep, Yesterday's Load). Each row has:
   - the input's name, and its weight as a whole-number percentage ("56%"), or "dropped";
   - its value as in spec 008's popup rows ("50 ms", "7h 30m", "85", or "—");
   - its **points** ("−23 pts", "+12 pts", "±0 pts"), none for a dropped input;
   - its **reason** (below);
   - a **gauge**, for an input that isn't dropped: a bar running worse, usual, better, with a
     tick at the middle labelled "usual", and a marker at 0.5 + score / 6, where score is the
     input's clamped score from spec 008 (−3 to +3), so 0 to 1 from left to right.

   Rows run from the lowest points to the highest; dropped inputs come last. Equal points keep
   the order HRV, Sleeping HR, Time Asleep, Yesterday's Load.
4. **Your week:** 7 bars, the Day shown and the 6 Days before it, oldest on the left. Each bar's
   height is that Day's Readiness (of the Night dated that Day), in its band colour, labelled
   with the weekday and the number. A Day with no Readiness (no Night, missing or Calibrating)
   is a hatched bar labelled "—". The Day shown's bar is outlined. Bars can't be tapped.
5. **Sleep Score:** a row with the Night's Sleep Score, as now.

**Points.** Each input's points are its share of how far Readiness is from a usual Night:
- Each input's weighted score is its re-weighted weight (spec 008) × its clamped score; Z is
  their sum.
- Its unrounded points are its weighted score × (curve(Z) − curve(0)) / Z, with curve as in spec
  008. At Z = 0 the factor is the curve's slope at 0 (about 42.13).
- Points are rounded to whole numbers so that they add up to Readiness − 70: each is rounded
  down, and the shortfall goes one point at a time to the inputs with the largest fractional
  parts (largest remainder). A dropped input has no points.

**Verdict.**
- "Your body looks recovered." when no input has −3 points or fewer.
- Otherwise "<input> pulled it down most.", naming the input with the lowest points ("Time
  Asleep pulled it down most."). Ties go to the first in the order HRV, Sleeping HR, Time
  Asleep, Yesterday's Load.

**Reasons.** The difference and reference texts are spec 008's popup row texts.
- HRV: "<difference> against your usual <reference>." ("−17% against your usual 60 ms.")
- Sleeping HR: the same ("+5 bpm against your usual 52 bpm.").
- Time Asleep: "<difference without its sign> short of your Sleep Need." when short; otherwise
  "Enough for your Sleep Need."
- Yesterday's Load: "Above your typical <typical Load>." when over; otherwise "No more than your
  typical <typical Load>."
- Dropped: "No Sleeping HR for this Night, so it's left out."; "No Load for yesterday, so it's
  left out."; "Typical Load is still calibrating, so it's left out."

**Calibrating.** The number reads "n/4" as on Today, greyed, with no band word; the band scale is
all faded with no marker and no tick; there's no Why list; the verdict is spec 002's Calibrating
explanation. Your week and Sleep Score show as usual.

**Missing** (no HRV, spec 008). The number reads "—", greyed, with no band word; the band scale
is all faded with no marker and no tick; the verdict is "No HRV for this Night, so there's no
Readiness."; and there's no Why list. Your week and Sleep Score show as usual.

**Gone.** Spec 008's popup table (value, against and difference columns) is replaced by the Why
list, and the popup's ring by the band scale. The Readiness ring and message on Today (spec 002)
don't change.

## Design decisions
- **`SerenixCore`: Readiness popup** (the Today view's popup content, reshaped). For the Night
  shown it gives: Readiness text and band; the band scale's segments (band and from–to
  position) and its marker and usual-Night tick positions, or none; the verdict text; the Why
  rows in order (name, weight text, value text, points text or none, reason, gauge position or
  none); 7 week
  bars (weekday, Readiness or none, band, which is the Day shown); and the Sleep Score text. It
  decides; it doesn't draw.
- **`SerenixCore`: Readiness** exposes each input's clamped score and re-weighted weight, so the
  popup's points and gauges come from the same numbers as the score. The points' factor and the
  largest-remainder rounding live with it.
- **`SerenixCore`: ReadinessBand** gives each band's stretch of 0 to 1 from its cut-offs
  (spec 002), so the scale and the band word can't disagree.
- **iOS shell:** draws the popup and maps bands to colours, as for the ring. Nothing new is
  stored: the week's Readiness is worked out from the stored Nights and Days, like today's.
- Supersedes spec 008's Readiness popup rows. Layout from prototype variant E; header from
  variant B of the header prototype.

## Seams under test
- **`SerenixCore` Today view** (its Readiness popup content), the seam of specs 002 and 008 —
  catches every number, weight, point, gauge position, reason, verdict, row order, week bar and
  band scale position; misses drawing, colours and layout, checked by hand on the phone (ADR
  0002).

## Success criteria (must be checkable)
Unless a criterion says otherwise, spec 008's set-up: a Night dated 15 Nov 2026 with HRV 60 ms,
Sleeping HR 52 bpm and Time Asleep 8 h; four earlier Nights the same; no Days (Load dropped).

Automated (`swift test`), Today view:
- [x] The usual Night: Readiness 70, Ready, verdict "Your body looks recovered.", every input
      "±0 pts" with gauge at 0.5, weights "56%", "28%", "17%", and Yesterday's Load last,
      "dropped", reason "No Load for yesterday, so it's left out.", no gauge.
- [x] HRV 50: Readiness 38; HRV "−32 pts", reason "−17% against your usual 60 ms.", gauge at
      0.2974 (to 4 dp), first in the list; verdict "HRV pulled it down most."
- [x] All four off (HRV 50, Sleeping HR 57, Time Asleep 5 h 30 m, 14 Nov at Load 85 over typical
      45): Readiness 7; points HRV −23, Sleeping HR −19, Time Asleep −14, Yesterday's Load −7
      (adding to −63), listed in that order; weights 50%, 25%, 15%, 10%; Time Asleep's reason
      "2h 30m short of your Sleep Need."; Load's "Above your typical 45."; Sleeping HR's gauge at
      0.1667 (to 4 dp).
- [x] HRV 72 and Time Asleep 6 h: Readiness 82; HRV "+24 pts", Time Asleep "−12 pts", Sleeping
      HR "±0 pts"; list order Time Asleep, Sleeping HR, HRV; verdict "Time Asleep pulled it down
      most."
- [x] Inputs that cancel (Z = 0, e.g. HRV score +1 and Sleeping HR score −2): Readiness 70; HRV
      "+23 pts", Sleeping HR "−23 pts".
- [x] HRV clamped at −3 (HRV 20): its gauge is at 0.
- [x] A Night with no Sleeping HR: Sleeping HR last, "dropped", reason "No Sleeping HR for this
      Night, so it's left out."; with typical Load calibrating, Load's reason is "Typical Load is
      still calibrating, so it's left out."
- [x] Time Asleep 10 h: reason "Enough for your Sleep Need."; Load at or below typical: "No more
      than your typical 45."
- [x] Calibrating (2 Nights): no band, no Why rows, verdict spec 002's Calibrating explanation.
- [x] No HRV: Readiness "—", no band, no Why rows, verdict "No HRV for this Night, so there's no
      Readiness."
- [x] The week holds 15 Nov and the 6 Days before, oldest first, with weekday labels; a Day with
      no Night and a Calibrating Day have no Readiness; 15 Nov is the Day shown.
- [x] Points always add up to Readiness − 70 when Readiness has a number.

Band scale:
- [ ] The scale's segments are Take it easy 0 to 0.34, Steady 0.34 to 0.67 and Ready 0.67 to 1,
      whatever the Night.
- [ ] The usual Night: marker at 0.70 and the usual tick at 0.70; HRV 50 (Readiness 38): marker
      at 0.38, band Steady; all four off (Readiness 7): marker at 0.07, band Take it easy.
- [ ] Calibrating and No HRV: no marker and no usual tick.

By hand on the phone:
- [ ] Tapping the Readiness ring opens the popup with the number and band word, the verdict,
      the band scale with its marker, the Why list with gauges, Your week and Sleep Score, in
      Light and Dark, and it closes with a tap outside or a swipe down.

## Non-goals (explicitly out of scope)
- Changing Readiness itself (spec 008's formula, weights and bands).
- Changing the Readiness message on Today, or its advice.
- Tapping a week bar to switch Day, or a row to open a metric popup.
- Explanatory text about what Readiness is (could follow spec 011's What it is later).

## Open questions
- None. Assumption: the Missing popup keeps Your week and Sleep Score, as Calibrating does.

## Notes
- Header prototype: branch `prototype/readiness-popup-header`,
  `src/SerenixApp/Prototype/readiness-header-prototype.html?variant=B` (big number on a band
  scale), chosen over the ring (A), a half-dial (C), a band-tinted card (D) and verdict-first (E).
- Prototype: branch `prototype/readiness-popup-ui`,
  `src/SerenixApp/Prototype/readiness-popup-prototype.html?variant=E` (B's ring and gauges with
  C's reasons and week). Its points are added in order; this spec splits them by share instead,
  so they don't depend on order.
- Related: spec 002 (Today, Readiness ring and message), spec 008 (Readiness), spec 011 (metric
  popup, the same popup style).
