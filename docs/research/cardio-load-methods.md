# Which established methods measure cardiovascular load over a Day from heart rate alone, what inputs do they need, how do they handle all-day 1 Hz wrist HR, and how can the result map onto a 0–100 scale?

**Date:** 2026-11-01 · **Unblocks:** the Load method: which method, which 0–100 scaling, and which
Profile fields Load needs (issue #16)

## Answer
- **Banister TRIMP, summed per second, is the best-documented fit.** It is published, needs only
  HR, resting HR, max HR and sex, and Polar's current consumer Cardio Load uses exactly this
  (Banister, computed each second, then summed). Edwards (5 zones of %HRmax) is a simpler
  alternative. Lucia needs lab ventilatory thresholds, and Firstbeat EPOC needs proprietary
  models, so neither is usable here.
- **Inputs beyond heart rate:** Banister needs max HR and sex (its weighting differs by sex);
  an estimated max HR needs age. Resting HR is already measured nightly (Resting HR /
  Baseline), so it need not come from the Profile. Polar takes max HR from user settings, so a
  user-entered max HR is one option alongside an age estimate. Of the age formulas, 220 − age
  has no original study behind it, while Tanaka (208 − 0.7·age) and Gellish (207 − 0.7·age) come
  from a large meta-analysis and a longitudinal study. Every age-only formula carries roughly
  7–12 bpm of individual error.
- **Unfloored all-day Banister over-counts everyday HR.** Banister's HRR
  fraction goes negative below resting HR and is small but non-zero just above it. Summed over
  16 waking hours, that low-level HR can match a hard workout (worked example below). Published
  methods handle this with a cutoff: Edwards ignores HR below 50% HRmax, EPOC decays during
  rest, and Garmin needs 10 continuous minutes at moderate intensity or above. No source sets
  a floor for all-day Banister, so any floor would be Serenix's own constant; the published
  candidates are listed under Open.
- **0–100 mapping:** no vendor publishes its curve. The one concrete published design is
  WHOOP's description: load accumulates linearly, the displayed number is log-scaled, and the
  ceiling is set by "max HR for 24 hours". One option is a 0–100 built the same way (for
  example `100 · ln(1 + L) / ln(1 + L_max)`, with `L_max` = TRIMP for 24 h at HRmax) without
  using WHOOP's 0–21 range or name. The other published approach is a relative scale (Polar,
  Firstbeat): today's load is shown against the user's own history.

## Findings

### Banister TRIMP (exponential, HR reserve)
- TRIMP = Σ Δt · ΔHR_ratio · k·e^(b·ΔHR_ratio), with ΔHR_ratio = (HR − HRrest)/(HRmax − HRrest).
  k = 0.64, b = 1.92 for men and k = 0.86, b = 1.67 for women. The weighting comes from the
  HR–blood-lactate curve in incremental exercise. Formula and constants as reproduced (with
  HRR defined as above) in [Milanez & Pedro, Rev Bras Med Esporte 18(4), 2012](https://new.scielo.br/j/rbme/a/kd8RLyCwnm3KNM5SbnTdg4B/?lang=en),
  which cites Banister, "Modeling elite athletic performance", in *Physiological Testing of the
  High-Performance Athlete*, 2nd ed., Human Kinetics 1991, pp. 403–425. TRIMP first appears in
  the impulse-response model of [Morton, Fitz-Clarke & Banister, J Appl Physiol 69(3):1171–7, 1990](https://pubmed.ncbi.nlm.nih.gov/2246166/).
  (I could not read the original chapter. The scielo web text loses the exponent notation. The
  constants match every secondary source seen.)
- Polar's consumer Cardio Load is Banister TRIMP. Polar says "TRIMPs are computed each second,
  and the total is then calculated". The inputs are HR(t), resting HR and max HR "from user
  settings", with one equation for males and one for females. Polar names two limitations:
  heart rate under-reads short anaerobic bouts and strength work, and the weighting
  distinguishes only sex. Source: [Polar Training Load Pro white paper, 12 Nov 2019, rev. Mar 2025](https://www.polar.com/img/static/whitepapers/pdf/polar-training-load-pro-white-paper.pdf),
  §3.1. Polar gives about 70–130 as typical for a 60-minute session ([Polar support: Training Load Pro](https://support.polar.com/en/training-load-pro)).
- Polar computes Cardio Load per **training session**, not all day. Its "Strain" (acute load)
  is the 7-day rolling mean of daily Cardio Load and "Tolerance" (chronic load) the 28-day
  mean. Session "load levels" (1–5) compare a session with the average session of the last
  90 days, using cut-offs at 0.5×, 0.75×, 1.25× and 2× that average. Polar says those cut-offs
  come from its own customer data and "are not grounded in firm scientific evidence"
  ([white paper](https://www.polar.com/img/static/whitepapers/pdf/polar-training-load-pro-white-paper.pdf), §3.5–3.8).
- HR reserve as an intensity measure goes back to [Karvonen, Kentala & Mustala, Ann Med Exp Biol Fenn 35:307–15, 1957](https://pubmed.ncbi.nlm.nih.gov/13470504/).

### Edwards zone TRIMP
- Five zones by %HRmax: 50–60, 60–70, 70–80, 80–90 and 90–100%. Minutes in each zone are
  weighted 1–5 and summed. HR below 50% HRmax is discarded. Needs only HRmax. Source: Edwards,
  *The Heart Rate Monitor Book*, Fleet Feet Press 1993, as applied in [Milanez & Pedro 2012](https://new.scielo.br/j/rbme/a/kd8RLyCwnm3KNM5SbnTdg4B/?lang=en).
  The 50% floor is a built-in all-day rule. The step weights make it insensitive to changes
  inside a zone.

### Lucia TRIMP
- Three zones: below the ventilatory threshold (VT), from VT to the respiratory compensation
  point (RCP), and above RCP. Time in each zone is weighted 1, 2 and 3. The zone boundaries come
  from each rider's ramp cycle-ergometer test with gas analysis ([Lucia et al., Med Sci Sports Exerc 35:872–8, 2003](https://researchportal.bath.ac.uk/en/publications/tour-de-france-versus-vuelta-a-espana-which-is-harder/)).
  **Not usable**: Serenix has no lab test, so it can't find VT or RCP.

### Time in HR zones (intensity minutes)
- Garmin's all-day "intensity minutes" compare HR with the user's average resting HR, or
  optionally with user-set zones. They count only after 10 consecutive minutes at moderate
  intensity or above, and vigorous minutes count double ([Garmin vívoactive HR manual, "Earning Intensity Minutes"](https://www8.garmin.com/manuals/webhelp/vivoactivehr/EN-US/GUID-02D2D4E7-4CEE-44C7-831C-2E5F58613B60.html)).
  This is the clearest published rule for 24-hour wrist HR: a minimum intensity plus a minimum
  duration, so everyday HR doesn't add up into load.

### EPOC / Firstbeat training load (Garmin)
- Firstbeat models EPOC from momentary intensity (%VO2max) estimated from heartbeat data:
  "When the intensity of exercise is high, EPOC accumulates, whereas during periods of rest or
  low-intensity activity, EPOC decreases". Aerobic Training Effect (0–5) comes from the
  session's peak EPOC, scaled to the user's fitness ([Firstbeat white paper "Aerobic and Anaerobic Training Effect Assessment", published 5/2017](https://www.firstbeat.com/wp-content/uploads/2015/10/FFW609US05-171.pdf), pp. 2–3;
  bands 0–0.9 none … 5.0 overreaching on [Firstbeat: EPOC and Training Effect](https://www.firstbeat.com/en/science-and-physiology/epoc-and-training-effect/)).
- Garmin's "training load" is the 7-day sum of EPOC from recorded activities ([Garmin epix manual, Training Status](https://www8.garmin.com/manuals-apac/webhelp/epix/EN-SG/GUID-6B0B7A2F-9E77-4055-BE12-BD5125B3BE45-9109.html)).
  Newer devices use an "Acute Load" that weights recent days more ([Garmin Descent Mk3 manual, Acute Load](https://www8.garmin.com/manuals-apac/webhelp/descentmk3series/EN-SG/GUID-4717F6BA-B325-4EF0-B70E-215E9C0C3490-8538.html)).
- The EPOC model itself (a neural network using HR, HRV-derived respiration rate, and HRmax,
  resting HR and VO2max from the profile) is proprietary and patented. **Not reproducible.**
  Its decay-at-rest behaviour is still a useful design idea.

### WHOOP Strain
- WHOOP describes Strain as cardiovascular load (newer material adds muscular load) on 0–21.
  Cardiovascular strain comes from time at elevated HR, with zones set from the user's max HR.
  The displayed scale is logarithmic: load accumulates in linear space and is shown in scaled
  space, so two 6-strain activities do not make 12. The scale was inspired by the Borg RPE
  scale, and 21 is the theoretical ceiling for "max HR for 24 hours". Sources: WHOOP Locker
  ["How does WHOOP Strain work"](https://www.whoop.com/thelocker/how-does-whoop-strain-work-101/),
  ["Ask us anything: Strain"](https://www.whoop.com/thelocker/ask-us-anything-strain/) and
  [Podcast 26 "Understanding Strain" (2019)](https://www.whoop.com/thelocker/podcast-26-understanding-strain/).
  **Caveat:** whoop.com returned HTTP 403 to direct fetches, so these statements come from
  search-engine excerpts of those WHOOP pages and were not read in full. The log base, the
  zone weights and whether WHOOP uses %HRR are not public. WHOOP's developer API exposes only
  the number ([cycle docs](https://developer.whoop.com/docs/developing/user-data/cycle/)).
- WHOOP's Day Strain accumulates across the whole day, and its pages say commuting and work
  stress raise it. ADR 0005 rules out WHOOP's 0–21 range and the name Strain for Serenix.

### Oura
- Oura has no HR-based load score. Its Activity Score contributor "Training Volume" sums
  medium/high-intensity MET-minutes over 7 days, from the accelerometer. It reaches 100% at
  2,000 MET-min/week, and the Activity Score may start to decline below 750 MET-min/week
  ([Oura, Activity Contributors, updated 2026-10-01](https://support.ouraring.com/hc/en-us/articles/360055901214)).
  This is a published saturating 0–100 mapping, but over a week and on MET input.

### Max-HR estimation
| Formula | Source | Error |
|---|---|---|
| 220 − age | No original study. [Robergs & Landwehr, JEPonline 5(2):1–10, 2002](https://www.asep.org/asep/asep/Robergs2.pdf) trace it to observation of about 11 references | Error 7–11 bpm (Robergs & Landwehr abstract). Under-predicts in older adults (secondary sources) |
| 208 − 0.7·age | [Tanaka, Monahan & Seals, J Am Coll Cardiol 37(1):153–6, 2001](https://pubmed.ncbi.nlm.nih.gov/11153730/). Meta-analysis of 18,712 subjects plus a lab check in 514 (209 − 0.7·age) | Same line for men and women and for all activity levels. SEE not given in the abstract (about 10 bpm in secondary reviews) |
| 207 − 0.7·age | [Gellish et al., Med Sci Sports Exerc 39(5):822–9, 2007](https://pubmed.ncbi.nlm.nih.gov/17468581/). Longitudinal, 132 people, 908 tests | Prediction error not given in the abstract |
| 211 − 0.64·age | [Nes et al. (HUNT), Scand J Med Sci Sports 23(6):697–704, 2013](https://pubmed.ncbi.nlm.nih.gov/22376273/). 3,320 healthy adults | SEE 10.8 bpm. Earlier equations under-predicted above age 30 |

All age-only formulas have roughly 7–12 bpm individual error (Robergs & Landwehr: most age-based
equations >10 bpm; Nes: SEE 10.8 bpm). That error goes straight into
%HRR and the exponential weight. The formulas differ from each other by less than that error, so
a measured max HR (user-entered, or the highest HR observed) would reduce error more than the
choice of formula (derived from the figures above, not stated by a source).

### Wrist HR quality
- Optical wrist sensors are "reasonably accurate at resting and prolonged elevated heart rate".
  Absolute error during activity averaged about 30% higher than at rest, and devices differed in
  how they tracked changes in activity ([Bent et al., npj Digit Med 3:18, 2020, PMC7010823](https://pmc.ncbi.nlm.nih.gov/articles/PMC7010823/)).
  Short spikes during movement are the least reliable input, which argues for a
  minimum-duration rule.

### Worked example: why all-day Banister needs a floor (derived, not from a source)
For a man at 20% HRR (ordinary daytime activity), Banister gives
0.2 · 0.64 · e^(1.92·0.2) ≈ 0.188 per minute. Over 16 waking hours that is about 180. One hour at
80% HRR gives 0.8 · 0.64 · e^(1.536) ≈ 2.38 per minute, about 143. So without a floor, an
ordinary day scores higher than a hard hour of exercise. Below resting HR (during sleep) the
ratio is negative, so it would need clamping to zero or excluding.

## Open / uncertain
- **Which floor to use.** No source sets a floor for continuous 24-hour Banister TRIMP. The
  candidates are Edwards' 50% HRmax, Garmin's 10-minute rule, EPOC-style decay, or the lower
  bound of a standard "moderate" intensity band. Comparing them would need testing against the
  fixture Days.
- **Banister's original text was not read.** The constants (0.64/1.92 and 0.86/1.67) come from
  secondary reproductions that agree with each other. Banister 1991 is a book chapter that isn't
  online.
- **WHOOP's exact mapping.** The log base, the weighting, and whether it uses %HRR or %HRmax
  are not public. whoop.com pages could not be fetched directly (HTTP 403), so the claims rest on
  search excerpts of WHOOP's own pages.
- **The 0–100 mapping.** No peer-reviewed absolute log or saturating mapping of daily TRIMP onto
  0–100 was found. Serenix's curve, and its `L_max` or half-saturation constant, will be its own
  design choice, not an established one.
- **Which resting HR to use.** Polar uses a user setting. The choice between last night's
  Resting HR and the Baseline Resting HR (more stable) is not settled by any source. A Day with
  no Night (Calibrating, or the Strap not worn) needs a fallback.
- **Sex as an input.** Banister's weighting needs binary sex. Edwards and Tanaka do not. The
  Profile currently holds only a name, so adding sex and age (or date of birth) is a Profile
  decision with privacy implications to settle in the spec.
- **ACSM %HRR intensity bands not verified.** The ACSM position stand ([Garber et al., Med Sci
  Sports Exerc 43(7):1334–59, 2011, PMID 21694556](https://pubmed.ncbi.nlm.nih.gov/21694556/))
  is often quoted as defining moderate and vigorous by %HRR, but its abstract gives no
  percentages and the full text was paywalled (HTTP 402), so no %HRR bounds are cited here.
