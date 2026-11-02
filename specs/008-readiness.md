# 008 — Readiness

**Status:** draft
**Last updated:** 2026-11-02 (Time Asleep against Sleep Need, spec 009)
**Issue:** https://github.com/ellismchardy/serenix/issues/18 (map: https://github.com/ellismchardy/serenix/issues/12)

## Problem
The Today screen's middle ring, its band, the Readiness message and the Readiness popup are all
built (spec 002), but Readiness itself is never worked out, so every Night shows "—" once
Calibrating ends. The ring meant to answer "how ready am I today?" is empty.

## Goal
Each Night gets a Readiness from 0 to 100, worked out from its HRV and Sleeping HR against their
Baselines, its Time Asleep against its Sleep Need (spec 009), and the previous Day's Load against
typical Load, using the formula decided in issue #18.

## User stories
1. As a Strap owner, I want a Readiness number every morning, so the ring, band and advice say
   something.
2. As a Strap owner, I want HRV to count most, since it's the strongest sign of how recovered I
   am, with Sleeping HR, a short night and a hard Day before counting less.
3. As a Strap owner whose numbers swing a lot, I want each input judged against how much it
   usually varies for me, so an ordinary Night scores as usual.
4. As a Strap owner, I want a usual Night to land in Ready, near 70, with room above for a very
   good one.
5. As a Strap owner, I want one wild value not to sink the score on its own, so each input is
   capped.
6. As a Strap owner who didn't wear the Strap yesterday, or is missing a Sleeping HR, I still
   want a Readiness from what there is.
7. As a Strap owner, I want the Readiness popup to show all four inputs, so I can see why the
   number is what it is.
8. As a Strap owner whose Load for yesterday arrives on a later sync, I want Readiness to take it
   in without my doing anything.

## Behavior
**Inputs.** For a Night dated D (spec 002: the local date of its Final Wake), and its
**previous Day** D − 1 (midnight to midnight, the Day the Readiness advice calls "yesterday"):

| Input | Score (0 = usual for you, positive = better) | Weight |
|---|---|---|
| HRV | (ln HRV − ln Baseline) / Spread (spec 004, on ln RMSSD) | 0.50 |
| Sleeping HR | −(Sleeping HR − Baseline) / Spread | 0.25 |
| Time Asleep | −(hours short of the Night's Sleep Need, spec 009), e.g. 5 h 30 m against 8 h → −2.5; 0 at Sleep Need or more | 0.15 |
| Previous Day's Load | −(Load − typical Load) / 20 when the Load is above typical Load; otherwise 0 | 0.10 |

Each score is clamped to −3 to +3. Baselines are the Night's own (spec 004: up to 14 earlier
Nights, the Night itself left out). Typical Load is the previous Day's (spec 006: the median of up
to 28 Days before D − 1, not counting it). Scores use unrounded values.

**Score.** Z is the weighted sum of the scores. Readiness = 100 / (1 + e^(−2 × (Z + 0.42))),
rounded to a whole number with halves up. A usual Night (Z = 0) scores 70. The band (spec 002:
Ready 67–100, Steady 34–66, Take it easy 0–33) comes from the rounded number.

**Sleeping HR's Spread** (left open by spec 004). Worked out like HRV's and respiratory rate's,
over the same Nights as its median, in bpm:
- with 7 or more earlier Nights, the scaled MAD (1.4826 × the median of |value − median|), never
  below **1 bpm**;
- with 3 to 6 earlier Nights, the typical value, **2.5 bpm**.

Sleeping HR's Zone keeps spec 004's fixed +3 / +5 bpm gaps; only Readiness reads this Spread.
Readiness never reads Zones.

**Calibrating and missing.**
- **Calibrating** while the HRV or Sleeping HR Baseline is Calibrating, as now (spec 002: the
  ring empty, "n/4").
- **Missing** ("—", no band, no Readiness message) when the Night has no HRV.
- Otherwise, an input is **dropped** when the Night has no Sleeping HR, the previous Day has no
  Load, or typical Load is still calibrating (fewer than 4 Days). The remaining weights are
  scaled up to add to 1. A previous Day's Load at or below typical Load is not dropped: it
  scores 0.
- Time Asleep is always there when there's a Night.

**Always current.** Readiness is worked out whenever the Today view is, from the stored Nights
and Days. So when a later sync fills in the previous Day's Load, or rebuilds a Night that moves a
Baseline, Readiness follows with nothing stored to update. Nights no longer carry a stored
Readiness.

**Readiness popup.** Spec 002's popup gains two rows after HRV and Sleeping HR, each with a value,
a reference and a difference:
- **Time Asleep:** the Night's Time Asleep ("7h 30m"), the Night's Sleep Need as the reference
  ("8h 0m"), and the difference in hours and minutes ("−30m", "+1h 10m", "±0").
- **Yesterday's Load:** the previous Day's Load ("85"), its typical Load ("Typical 45"), and the
  signed difference ("+40", "−5", "±0"), as in spec 006. With the Load missing, the value and
  difference read "—"; with typical Load calibrating, the reference reads "Calibrating" and the
  difference "—", as there's nothing to measure against.

Sleep Score stays as it is. While Readiness is Calibrating the popup keeps its Calibrating
explanation.

**Unchanged.** The Readiness message's advice and reasons ("Yesterday's Load was high (82)" at 55
or more, HRV and Sleeping HR when they moved the bad way) and its Load caps (spec 002, spec 005);
vs your Baseline; the ring, band colours and Calibrating count.

## Design decisions
- **`SerenixCore`: Readiness (new).** A pure function: given a Night, its HRV and Sleeping HR
  Baselines, and the previous Day's Load and typical Load, it returns Readiness as a whole
  number, or missing. The Today view decides Calibrating, as before, and works out the previous
  Day once for Readiness, its advice and its popup. It takes the Night's Sleep Need (spec 009)
  as the Time Asleep mark. Weights, the Load divisor 20, the ±3 clamp, the curve's slope 2 and
  offset 0.42 are named constants, each citing issue #18 and
  `docs/research/readiness-composite-scores.md` ("assumption: tune with real Nights").
- **`SerenixCore`: Baseline** gains Sleeping HR's Spread (floor and typical value as named
  constants, issue #18). Zone doesn't change.
- **`SerenixCore`: typical Load** (spec 006) is reused as is, for the previous Day.
- **`SerenixCore`: Night** loses its Readiness field; the Today view gets Readiness from the
  Readiness function instead. Its output shapes keep their fields; the Readiness popup gains
  its Time Asleep and Yesterday's Load rows.
- **Shell.** The stored Night's Readiness field is no longer read (removed, or left unused if
  SwiftData migration needs it). Nothing else changes: the Today view already takes the Days.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own name, 0–100). No new ADR: every
  constant is easy to change.

## Seams under test
- **Today view (`SerenixCore`)**, the seam of specs 002 and 004, fed hand-built Nights and Days
  with known values. Through the Readiness text, band and popup it catches every weight, the
  clamp, the curve and rounding, the Spreads (typical, floor, MAD) including Sleeping HR's, the
  previous Day and typical Load, dropped inputs and re-weighting, missing and Calibrating, and
  the popup rows. It misses drawing and the stored field's removal, checked by hand on the
  phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`). Unless a criterion says otherwise: a Night dated 15 Nov 2026 with HRV
60 ms, Sleeping HR 52 bpm and Time Asleep 8 h; four earlier Nights each with HRV 60, Sleeping
HR 52 and Time Asleep 8 h (so typical Spreads: HRV 0.15, Sleeping HR 2.5 bpm, and Sleep Need
8 h with no Sleep Debt, spec 009); no birth year; and no Days, so the Load input is dropped.
Expected values worked by hand from the formula above.

Score:
- [x] The usual Night reads 70, Ready. With four Days before 14 Nov at Load 45 and 14 Nov at 40
      (at or below typical), it still reads 70.
- [x] HRV 50 reads 38, Steady; HRV 72 reads 90, Ready.
- [x] HRV 20 is clamped at −3 and reads 8, Take it easy.
- [x] Sleeping HR 57 reads 43; Sleeping HR 48 (better than usual) reads 85.
- [ ] Time Asleep 6 h reads 54; 7 h 59 m reads 70; 10 h reads 70 (against Sleep Need 8 h).
- [x] With four Days before 14 Nov at Load 45: 14 Nov at Load 65 reads 65, Steady; at 85, 61; at
      200, clamped at −3, 56.
- [ ] All four off at once (HRV 50, Sleeping HR 57, Time Asleep 5 h 30 m, 14 Nov at Load 85 over
      typical 45) reads 7, Take it easy.

Sleeping HR's Spread:
- [x] Sleeping HR 54 against four earlier Nights of 52 (typical 2.5 bpm) reads 60; against seven
      earlier Nights of 52 (Spread floored to 1 bpm) it reads 43.
- [x] Against seven earlier Nights of 50, 51, 52, 52, 52, 53, 54 (Baseline 52, Spread 1.4826 bpm),
      Sleeping HR 56 reads 34.
- [x] Zones don't change: against seven earlier Nights of 52, Sleeping HR 54 is still In range and
      56 still Watch.

Missing, dropped and Calibrating:
- [x] A Night with no HRV reads "—", with no band and no Readiness message.
- [x] HRV 50 with no Sleeping HR reads 26 (HRV and Time Asleep re-weighted).
- [x] With only three Days before 14 Nov at Load 45 (typical Load calibrating), 14 Nov at 85
      changes nothing: 70. With four but no Load on 14 Nov, also 70.
- [x] With one earlier Night, Readiness is Calibrating, "2/4", and with two, "3/4" (unchanged:
      the count includes the Night shown); with three, it reads a number.
- [x] Readiness follows the Days: the same Nights give 70 with no Day for 14 Nov and 61 once
      14 Nov has Load 85 over typical 45.

Popup:
- [x] The Readiness popup lists HRV, Sleeping HR, Time Asleep and Yesterday's Load, in that
      order.
- [ ] Its Time Asleep row: 7 h 30 m reads "7h 30m", "8h 0m", "−30m"; 9 h 10 m reads "+1h 10m";
      8 h reads "±0".
- [x] Yesterday's Load 85 over typical 45 reads "85", "Typical 45", "+40"; 40 reads "−5"; with no
      Load on 14 Nov, "—", "Typical 45", "—"; with typical Load calibrating (14 Nov at 85),
      "85", "Calibrating", "—".

Build and phone:
- [x] No `SerenixCore` type still carries a stored Readiness on a Night.
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): installed over the previous build, past Nights with 4 or more
      Nights before them show a Readiness number, band colour and Readiness message.
- [ ] On the phone (by hand): the Readiness popup shows the four rows, and its numbers match that
      Night's tiles and the previous Day's Load popup.

## Non-goals (explicitly out of scope)
- Retuning the Readiness advice, its reasons or Load caps to typical Load.
- Sleep Score (its own spec). How Sleep Need and Sleep Debt are worked out: spec 009.
- Respiratory rate, skin temperature or SpO2 as inputs; Resting HR (the awake one, spec 007).
- Smoothing inputs over several Nights, or a lagged Baseline.
- Readiness history or trends, or writing Readiness anywhere (Apple Health has no such type).
- Tuning the weights, curve, clamp and Spreads against real Nights: after this ships.

## Open questions
- **Every number is an assumption** (weights, 20, ±3, the curve, Sleeping HR's Spread).
  Tune them once there are a few weeks of real Nights, changing constants and tests together.
- **Typical Load from 4 Days** (spec 006) instead of #18's 7: decided here so typical Load means
  one thing. A 4-Day median is noisy, but the input only weighs 0.10.

## Notes
- Decision: issue #18 ("Resting HR" there is Sleeping HR since spec 007, #29). Evidence:
  `docs/research/readiness-composite-scores.md`.
- Builds on spec 002 (ring, band, message, popup), 004 (Baseline, Spread), 005 (Load) and 006
  (typical Load). Spec 004's open question on Sleeping HR's Spread is answered here.
- Map: issue #12. Its Time Asleep mark became Sleep Need with spec 009 (map: issue #31).
