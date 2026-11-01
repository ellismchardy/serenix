# How do trackers and the literature decide a Nightly Metric is unusual *for this person*?

**Date:** 2026-11-01 · **Unblocks:** the Zone rule: per-metric rule type, direction and warm-up length
(issue #14)

## Answer
- **HRV: spread-scaled, both directions, on a smoothed value.** The HRV-guided training literature compares a
  7-day rolling average of (ln)RMSSD with a personal band of *mean ± 0.5 × SD* (the "smallest worthwhile
  change"). It flags values **above** the band as well as below. Garmin (7-day average against a personal
  range; above the range = "Unbalanced") and Oura (both directions lower the score) do the same.
  Single-night HRV is too noisy to act on alone.
- **Resting HR: in practice, fixed bpm gaps from a personal median or mean.** The illness-detection work
  (Stanford NightSignal: +3 bpm yellow, +4 bpm red, over consecutive nights) and Oura (lower score at
  +3–5 bpm, or −10–15 bpm) use absolute bpm offsets, not SD multiples. A spread-scaled rule (the 28-day
  CuSum on standardized residuals) was less sensitive than the fixed-bpm rule in the head-to-head we
  found. The warning direction is mainly **up**. Oura is the only one that also penalises a large drop.
- **Respiratory rate and skin temperature: personal baseline; for respiratory rate, scaled by the
  person's own spread.** WHOOP's respiratory-rate study used a robust z-score: (recent mean − median of a
  lagged 14-night window) / that window's SD. Within-person night-to-night SD is only ~0.5 breaths/min.
  Temperature is shown as a deviation from a personal baseline (Oura, WHOOP). No vendor publishes its
  threshold. The warning direction is **up**. Oura notes a low temperature can be the menstrual cycle,
  not illness.
- **Warm-up length:** vendors show something after **3 nights** (Polar), **4 days** (WHOOP Recovery) or
  **~2 weeks** (Oura, WHOOP Health Monitor). For a *range* they want **~3 weeks** (Garmin) to **~30 days**
  (Oura temperature, Polar 28-day window), and they keep **2–3 months** as the long-term reference. The
  research protocols use **10 days** (Kiviniemi), **14–21 nights** (WHOOP respiratory rate) or **4 weeks**
  (Vesterinen) before trusting a mean and SD. NightSignal's median settled in about 7 nights for >80% of
  people.
- **High HRV / low Resting HR as a warning:** contested. Functional overreaching can *raise*
  weekly-averaged HRV and lower Resting HR (Le Meur 2013; meta-analysis SMD 0.81 for weekly HRV). So
  Vesterinen, Garmin and Oura treat "above range" as abnormal. Buchheit says that HRV saturation on its
  own is not a sign of fatigue. The evidence is stronger for a low HRV than a high one, and stronger for
  a raised Resting HR than a lowered one (only Oura flags a large drop). Options the evidence supports
  include a two-sided HRV band, with or without a softer label for the high side, and a Resting HR rule
  that warns upward only or in both directions.

## Findings

### Research literature: HRV (RMSSD / lnRMSSD)
- Kiviniemi et al. 2007 guided training by each morning's HRV against a reference of the **10-day
  mean − SD**. They also flagged a falling trend over 2 days. Single-day values, high-frequency power.
  ([Eur J Appl Physiol 101:743–51, PMID 17849143](https://pubmed.ncbi.nlm.nih.gov/17849143/))
- Vesterinen et al. 2016 used a **7-day rolling average of RMSSD** against an SWC band of **mean ± 0.5 × SD**,
  taken from **4 weeks** of daily values. They refreshed the band every 4 weeks. Values **below or above**
  the band were treated as abnormal: below = sympathetic stress, above = "parasympathetic hyperactivity",
  a possible sign of overreaching. Their reasoning: "it is unknown whether HRV should be expected to
  increase or decrease" in overreaching, so the rule needs upper and lower limits. They also warn that
  the baseline should not be recorded during illness or heavy stress.
  Read in the authors' accepted manuscript, Methods and Discussion; the HRV variable is **raw RMSSD**,
  not ln.
  ([MSSE 48(7):1347–54, PMID 26909534](https://pubmed.ncbi.nlm.nih.gov/26909534/);
  [accepted manuscript, Univ. of Jyväskylä repository](https://jyx.jyu.fi/bitstream/handle/123456789/50625/vesterinenetalindividualendurancemsse.pdf?sequence=1))
- Plews et al. 2014: averaging lnRMSSD over a week stops improving after **3–4 days**. They recommend at
  least 3 valid data points per week.
  ([IJSPP 9(5):783–90, PMID 24334285](https://pubmed.ncbi.nlm.nih.gov/24334285/))
- Plews et al. 2012, a case study of 2 athletes: in the athlete who became non-functionally overreached,
  the 7-day rolling lnRMSSD fell, and so did the **coefficient of variation** of lnRMSSD (−0.65 %/week).
  In the control athlete both stayed stable. The authors propose that the day-to-day CV plus the
  individual SWC are useful markers.
  ([Eur J Appl Physiol 2012, PMID 22367011](https://pubmed.ncbi.nlm.nih.gov/22367011/);
  [Plews PhD thesis, AUT 2014](https://openrepository.aut.ac.nz/items/d7b41d29-e92e-4acf-90ea-ed68d84d6c73/full))
- Plews et al. 2013 review: "HRV saturation" in elite athletes means HRV falls *despite* a lower
  Resting HR. They also argue for averaging techniques and for long-term monitoring of each person.
  ([Sports Med 43(9):773–81, PMID 23852425](https://pubmed.ncbi.nlm.nih.gov/23852425/))
- Buchheit 2014 review:
  - Authors set the SWC at 0.5 × or 1 × the individual CV. He prefers the individual's own CV.
  - Typical error is about **10% for resting HR** and **~12% for lnRMSSD**. Day-to-day CV of lnRMSSD is
    roughly 10–20%.
  - The ideal case is a typical error below half the SWC.
  - Saturation comes from *more*, not less, vagal activity and happens "independently of any sign of
    fatigue". It can be told apart using the lnRMSSD : RR-interval ratio. It points to overtraining only
    if it persists and does not reverse with a taper.
  - Measure at least 3–4 days per week.

  ([Front Physiol 5:73](https://www.frontiersin.org/articles/10.3389/fphys.2014.00073/full))
- Le Meur et al. 2013 (21 triathletes, RCT): in the athletes who became functionally overreached,
  **weekly-averaged** HRV showed a progressive *increase* in parasympathetic modulation, and Resting HR
  fell. Once-a-week single recordings missed this.
  ([MSSE 45(11):2061–71, PMID 24136138](https://pubmed.ncbi.nlm.nih.gov/24136138/))
- Manresa-Rocamora, Flatt et al. 2021 meta-analysis on functional overreaching:
  - Pooled resting vagal HRV showed no effect (SMD −0.01).
  - **Weekly-averaged** HRV rose meaningfully (SMD 0.81). Isolated values did not (SMD −0.45, not
    significant).

  ([Scand J Med Sci Sports 31(6):1164–82, PMID 33533045](https://pubmed.ncbi.nlm.nih.gov/33533045/))

### Research literature: Resting HR, respiratory rate, temperature (illness detection)
- Alavi et al. 2022, the NightSignal method:
  - Baseline = **streaming median** of overnight Resting HR. It stabilised after **7 nights** for >80% of
    participants.
  - Thresholds are **fixed bpm**: +3 bpm = yellow, ≥ +4 bpm on 2 consecutive nights = red. The 3 bpm
    figure was chosen as the median fluctuation of people's medians.
  - The comparison method, CuSum, uses SD-standardized residuals over a **28-day** sliding baseline, with
    the 95th-percentile alarm threshold. CuSum caught fewer cases (54% vs 78% in the preprint).

  ([Nat Med 28:175–84, PMC8799466](https://pmc.ncbi.nlm.nih.gov/articles/PMC8799466/))
- Mishra et al. 2020: the RHR-Diff method standardizes resting HR, hour by hour, against the average
  daily curve from a **28-day sliding window**, then flags elevated intervals on the standardized
  residuals at a 0.05 significance level, dropping intervals shorter than 24 h. So it is spread-scaled,
  not a fixed bpm offset.
  ([Nat Biomed Eng 4(12):1208–20, PMID 33208926](https://pubmed.ncbi.nlm.nih.gov/33208926/);
  methods read in the [author manuscript, PMC9020268](https://pmc.ncbi.nlm.nih.gov/articles/PMC9020268/))
- Miller et al. 2020 (WHOOP authors):
  - Respiratory rate during sleep was compared with the **median of a 14-night window lagged 7 nights**.
    The lag stops an illness from raising its own baseline.
  - It was scaled by that window's SD (a "modified z-score"), and needed 21 consecutive prior nights.
  - Within-person night-to-night SD averaged **0.51 ± 0.20 breaths/min** (CV 3.3%) across 25,000 members.

  ([PLOS ONE 15(12):e0243693, PMC7728254](https://pmc.ncbi.nlm.nih.gov/articles/PMC7728254/))
- Smarr et al. 2020 / Mason et al. 2022 (Oura, TemPredict): illness-linked rises in temperature measured
  at the finger can be seen as deviations from each person's own baseline. The abstracts give no
  threshold. ([Sci Rep 10:21640, PMID 33318528](https://pubmed.ncbi.nlm.nih.gov/33318528/);
  [Sci Rep 12:3463, PMC8891385](https://pmc.ncbi.nlm.nih.gov/articles/PMC8891385))

### Vendors (public docs; formulas are not published)
- **Oura** ([Readiness Contributors, updated 2026-10-07](https://support.ouraring.com/hc/en-us/articles/360057791533);
  [Readiness Score, updated 2026-10-01](https://support.ouraring.com/hc/en-us/articles/360025589793)):
  - Takes **up to 2 weeks** to learn averages. "Long-term" means 2 months.
  - Resting HR: last night's lowest HR against the long-term average. The score drops at **3–5 bpm
    higher or 10–15 bpm lower** (asymmetric, fixed bpm).
  - HRV balance: a 14-day weighted average (last 2–5 days weighted more) against a 2- or 3-month average.
    The two pages disagree on which. **Both directions are penalised**: high HRV means "low arousal",
    low HRV means "excessive stress".
  - Temperature: deviation from a personal nightly average. High suggests illness, low may be the cycle.
    No threshold is given.
  - The baseline takes a couple of weeks and is fully accurate after ~30 days
    ([Glossary](https://support.ouraring.com/hc/en-us/articles/5949130374547);
    [Restorative Time](https://support.ouraring.com/hc/en-us/articles/4410641295763-Restorative-Time)).
- **Garmin** (Firstbeat):
  - HRV status = the **7-day average of overnight HRV** against a personal baseline *range*.
  - Balanced = inside the range. **Unbalanced = above or below**. Low = well below. Poor = below the age
    norm.
  - Needs **3 weeks** of nights. The calculation of the range is not published.

  ([Index Sleep Monitor manual](https://www8.garmin.com/manuals/webhelp/GUID-4462687B-8DF5-4719-872E-E16754F9D4B0/EN-US/GUID-5247CEC7-AF06-44FB-B6AD-87C53D4F7941.html);
  [Garmin blog, 2024-08-15](https://www.garmin.com/en-US/blog/fitness/understanding-the-hrv-status-on-your-garmin-smartwatch/):
  above the range after a training jump means the body "is working overtime to recover").
- **Polar** Nightly Recharge:
  - ANS charge (−10…+10, 0 = usual) combines HR, HRV and breathing rate from the first ~4 h of sleep.
  - It is compared with the person's usual level over the **past 28 days**.
  - Shown after **3 nights**. How the inputs are combined and scaled is not published.

  ([Polar Loop manual](https://support.polar.com/e_manuals/polar-loop/polar-loop-user-manual-english/nightly-recharge.htm))
- **WHOOP**:
  - Health Monitor shows green inside / orange-red outside a "typical range" for HRV, Resting HR,
    respiratory rate, skin temperature and SpO2, once there is "sufficient data".
  - The search excerpt of the official support article says thresholds come from the person's history
    and adjust dynamically. It also says **SpO2 uses a fixed range (≥ 90% green), not a personal one**.
  - Recovery is greyed out for the **first 4 days**.

  ([Locker article](https://www.whoop.com/thelocker/health-monitor-feature/);
  [support article](https://support.whoop.com/s/article/WHOOP-Health-Monitor-Report). Both returned 403 or a
  JavaScript-only page, so these come from search excerpts, not a direct read.)

## Open / uncertain
- **No vendor publishes the band width.** Nobody documents an SD multiple, percentile or bpm cut-off for
  HRV, temperature or respiratory rate. Garmin and WHOOP might use SD, percentiles or a model. The only
  published numbers are Oura's Resting HR offsets and the research thresholds above.
- **SWC multiplier:** 0.5 × SD is a convention borrowed from Hopkins' between-subject effect-size thresholds
  and the Plews work. It is not validated for *alerting*, and 1 × CV is also used (Buchheit). The literature
  does not say whether SD on lnRMSSD, raw RMSSD or a CV% is best. Vesterinen used raw RMSSD. Plews,
  Buchheit and Le Meur use ln.
- **MAD / median-based spread** shows up only indirectly: the WHOOP respiratory-rate study used a median
  centre with an SD scale, and NightSignal used a median with a fixed offset. We found no wearable paper
  comparing MAD with SD.
- **High HRV as a warning** is proven only for overreached *endurance athletes* on weekly averages. It is
  unclear whether it means anything for a non-athlete or on a single night. Buchheit says saturation alone
  is not fatigue. Very high single-night RMSSD can also be ectopic beats or artefact (not researched here).
- **Low Resting HR as a warning:** only Oura penalises it, at −10–15 bpm. We found no illness-detection
  paper that flags it.
- **Warm-up for spread vs centre:** no source tests how many nights an SD needs, separately from a mean.
  Kiviniemi used 10 days, WHOOP respiratory rate 14 lagged nights, Vesterinen 28 days, Garmin 21 nights.
  None reports the error of the spread estimate at shorter warm-ups.
- **Skin-temperature threshold:** none published (Oura, WHOOP, TemPredict abstracts). The full TemPredict
  methods were not read.
- Plews 2012/2013 full texts were not read directly. Their claims come from the abstracts.
