# How do readiness-style composite scores combine HRV, resting HR, sleep and prior-day load relative to a personal baseline?

**Date:** 2026-11-01 · **Unblocks:** the Readiness v1 formula ticket (issue #17): how Serenix
turns HRV, Resting HR, the previous Day's Load and Time Asleep into a 0–100 Readiness, with
Calibrating and missing-input rules

## Answer
- **The shared method is "today against your own Baseline, per input, then combine".** The
  research behind HRV-guided training compares a morning ln(RMSSD), ideally as a 7-day rolling
  average, against a personal reference band (mean ± a fraction of the SD or CV over the
  preceding weeks). Every vendor reviewed describes the same idea: Oura compares each
  contributor with a 2-week to 3-month personal average, Polar with your last 28 days, Garmin
  with a 3-week HRV baseline, and WHOOP with your own calibrated baseline. None of them
  publishes its weights or its exact normalisation.
- **HRV is the dominant input almost everywhere. Load is a secondary input, or it is left
  out.** WHOOP has said publicly that HRV carries most of Recovery's predictive value, with
  Resting HR and sleep adding less because they overlap with it. WHOOP doesn't list prior-day
  Strain as a Recovery input. Polar's ANS charge weights heart rate most and breathing rate
  least, and its sleep enters as a separate "sleep charge". Oura (previous day activity,
  activity balance) and Garmin (acute load, recovery time) are the only vendors that put
  training load directly into the score. For Serenix this points to HRV with the largest
  weight, Resting HR and Time Asleep next, and the previous Day's Load as a small penalty term.
- **Normalise each input as a deviation from Baseline in SD units, with the sign pointing the
  right way.** Use ln(RMSSD) for HRV (higher is better), Resting HR inverted (lower is better)
  and Time Asleep against the user's usual amount. For Load, the published comparison is acute
  against chronic, from the acute:chronic workload ratio (ACWR). Use it only as a soft
  "yesterday versus usual" signal. The ACWR literature has strong methodological critiques, and
  its 0.8–1.3 "sweet spot" and ≥1.5 "danger zone" come from team-sport injury studies, not
  from readiness scoring.
- **Warm-up: vendors either hide the score or fall back to population norms.** WHOOP falls back
  to population norms (adjusted for age, sex and fitness) until 4 consecutive Recoveries.
  Polar needs 3 nights before showing a status. Oura says it can take up to two weeks to learn
  your averages. Garmin's HRV status needs 3 weeks. Serenix's planned rule (Calibrating until 4
  Nights, Baseline over the last 14 Nights) is in line with these.
- **Missing inputs and bands are mostly undocumented.** WHOOP marks a day `UNSCORABLE` when
  there isn't enough data. Polar shows no status after fewer than 4 h of sleep or with gaps in
  wear. Oura and Garmin say nothing official. Published bands differ: WHOOP 67/34 (three
  colours); Oura 85/70/60; Garmin 95/75/50/25; Polar has six verbal categories. Serenix has to
  choose its own cut-offs (ADR 0005) and state them in the spec as literals.

## Findings

### Published research

**HRV-guided training (the "readiness" idea)**
- In an early randomised study of HRV-guided training, each athlete's morning HRV was compared
  with a reference value: their **10-day mean minus one SD**. Hard training was done only when
  HRV was not below that reference and had not fallen for 2 days in a row; otherwise the
  athlete trained easy or rested. ([Kiviniemi et al., Eur J Appl Physiol 2007;101(6):743–51,
  PMID 17849143](https://pubmed.ncbi.nlm.nih.gov/17849143/))
- Later trials used the same structure with an individually set "smallest worthwhile change"
  (SWC) band. Moderate or high-intensity sessions were done only when morning HRV sat inside the
  SWC band. ([Vesterinen et al., Med Sci Sports Exerc 2016;48(7):1347–54, PMID
  26909534](https://pubmed.ncbi.nlm.nih.gov/26909534/);
  [Javaloyes et al., Int J Sports Physiol Perform 2019;14(1):23–32, PMID
  29809080](https://pubmed.ncbi.nlm.nih.gov/29809080/)). The abstracts don't state the SWC
  formula; see Open.

**ln(RMSSD) and rolling averages**
- In a 77-day case comparison of two elite triathletes, the 7-day rolling average of ln(RMSSD)
  fell steadily in the athlete who became non-functionally over-reached. The weekly coefficient
  of variation (CV) of ln(RMSSD) also fell steadily. Both measures stayed stable in the control
  athlete. ([Plews et al., Eur J Appl Physiol 2012;112(11):3729–41, PMID
  22367011](https://pubmed.ncbi.nlm.nih.gov/22367011/))
- In 10 runners, **weekly averaged** Resting HR and ln(RMSSD) tracked changes in fitness far
  better than single-day values (r = .72 against r = −.06). ([Plews et al., IJSPP
  2013;8(6):688–91, doi 10.1123/ijspp.8.6.688](https://doi.org/10.1123/ijspp.8.6.688))
- At least **3 valid measurements per week** are needed for a weekly ln(RMSSD) average to be
  valid. ([Plews et al., IJSPP 2014;9(5):784–91, doi
  10.1123/ijspp.2013-0455](https://doi.org/10.1123/ijspp.2013-0455))
- Review ([Plews et al., Sports Med 2013;43(9):773–81, PMID
  23852425](https://pubmed.ncbi.nlm.nih.gov/23852425/)): HRV should be read through
  "appropriate averaging techniques" and long-term individual monitoring (an athlete's HRV
  "fingerprint"). Rises in HRV went with improved fitness and falls with reduced freshness.
- Review ([Buchheit, Front Physiol 2014;5:73, PMC3936188](https://pmc.ncbi.nlm.nih.gov/articles/PMC3936188/)):
  - **Noise:** the day-to-day CV of ln(RMSSD) is about 10–20%. Averaging n days reduces noise by
    1/√n, and averages of 3–4+ days correlate better with performance.
  - **SWC:** studies have used 0.5× or 1× the individual's CV. The author prefers the
    individual's CV to the between-athlete SD as the reference. Table 1 gives an approximate SWC
    of about +3% for vagal HRV indices and about −2% for resting HR.
  - **HRV saturation:** when R-R intervals exceed about 1000 ms (a low HR), RMSSD can fall even
    though vagal activity is high. A fall in HRV together with a fall in HR is therefore not
    automatically fatigue. The author suggests checking RMSSD against resting HR, or using the
    ln(RMSSD)/R-R ratio.
  - **Context:** HRV and HR should be read alongside training phase and other markers.

**Acute:chronic workload ratio (prior load against a personal baseline)**
- **Windows:** acute load is usually 1 week; chronic load is "the rolling average of the most
  recent 3–6 weeks of training".
- **Thresholds:** a ratio of about **0.8–1.3** is the low-risk "sweet spot", and **≥1.5** is the
  "danger zone", with 2–4× injury risk over the following 7 days in one cricket cohort.
- Source: [Gabbett, Br J Sports Med 2016;50(5):273–80,
  PMC4789704](https://pmc.ncbi.nlm.nih.gov/articles/PMC4789704/).
- Critique: the ACWR is a statistically problematic ratio. It adds noise and artefacts, it is
  mathematically coupled when the acute week also sits inside the chronic window, and it
  shouldn't be treated as a causal lever. ([Impellizzeri et al., IJSPP 2020;15(6):907–13, doi
  10.1123/ijspp.2019-0864](https://doi.org/10.1123/ijspp.2019-0864); record seen via the [UTS
  repository](https://opus.lib.uts.edu.au/citation/handle/10453/141898). Full text not read.)

### WHOOP — Recovery
- **Scale and bands:** 0–100%. Green is **67–100**, yellow **34–66** and red **0–33**.
- **Inputs:** HRV, Resting HR, sleep (Sleep Performance) and respiratory rate. SpO2 and skin
  temperature are shown in Health Monitor but are not part of Recovery.
- Source for both points: WHOOP's "How does WHOOP Recovery work 101" page
  ([whoop.com/thelocker/how-does-whoop-recovery-work-101](https://www.whoop.com/thelocker/how-does-whoop-recovery-work-101/)).
  whoop.com returned HTTP 403 to direct fetches, so these points come from search excerpts of
  the official page.
- **Respiratory rate** was added in July 2020. It lowers the score when it is raised against
  baseline, especially when Recovery is already low.
  ([whoop.com/thelocker/adding-respiratory-rate-to-recovery](https://www.whoop.com/us/en/thelocker/adding-respiratory-rate-to-recovery/),
  search excerpt only.)
- **Weighting:** WHOOP Podcast 40 says HRV carries most of the predictive value, while Resting
  HR and Sleep Performance add less because they overlap with HRV. This predates the
  respiratory-rate update.
  ([whoop.com/thelocker/podcast-40-whoop-recovery-maximize-readiness](https://www.whoop.com/thelocker/podcast-40-whoop-recovery-maximize-readiness/),
  search excerpt only.) No numeric weights are published.
- **Calibration:** the first sleep is compared against typical HRV and Resting HR values
  adjusted for age, gender and fitness. Recovery counts as calibrated after **4 consecutive
  Recoveries**. ([WHOOP Support, "What is the Recovery calibration
  period?"](https://support.whoop.com/hc/en-us/articles/360019622573-What-is-the-Recovery-calibration-period-),
  search excerpt only; the page returned 401.) The podcast page says scores are greyed out
  during the first four days.
- **Missing data:** the official developer API has `score_state` ∈ {`SCORED`, `PENDING_SCORE`,
  `UNSCORABLE`}. `UNSCORABLE` is used "commonly because there is not enough user metric data".
  The score object includes a `user_calibrating` flag and `recovery_score` ("a percentage
  between 0 - 100%"). ([WHOOP Developer docs,
  Recovery](https://developer.whoop.com/docs/developing/user-data/recovery))
- Prior-day Strain is not among the published Recovery inputs.

### Oura — Readiness (support pages last updated October 2026)
- **Bands:** 0–100: **85–100 Optimal, 70–84 Good, 60–69 Fair, 0–59 Pay attention**. The same
  bands apply to each contributor's own 0–100 sub-score.
  ([Oura, Readiness Score](https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score),
  updated 2026-10-01)
- **Contributors and their baselines** ([Oura, Readiness
  Contributors](https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors),
  updated 2026-10-07):
  - **Resting heart rate:** last night's lowest HR against the long-term average (about two
    months).
  - **HRV balance:** a 14-day weighted average, with recent days weighted more, against a
    3-month average.
  - **Body temperature:** last night against the long-term nightly average.
  - **Recovery index:** time asleep after HR reaches its nightly low; at least 6 h is best.
  - **Sleep:** total sleep including naps against the personal baseline.
  - **Sleep balance:** the past 2 weeks against the personal baseline and adult
    recommendations.
  - **Sleep regularity:** consistency of bedtime and wake time over the past 2 weeks.
  - **Previous day activity:** against long-term averages and recommended daily activity.
  - **Activity balance:** 14-day weighted against about 2 months.
  - The Readiness Score page describes the "balance" contributors as 14-day weighted averages
    (the past 2–5 days weighted slightly more) against "your long-term average over the past
    two months".
- **Calibration:** "It can take up to two weeks for the Oura App to learn your average values."
- **Not published:** contributor weights, how each contributor maps to 0–100, and how missing
  data is handled.

### Garmin — Training Readiness and Body Battery
- **Training Readiness inputs:** last night's sleep score, recovery time, HRV status, acute
  load, sleep history (last 3 nights) and stress history (last 3 days). The score updates
  through the day.
- **Training Readiness bands:** **95–100 Prime (purple), 75–94 High (blue), 50–74 Moderate
  (green), 25–49 Low (orange), 1–24 Poor (red)**.
- Source: [Forerunner 965 manual, Training
  Readiness](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html);
  the Instinct 2 manual gives the same list.
- **Main determinants:** Garmin's launch post (2022-07-01) names sleep quality and the recovery
  demands of recent activity. It gives no weights. ([Garmin blog
  (MY)](https://www.garmin.com/en-MY/blog/fitness/new-features-on-garmin-smartwatches-help-to-maximize-your-training/))
- **HRV status:**
  - Measured overnight and needs **three weeks of consistent sleep data**.
  - The **7-day average** HRV is compared with a personal "baseline range". Balanced means
    inside the range, Unbalanced above or below it, Low well below it, and Poor well below
    the normal range for your age.
  - "No status" is shown when there is too little data for a 7-day average.
  - Source: [Instinct 3 manual, HRV
    Status](https://www8.garmin.com/manuals/webhelp/GUID-2C274FD2-F0C3-445C-B0AC-700FECCE12E9/EN-US/GUID-9282196F-D969-404D-B678-F48A13D8D0CB.html).
  - The baseline's width and the method behind it are not published.
- **Body Battery:**
  - Built from HRV, stress, sleep quality and activity.
  - Some manuals use a **5–100** range: 5–25 very low, 26–50 low, 51–75 medium, 76–100 high.
    Others use 0–100 with differently named bands.
  - It is a running "energy" level that rises with rest and falls with stress and activity,
    not a once-a-day readiness score.
  - Source: [Garmin manuals, Body
    Battery](https://www8.garmin.com/manuals/webhelp/GUID-3A4F9C4A-8735-46C0-8DA9-65F11400B150/EN-US/GUID-87E1392B-2C55-40B7-A1FF-3AB9252DA0A0.html).
- **Firstbeat patents:** related patents describe training status from an HRV variable plus
  short-term load and a short/long load ratio
  ([US11317862B2](https://patents.google.com/patent/US11317862)). This is one possible
  implementation, not Garmin's documented algorithm.

### Polar — Nightly Recharge
- **ANS charge:**
  - Inputs: heart rate, HRV (RMSSD) and breathing rate over about the **first 4 hours of
    sleep**.
  - Each is compared with your usual level over the **past 28 days**.
  - Heart rate has the most influence and breathing rate the least.
  - Scale −10 to +10, where around 0 is your usual level.
- **Sleep charge:** the night's sleep score (1–100) against your usual over 28 days, in five
  categories from much below usual to much above usual.
- **Nightly Recharge status:** combines the two charges into one of six categories: very poor,
  poor, compromised, OK, good, very good. The combination rule is not published.
- **Warm-up:** the first status needs **3 nights** with successful measurements.
- **Missing data:** no status is shown if there are 3 nights without wear, under 4 h of sleep,
  continuous HR is off, the watch is worn badly, or sleep is too restless.
- Prior-day training load is not an input.
- Source: [Polar Support, Nightly Recharge recovery
  measurement](https://support.polar.com/ie-en/nightly-recharge-recovery-measurement). The
  [white paper (2019)](https://polar.com/img/static/whitepapers/pdf/polar-nightly-recharge-white-paper.pdf)
  could not be text-extracted here.

### Fit with Serenix v1 (inference from the above, not a decision)
| Serenix input | Closest published normalisation | Direction |
|---|---|---|
| HRV | ln(RMSSD) against Baseline mean and SD (Kiviniemi: mean − 1 SD; SWC 0.5× CV) | higher = better |
| Resting HR | against long-term average (Oura, Polar); SWC about −2% (Buchheit) | lower = better |
| Time Asleep | against personal baseline (Oura Sleep, Polar sleep charge) | more = better, capped |
| previous Day's Load | acute against chronic (ACWR; Oura previous day activity; Garmin acute load) | above usual = small penalty |

## Open / uncertain
- **No vendor publishes weights, per-input transforms or the curve that maps the combination to
  0–100.** Serenix's weights and mapping (for example a z-score sum through a logistic or
  normal CDF) will be its own design choice. Expected values for tests have to come from the
  spec, not from any vendor.
- **WHOOP primary pages couldn't be read directly** (HTTP 403/401). The bands, input list,
  HRV-dominance statement and the 4-Recovery calibration come from search excerpts of
  whoop.com and support.whoop.com, so their exact current wording is unverified. The HRV
  dominance claim predates the 2020 respiratory-rate update.
- **Exact SWC formulas** in Vesterinen 2016 and Javaloyes 2019 (commonly reported as a 7-day
  rolling average of ln(RMSSD) against baseline mean ± 0.5 SD) were not confirmed from full
  text. Only the abstracts were read.
- **Why HRV is log-transformed** is the convention across Plews, Buchheit and Javaloyes. The
  usual reason (RMSSD is right-skewed) wasn't stated in the sections read.
- **Missing-input handling** is undocumented for Oura and Garmin. Whether a vendor drops a
  missing input and re-weights the rest, or refuses to score, is unknown. Serenix has to
  decide; one option is to require HRV and re-weight the others.
- **Baseline windows differ widely:** 10 days (Kiviniemi), 14 days against 2–3 months (Oura),
  3 weeks (Garmin), 28 days (Polar). There is no evidence that any one window is best for
  readiness. Serenix's 14-Night Baseline is within the range in use.
- **Validation of composite scores is thin.** No peer-reviewed validation of any vendor's
  composite against an outcome was found. The HRV-guided-training trials validate a
  single-input HRV rule, not a weighted composite.
- **The ACWR's predictive validity is disputed** (Impellizzeri 2020). Its 0.8–1.3 and ≥1.5
  thresholds come from team-sport injury studies and should not be carried over as Readiness
  thresholds.
- **HRV saturation:** in very fit users, low HR together with lower RMSSD can be misread as
  poor Readiness. A simple formula would not handle this.
- **Bands are vendor-specific.** WHOOP 67/34, Oura 85/70/60, Garmin 95/75/50/25. There is no
  shared standard, so Serenix's cut-offs are a product decision under ADR 0005.
