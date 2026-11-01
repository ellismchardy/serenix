# 004 — Baseline and Zones

**Status:** approved
**Last updated:** 2026-11-01
**Issue:** https://github.com/ellismchardy/serenix/issues/14 (map: https://github.com/ellismchardy/serenix/issues/12)

## Problem
The Today screen (spec 002) colours each Nightly Metric by its Zone, but the cut-offs are the
prototype's placeholders: HRV is judged by a fixed percentage and only on the low side, and
Resting HR goes amber at just +1 bpm. Someone whose HRV naturally swings a lot sees false alarms,
and someone whose HRV barely moves sees none. A Zone should answer "is tonight off *for you*?",
which means comparing each metric against how much it usually varies for the user.

## Goal
Each Night's Baseline also gives each metric's Spread. Zones use rules from the research in
issue #14: Spread-scaled for HRV and respiratory rate, and fixed gaps or levels for Resting HR,
skin temperature and SpO2.

## User stories
1. As a Strap owner whose HRV varies a lot from Night to Night, I want an ordinary swing to stay
   In range, so that I only see amber or red when the Night is unusual for me.
2. As a Strap owner whose HRV is very steady, I want a small but unusual drop to show as Watch.
3. As a Strap owner, I want an unusually high HRV to show as Watch (never Out of range), because
   it can be a sign of overreaching, but the evidence for that is weaker.
4. As a Strap owner, I want Resting HR to warn me only when it rises (+3 bpm Watch, +5 bpm Out of
   range), since a lower Resting HR is not a warning sign.
5. As a new Strap owner with only a few Nights, I want Zones from my 4th Night, using a typical
   Spread until Serenix has enough Nights to measure mine.
6. As a Strap owner whose respiratory rate barely changes, I don't want a 0.2 br/min wobble to
   count as Out of range, so the Spread has a floor.

## Behavior
**Baseline.** Unchanged from spec 002. For a given Night and metric (Resting HR, HRV,
respiratory rate, skin temperature), the Baseline is the **median** of that metric over the
up-to-14 most recent *earlier* Nights that have a value for it. With an even count it is the
mean of the two middle values. The Night itself is never part of its own Baseline, and an
earlier Night is compared against its own Baseline. Missing values are skipped, never counted
as 0. A metric's Baseline is Calibrating until 3 earlier Nights have it, so the 4th Night with
a value is the first with a Baseline. SpO2 has no Baseline.

**Spread.** HRV's and respiratory rate's Baselines also have a Spread, worked out over the
same Nights as the median:
- **With 7 or more earlier Nights** (counting all earlier Nights with a value, not only the 14
  used), the Spread is the scaled MAD: 1.4826 × the median of |value − median|. It is never
  below the metric's floor.
- **With 3 to 6 earlier Nights**, the Spread is the metric's typical value.
- HRV's Spread is on **ln(RMSSD)**: the MAD of the ln values around ln(Baseline). Respiratory
  rate's is in br/min.

| Metric | Floor | Typical value |
|---|---|---|
| HRV (ln RMSSD) | 0.10 | 0.15 |
| Respiratory rate (br/min) | 0.3 | 0.5 |

Resting HR and skin temperature have no Spread yet: their Zones use fixed gaps. Resting HR's
Spread comes with the Readiness spec, which is the first to use it. The Spread is never shown in
the app.

**Zones.** A Zone compares **the Night's own value**, with no smoothing, against that Night's
Baseline. They are worked out on unrounded values. Every cut-off is a named assumption, to be
tuned once there are real Nights. For HRV, z = (ln value − ln Baseline) / Spread. For
respiratory rate, z = (value − Baseline) / Spread.

| Metric | Rule | In range | Watch | Out of range |
|---|---|---|---|---|
| HRV | Spread-scaled, both ways; the high side never goes past Watch | −1.5 ≤ z ≤ +2.5 | −2.5 ≤ z < −1.5, or z > +2.5 | z < −2.5 |
| Respiratory rate | Spread-scaled, both ways | \|z\| ≤ 1.5 | 1.5 < \|z\| ≤ 2.5 | \|z\| > 2.5 |
| Resting HR, d = value − Baseline (bpm) | Fixed gap, up only | d < 3 | 3 ≤ d < 5 | d ≥ 5 |
| Skin temperature, \|value − Baseline\| (°C) | Fixed gap, both ways | ≤ 0.3 | ≤ 0.6 | > 0.6 |
| SpO2 (%) | Fixed levels, low only, no Baseline | ≥ 95 | 92 ≤ value < 95 | < 92 |

A value exactly on a cut-off falls on the side the table gives it, even after floating-point
rounding. A metric that is Calibrating or missing has no Zone (spec 002).

**Status words** (on the tile, spec 002): "Normal" when In range. Otherwise "Low" or "High",
by which side of the Baseline the value is on. HRV can now be "High". Resting HR below its
Baseline is always In range, so it reads "Normal". SpO2 keeps its level words.

**Gauge** (on the tile): Baseline at 0.5, clamped to 0–1, with the end of each side where Watch
turns into Out of range:
- HRV and respiratory rate: 0.5 + z / (2 × 2.5).
- Resting HR: 0.5 + d / (2 × 5), symmetric even though only the upper side changes the Zone.
- Skin temperature: 0.5 + d / (2 × 0.6), unchanged.
- SpO2: unchanged, a fixed scale from 88% to 100%.

**In range band** (Nightly Metric popup, spec 002): the values that are In range, with no limit
on a side that has none:
- HRV: exp(ln Baseline − 1.5 × Spread) to exp(ln Baseline + 2.5 × Spread), in ms.
- Respiratory rate: Baseline ± 1.5 × Spread.
- Resting HR: no lower limit, upper limit Baseline + 3.
- Skin temperature: Baseline ± 0.3.
- SpO2: no band.

**Unchanged.** "vs your Baseline" still shows HRV as a percentage and Resting HR in bpm. The
Readiness advice still names HRV and Resting HR when they moved the bad way. The Baseline the
app shows is still the median in the metric's unit (e.g. "60 ms").

## Design decisions
- **`SerenixCore`: Baseline** gains a Spread next to its median: nil while Calibrating,
  otherwise the scaled MAD (floored) or the typical value, and nil for metrics with no
  Spread. It stays pure, takes the same inputs, and the Readiness spec will extend and reuse it. Floors, typical values, the 7-Night
  threshold and the 1.4826 factor are named constants, each commented with its unit and source
  (issue #14 and `docs/research/nightly-metric-deviation.md`, "assumption: tune with real
  Nights").
- **`SerenixCore`: Zone** takes the whole Baseline (median and Spread) instead of only the
  median, for the Zone, the gauge position and the In range band. Its cut-offs are named
  constants as before.
- **Today view, tiles and popups** pass the Baseline through. Their output shapes don't change.
  Only the values in them do: Zone, status word, gauge position and band limits.
- The iOS shell doesn't change.
- Spec 002 keeps the screen, and points here for Baseline, Zones, status words, gauges and the
  band. Follows ADR 0002 (logic in `SerenixCore`). No ADR: every constant is easy to change.

## Seams under test
- **Today view (`SerenixCore`)**, the same seam as spec 002, fed hand-built Nights with known
  values. Through tile Zones, status words, gauge positions and the popup's In range band, it
  catches the Spread (MAD, floor, typical value, 7-Night switch, 14-Night window), every Zone
  boundary and direction, and the ln scale for HRV. It misses colours and drawing, which are
  already checked by hand under spec 002.

## Success criteria (must be checkable)
Automated (`swift test`, on Windows and in CI). Expected values are worked out by hand, with
the Baseline from earlier Nights all equal unless the criterion says otherwise.

Baseline (carried over from spec 002, unchanged):
- [x] Baseline for HRV over earlier values 50, 70, 60, 58 is 59 (even-count median); over 50,
      70, 60 it is 60.
- [x] Baseline uses at most the 14 most recent earlier Nights: with 20 earlier Nights, the 6
      oldest change nothing.
- [x] The Night shown is not in its own Baseline: changing its HRV changes its Zone but not its
      Baseline.
- [x] An earlier Night's Baseline comes from Nights before it only: adding a newer Night leaves
      it unchanged.
- [x] A metric with 2 earlier Nights is Calibrating ("Calibrating", no Zone); with 3, it has a
      Baseline.
- [x] Earlier Nights missing a metric are skipped for that metric's Baseline and popup chart, and
      don't count towards its 3.

Spread:
- [ ] With 3 to 6 earlier Nights, the typical Spread applies: respiratory rate 14.8 against six
      earlier Nights of 14.0 is Watch (z 1.6); against seven, it is Out of range (Spread
      floored to 0.3, z 2.67).
- [ ] Scaled MAD: respiratory rate over earlier Nights 14.0, 14.4, 13.6, 14.8, 13.2, 14.0, 14.0
      has Baseline 14.0 and Spread 0.59304, so the popup band is 13.11 to 14.89 (to 2 dp), 14.88
      and 13.12 are In range, 14.9 and 13.11 are Watch, 15.48 is Watch, and 15.49 and 12.5 are
      Out of range.
- [ ] HRV's floor: 50 against seven earlier Nights of 60 is Watch (Spread 0.10, z −1.82); against
      three, it is In range (typical 0.15, z −1.22). 54 against seven of 60 is In range.
- [ ] HRV's Spread is on ln(RMSSD): with earlier Nights 40, 50, 60, 60, 60, 72 and 90, the
      Baseline is 60 and the Spread is 1.4826 × ln 1.2 = 0.27031, so the popup band runs 40.00 to
      117.93 ms (to 2 dp); 40.1 is In range and 39.9 is Watch.
- [ ] The Spread uses the same up-to-14 Nights as the median: with 20 earlier Nights, giving the
      6 oldest wild values changes no Zone, gauge or band.

Zones (replacing spec 002's Zone criteria):
- [ ] HRV against Baseline 60 with the typical Spread: 48 is In range, 47.9 is Watch, 41.3 is
      Watch, 41.2 is Out of range; 87.2 is In range, 87.4 is Watch, and 200 is Watch (never Out
      of range).
- [ ] Resting HR against Baseline 52: 54.9 is In range, 55 is Watch, 56.9 is Watch, 57 is Out of
      range, and 40 is In range.
- [ ] Respiratory rate against Baseline 14.0 with the typical Spread: 14.7 and 13.3 are In range,
      14.8 and 15.25 are Watch, 15.3 and 12.7 are Out of range.
- [ ] Skin temperature against Baseline 34.0: 34.3 is In range, 33.6 is Watch, 34.7 is Out of
      range (unchanged).
- [ ] SpO2: 95 is In range, 94 and 92 are Watch, 91 is Out of range, including on a Night with
      no earlier Nights (unchanged).

Status words, gauge and band (replacing spec 002's criteria for these):
- [ ] Status words against Baselines HRV 60, Resting HR 52, respiratory rate 14.0 and skin
      temperature 34.0, with typical Spreads: HRV 70 "Normal", 90 "High", 41 "Low"; Resting HR
      45 "Normal", 55 "High"; respiratory rate 15.0 "High", 13.0 "Low"; skin temperature 34.5
      "High", 33.5 "Low"; SpO2 97 "95% or above", 93 "Below 95%", 90 "Below 92%"; a Calibrating
      metric "Calibrating".
- [ ] Gauge positions against the same Baselines: HRV 60 → 0.5, 30 → 0 and 120 → 1 (clamped);
      respiratory rate 15.0 → 0.9, 13.5 → 0.3, 16 → 1 (clamped); Resting HR 54.5 → 0.75, 47 →
      0; skin temperature 33.7 → 0.25; SpO2 97 → 0.75, 85 → 0 (clamped); a Calibrating or
      missing metric has no position.
- [ ] Popup In range band with typical Spreads: HRV against 60 runs 47.91 to 87.30 ms;
      respiratory rate against 14.0 runs 13.25 to 14.75; Resting HR against 52 has no lower
      limit and an upper limit of 55; skin temperature against 34.0 runs 33.7 to 34.3; SpO2 has
      none.

Manual, on the iPhone with the sideloaded CI build:
- [ ] After a sync with real Nights, each metric tile's Zone, status word and gauge match the
      Today view's output for that data.

## Non-goals (explicitly out of scope)
- Smoothing (e.g. a 7-Night average) or a lagged Baseline window.
- Readiness and how it uses the Spread: the Readiness spec.
- Showing the Spread in the app, or explaining it in a popup.
- Changing "vs your Baseline" or the Readiness advice.
- Comparing a Baseline with population norms ("is my Baseline healthy?"): a later feature.
- Tuning the cut-offs, floors and typical values against real Nights: after this ships.

## Open questions
- **Every number is an assumption** (cut-offs, floors, typical values, the 7-Night switch).
  Tune them once there are a few weeks of real Nights, changing the constants and their tests
  together.
- **Resting HR's Spread** (its floor and typical value) is left to the Readiness spec, which
  can test it through Readiness. Skin temperature's has no use yet.

## Notes
- Decision: issue #14. Evidence: `docs/research/nightly-metric-deviation.md` (NightSignal +3 bpm,
  WHOOP respiratory-rate z-score, the HRV SWC literature; high HRV as a warning is contested,
  hence capped at Watch).
- Changes spec 002's Baseline, Zones, status words, gauge and popup band. 002 now points here.
- Map: issue #12. Related: `specs/003-nightly-metrics.md` (on `feat/nightly-metrics`), and the
  Readiness spec to come.
