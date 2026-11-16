# How could Serenix label sleep and wake better, and estimate sleep stages, from what the Strap records?

**Date:** 2026-11-15 · **Unblocks:** whether and how to improve sleep tracking beyond hr-tracker's
`tools/sleep.py` port: better sleep/wake labelling, a checked set of constants, and sleep stages
(light, deep, REM), which `docs/architecture.md` lists under "Not in v1". Also bears on a
proposed 5-minute minimum Wake Bout (drafted 2026-11-15 as edits to specs 003 and 012 and
GLOSSARY.md; not on `main` when this note was written).

## Answer
- **Serenix's sleep/wake labelling is a motion-only actigraphy rule, and its known weakness is
  quiet wake.** Every motion-only method (Cole–Kripke, Sadeh, Webster, van Hees) finds sleep in
  90%+ of sleep epochs but only 30–55% of wake epochs against polysomnography (PSG). The closest
  published method, van Hees 2015 (sleep = no arm-angle change over 5° for 5 min), reports
  accuracy 83%, sleep sensitivity 91%, wake specificity 45% (n = 28). Motion-only methods as a
  family top out around there. Serenix's constants were set by eye on two nights,
  with no reference to check them against, so no one knows yet whether they are good.
- **Sleep stages need heart rate and HRV, and the realistic ceiling is moderate.** Published
  wrist models that combine motion, HR/HRV and time of night reach 4-class (wake, light, deep,
  REM) agreement of kappa (κ) 0.42–0.65, or 59–79% of epochs. WHOOP's own staging scored 64% and
  κ 0.47 against PSG. Human scorers agree with each other at about κ 0.76. Motion alone cannot
  separate REM from NREM. HRV is what makes REM and deep sleep visible (Oura: REM sensitivity
  29% → 76% with HRV added).
- **What is feasible on the phone in pure Swift (ADR 0002):**
  1. Better sleep/wake from motion: Webster-style rescoring, a per-night threshold as in HDCZA
     (van Hees 2018), and heart rate as a wake signal. All of these are small and testable.
  2. Sleep stages from a small trained model: logistic regression or gradient-boosted trees over
     a handful of epoch features (motion, HR, RMSSD, respiratory rate, time since Sleep Onset).
     These export to plain Swift arithmetic. They need labelled nights to train on, which
     Serenix doesn't have. Walch et al. 2019's Apple Watch + PSG dataset (31 people, open,
     ODC-By) and code (MIT) are the cheapest starting point.
  3. Not feasible: the best published models (κ 0.6–0.75) are LSTMs or CNNs, trained on hundreds
     of PSG nights. The best one also needs the raw PPG waveform, which the Strap doesn't send.
- **AASM sets no minimum length for wake.** Any single 30-second wake epoch after Sleep Onset is
  wake after sleep onset (WASO), and it is never part of total sleep time. The "awakenings
  longer than 5 minutes" threshold comes from the National Sleep Foundation's consensus on
  *counting* awakenings as a quality indicator. **So the 5-minute threshold suits counting Wake
  Bouts, but counting the shorter wake as Time Asleep departs from the standard.** It also
  pushes in the direction actigraphy already errs, since it already overstates sleep.
- **Recommended next step: `/wayfinder` on "sleep accuracy and stages".** Its first slice is a
  measuring stick, before any rule changes. Build a harness that scores the labeller against an
  external reference: Walch's PSG dataset first, then the owner's own nights with a home EEG
  headband. Re-tune or replace the sleep/wake constants against it. Treat stages as a later,
  separate spec once the harness exists. Details are under [Recommended next
  step](#4-recommended-next-step).

## Findings

### 1. Methods feasible on the phone, and their accuracy against PSG

Abbreviations: PSG = polysomnography (the lab reference); κ = Cohen's kappa; sensitivity =
share of PSG sleep epochs scored sleep; specificity = share of PSG wake epochs scored wake;
EBE = epoch-by-epoch.

#### 1a. Sleep/wake from motion (actigraphy)

| Method | How it works | Against PSG |
|---|---|---|
| [Webster 1982](https://doi.org/10.1093/sleep/5.4.389) | Wrist activity summed per epoch, then **rescoring rules** that turn short sleep after long wake into wake | 94–96% of epochs agree in development and prospective sets |
| [Cole–Kripke 1992](https://doi.org/10.1093/sleep/15.5.461) | 1-min epochs; weighted sum of activity from 4 min before to 2 min after, × a scale factor; ≥ 1 is wake | ~88% of epochs; n = 41, 21 in a prospective test |
| [Sadeh 1994](https://doi.org/10.1093/sleep/17.3.201) | 1-min epochs; linear score from an 11-min window's mean, the count of moderately active epochs, an SD and log activity | 91–93% agreement; "sleep consistently higher than wake" |
| [van Hees 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4646630/) | **Arm angle** from the accelerometer; sleep = no change over 5° for ≥ 5 min | n = 28: accuracy 83 ± 8%, sleep sensitivity 91 ± 13%, **wake specificity 45 ± 23%**, overstates sleep by 31 ± 38 min |
| [van Hees 2018 (HDCZA)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6113241/) | Finds the sleep period: 5-min rolling median of angle change; threshold = 10th percentile of the night × 15; blocks over 30 min; gaps under 60 min merged; longest block wins | Clinic patients (n = 28): C-statistic 0.86, accuracy 87%. Good sleepers (n = 22): 0.83, 89%. Overstates sleep efficiency by 8.7–9.4 points |

Reference implementations: Cole–Kripke, Sadeh, Oakley and Webster rescoring are in
[pyActigraphy](https://github.com/ghammad/pyActigraphy/blob/master/pyActigraphy/sleep/scoring_base.py);
van Hees and HDCZA are in [GGIR](https://github.com/wadpac/GGIR). Webster's rules as pyActigraphy
gives them:
- After ≥ 4 min of wake, the next 1 min of sleep becomes wake.
- After ≥ 10 min of wake, the next 3 min become wake.
- After ≥ 15 min of wake, the next 4 min become wake.
- A run of sleep ≤ 6 min with ≥ 15 min of wake on both sides becomes wake.
- A run of sleep ≤ 10 min with ≥ 20 min of wake on both sides becomes wake.

**The shared weakness is low wake specificity.**
- Large actigraphy study, [Marino 2013](https://doi.org/10.5665/sleep.3142) (n = 77, 232,849
  epochs): sensitivity 0.965, **specificity 0.329**. WASO 36.8 min against PSG's 49.1 min,
  understated more as WASO grows past 30 min.
- [Chinoy 2021](https://doi.org/10.1093/sleep/zsaa291) (n = 34): consumer wearables and
  research actigraphs all had sensitivity ≥ 0.93 and specificity 0.18–0.54, worse on
  disrupted nights.
- The reason is that quiet wake, such as lying still awake, looks like sleep to a motion sensor.

**Fit to the Strap.** van Hees uses arm angle, the direction of gravity in the wrist's frame.
Serenix uses the Strap's orientation quaternion, the full 3-D turn between seconds, which also
catches rotation about the vertical axis. They are close but not the same signal; untested
which detects wake better.

#### 1b. Adding heart rate, HRV and time of night (staging)

| Study | n | Inputs / model | Result vs PSG |
|---|---|---|---|
| [Walch 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/) | 31 (Apple Watch) + 188 MESA | Activity, HR variation (band-passed), a cosine "clock proxy"; logistic regression (LR), k-NN, random forest, MLP | Sleep/wake: 90% of epochs, wake spec 59.6% at 93% sleep sens. 3-class (wake/NREM/REM): accuracy 72%, κ 0.28 (MLP) |
| [Fonseca 2017](https://doi.org/10.1093/sleep/zsx097) | 101 train / 51 test | Wrist PPG HRV + accelerometer | Sleep/wake κ 0.55 (actigraphy alone 0.40). 3-class κ 0.46. **4-class κ 0.42, 59%** |
| [Beattie 2017](https://doi.org/10.1088/1361-6579/aa9047) (Fitbit) | 60 | Wrist accelerometer + PPG: movement, breathing, HRV | **4-class 69%, κ 0.52.** Errors mostly light↔REM and light↔wake |
| [Altini & Kinnunen 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8271886/) (Oura) | 106 people, 440 nights | LightGBM (500 trees) on motion, temperature, HRV/breathing, circadian features | 4-class: **57% motion → 60% +temperature → 76% +HRV → 79% +circadian**. Sensitivity: wake 81%, light 82%, deep 74%, REM 78%. No κ given |
| [Radha 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6775145/) | 292 people, 584 nights | 132 ECG HRV features, LSTM (~260k parameters) | 4-class κ 0.61, 77%. Recall: wake 0.71, REM 0.76, light 0.82, **deep 0.61** |
| [Radha 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8443610/) | ECG-pretrained, 60 PPG | LSTM, transfer to wrist | 4-class κ 0.65, 76% |
| [Kotzen 2023 (SleepPPG-Net)](https://doi.org/10.1109/jbhi.2022.3225363) | 2,374 | CNN on the **raw PPG waveform** | 4-class κ 0.75. Not possible here: the Strap sends HR and RR, not the waveform |

**WHOOP's own staging**, for scale:
- [Miller 2020](https://doi.org/10.1080/02640414.2020.1797448) (n = 12): 4-stage 64%, κ 0.47.
  Sensitivity: light 62%, deep 68%, REM 70%, wake 51%.
- [Miller 2022](https://doi.org/10.3390/s22166317) (n = 53): WHOOP 3.0 multi-state 60%,
  κ 0.44; Oura κ 0.43; Apple κ 0.20.
- A 2025 preprint ([doi:10.31234/osf.io/27wun_v1](https://doi.org/10.31234/osf.io/27wun_v1),
  n = 18, not peer-reviewed): WHOOP 4 κ 0.48.
- No PSG validation of WHOOP 5.0 was found.

**The ceiling.** Human scorers agree with each other at κ 0.76
([Danker-Hopfe 2009](https://doi.org/10.1111/j.1365-2869.2008.00700.x)), or 82.6% of epochs,
with deep sleep only 67%
([Rosenberg & Van Hout 2013](https://doi.org/10.5664/jcsm.2350)).

**Why the features work** (physiology):
- **HR and HRV.** NREM shifts the nervous system toward parasympathetic: HR falls and
  high-frequency HRV rises, sharply at sleep onset. In REM, autonomic balance and HR return to
  near-waking levels with sympathetic surges
  ([Trinder 2001](https://doi.org/10.1046/j.1365-2869.2001.00263.x);
  [Somers 1993](https://doi.org/10.1056/nejm199302043280502);
  review [Stein & Pu 2012](https://doi.org/10.1016/j.smrv.2011.02.005)).
- **Motion.** REM brings muscle atonia, so stillness can't tell REM from NREM. Walch's
  motion-only 3-class κ was ~0.08.
- **Breathing.** It changes by stage and is most variable in REM
  ([Douglas 1982](https://doi.org/10.1136/thx.37.11.840)). Respiratory rate can be drawn from RR
  intervals, as Serenix's Nightly Metrics already do for the whole night.
- **Skin temperature.** Wrist skin warms at sleep onset
  ([Kräuchi 2000](https://doi.org/10.1152/ajpregu.2000.278.3.r741)), a useful onset cue. It
  added only 3 points to Oura's staging.
- **Time of night.** Deep sleep comes mostly early in the night; REM increases toward morning
  ([Dijk & Czeisler 1995](https://doi.org/10.1523/jneurosci.15-05-03526.1995)). Time since Sleep
  Onset is therefore a strong, free feature.
- **SpO2.** No staging study used it. It stays a Nightly Metric only.

**What the Strap gives.** The fixture night of 29–30 Oct (Sleep Onset 21:05 to Final Wake 03:42
UTC) was checked for this note:
- RR values arrive in 80% of records, about 19,300 intervals against roughly 27,700 beats
  estimated from heart rate. That is ~70% of beats.
- This is enough for RMSSD and respiratory rate in windows of a few minutes. Frequency-domain HRV
  would need careful gap handling.

#### 1c. What fits in pure Swift with no ML framework
- **Trivial:** every motion rule above (weighted sums, rolling medians, percentiles, run-length
  rules), and Webster rescoring.
- **Small:** logistic regression (a dot product per epoch), a handful of exported decision trees
  or a gradient-boosted ensemble as static arrays, and an HMM/Viterbi pass to smooth stage
  sequences.
  - LightGBM-sized models export to a few hundred kB of constants (an inference, not from a
    paper).
- **Caveat from Walch:** LR matched the neural net only on motion features (3-class accuracy
  71.0% vs 71.3%). With HR and the clock proxy it fell well behind: 3-class κ 0.13 vs 0.28.
  So a linear model is enough for sleep/wake but probably weak for stages. Trees are the better
  small model for stages.
- **Not feasible without Core ML** (an iOS-shell dependency, against ADR 0002's testable core)
  and a large training set: LSTM/CNN models.
- **Training data is the real constraint, not code size.**
  - [Walch's dataset on PhysioNet](https://physionet.org/content/sleep-accel/1.0.0/): 31
    people, Apple Watch triaxial acceleration and PPG heart rate, PSG labels. Open, Open Data
    Commons Attribution v1.0. It has **no RR intervals**, so it can train motion + HR + clock
    models, not HRV ones.
  - [Walch's code](https://github.com/ojwalch/sleep_classifiers) is MIT.
  - MESA and other NSRR datasets have PSG ECG, which can give RR intervals, and actigraphy for
    ~2,000 people, but need an NSRR data-use agreement.

### 2. Gaps in the current sleep/wake labelling

Today's method is `SleepPeriod.swift` and `MotionMinutes.swift`, a faithful port of hr-tracker's
`tools/sleep.py`; specs 003 and 012 describe it.
- A second is active when the Strap turns more than 2° since the previous second.
- A minute is wake when it has ≥ 10 active seconds, or when the median over 5 minutes is ≥ 6.
- After a motion-led wake, up to 10 following minutes stay wake while mean HR is ≥ 6 bpm above
  its 61-minute rolling median.
- The Sleep Period is runs of ≥ 7 sleep minutes, merged across under 60 minutes of recorded
  wake. The merged period with the most sleep minutes wins.
- Time in Bed widens the Sleep Period until 3 minutes in a row of ≥ 30 active seconds.

**How it compares.** In shape it is a cousin of the published methods:
- The per-minute rule plus 5-minute median is like van Hees' "5 min without movement".
- The HR extension does what Webster's rescoring does, carrying wake on after movement stops,
  but uses heart rate instead of a fixed number of minutes.
- The 60-minute merge matches HDCZA's 60-minute gap merge.

**Gaps:**
1. **No reference has ever checked it.** The constants `activeDegrees` 2°, `wakeActiveSeconds`
   10, `wakeMedianActiveSeconds` 6, `raisedHeartRate` 6 bpm, `longestHeartRateExtension` 10,
   `shortestSleepRun` 7, `longestMergedWake` 60, `upActiveSeconds` 30 and `upMinutes` 3 were
   set by eye on two of the owner's nights (`SleepPeriod.swift`, `MotionMinutes.swift`). There was no PSG, diary or
   headband to say which minutes were truly wake.
   - The tests prove parity with hr-tracker, not accuracy.
   - The fixtures are two of the owner's nights too; tuning and checking on the same nights
     would overfit even with a reference.
2. **Quiet wake is invisible unless it follows movement.**
   - Heart rate only *extends* a run of wake minutes that motion started, by at most 10
     minutes.
   - Lying awake and still is labelled sleep. That is exactly the error that puts actigraphy's
     wake specificity at 30–55%.
   - Expect Time Asleep to be overstated and WASO understated, more so on bad nights. Marino
     2013 found the understatement grows past 30 min of WASO.
3. **Fixed thresholds, not per user or per night.**
   - HDCZA sets its threshold from each night's own 10th percentile, so it adapts to sensor
     noise and to how still the person is.
   - Serenix's 2° and 10-second cut-offs assume one Strap's noise and one person's sleep.
   - In the fixture Sleep Period the median per-second turn is 0.28° and 4.3% of seconds exceed
     2°. This is consistent with the code's "resting noise ~0.2°" note, but a different wrist
     fit or firmware could shift it.
4. **One-minute epochs.** PSG and most validation use 30-second epochs, and van Hees uses 5-s
   angles. One-minute bins blur short wake, and make epoch-by-epoch comparison with any reference
   need resampling. This is not wrong, but it should be a choice rather than inherited.
5. **Sleep Onset is not "persistent sleep".**
   - Serenix needs 7 unbroken sleep minutes to start a Sleep Period.
   - Drug trials use 10 minutes (20 epochs) of continuous sleep for *persistent* sleep onset
     ([e.g. NCT01021852](https://clinicaltrials.gov/study/NCT01021852)), and AASM uses the first
     epoch of any sleep.
   - The 7 is in between and unexplained.
6. **No heart-rate or temperature cue for the start and end of sleep.**
   - Wrist warming at onset and HR falling to the night's level are both used by HDCZA-style and
     consumer methods (Oura's temperature feature).
   - Time in Bed comes from motion alone, and the Sleep Period's edges move with heart rate only
     through the wake extension above.
7. **The proposed 5-minute minimum Wake Bout** (not on `main`; see the top of this note).
   - The threshold matches the National Sleep Foundation consensus indicator, "number of
     awakenings > 5 minutes" ([Ohayon 2017](https://doi.org/10.1016/j.sleh.2016.11.006)), which
     is a rule for *counting* awakenings.
   - AASM scoring has no minimum: any 30-s wake epoch after sleep onset is WASO and is left out
     of total sleep time. Only arousals have a duration rule, ≥ 3 s after ≥ 10 s of sleep
     ([AASM ISR](https://isr.aasm.org/helpv5/ScoringArousalsA.html)).
   - Counting 1–4 minute wake runs as Time Asleep therefore makes Time Asleep differ from the
     standard measure.
   - Because motion actigraphy already overstates sleep (gap 2), it widens the existing bias
     rather than correcting noise. A short wake run that motion caught is more likely real than
     spurious.
   - An option closer to the literature: show and count only Wake Bouts ≥ 5 minutes (the
     NSF-style count), but leave every wake minute out of Time Asleep. This is a judgement for
     the spec that settles Wake Bouts, not settled by this note.

### 3. Validating without a sleep lab

[Menghini et al. 2021](https://doi.org/10.1093/sleep/zsaa170) set a standard framework for
testing sleep trackers, with open R code
([pipeline](https://sri-human-sleep.github.io/sleep-trackers-performance/AnalyticalPipeline_v1.0.0.html),
[GitHub](https://github.com/SRI-human-sleep/sleep-trackers-performance)):
- per-night bias for total sleep time, sleep efficiency, sleep-onset latency and WASO;
- Bland–Altman limits of agreement;
- epoch-by-epoch sensitivity, specificity, accuracy and κ.

[Depner 2020](https://doi.org/10.1093/sleep/zsz254) gives best practices. ±30 min on total sleep
time and WASO has been used as clinically acceptable
([de Zambotti 2019](https://doi.org/10.1080/15402002.2017.1300587)).

Four references are available without a lab, cheapest first:
1. **Public PSG-labelled wrist data (no new nights).**
   - Walch's 31 Apple Watch nights with PSG labels are open.
   - Adapter needed: Serenix's labeller takes per-second turn angles, and the dataset gives raw
     acceleration. The change in gravity direction between seconds approximates the turn,
     missing only rotation about the vertical axis.
   - Its heart rate is PPG-derived, sampled irregularly.
   - It tests sleep/wake and the Sleep Period against real PSG on 31 people other than the
     owner.
   - It can also train and test a 3-class (wake/NREM/REM) motion + HR model, which is the
     dataset's own design.
   - Limits: it is not the Strap. There is no RR, so no HRV features, and no quaternion.
2. **A home EEG headband worn with the Strap for 10–14 nights**, mixing ordinary and disrupted
   nights:
   - [ZMax](https://doi.org/10.1101/2023.08.18.553744): κ 0.72 against PSG with open scoring
     (preprint).
   - Somfit (tested in [Miller 2022](https://doi.org/10.3390/s22166317)): κ 0.52 multi-state.
   - [Dreem](https://doi.org/10.1093/sleep/zsaa097): 83.5% vs 86.4% for experts, but its
     consumer availability is uncertain.
   - Procedure: align clocks, resample to 30-s epochs, then run Menghini's EBE and Bland–Altman
     analysis.
   - The headband is not PSG, so judge Serenix against the headband's own error.
   - This is the only route that gives labelled *Strap* nights, with RR and quaternion, for
     training or checking stages.
3. **Consensus Sleep Diary** ([Carney 2012](https://pmc.ncbi.nlm.nih.gov/articles/PMC3250369/))
   each morning. Free and validated as a standard instrument. Good for lights-out, wake time and
   rough awakenings, but too coarse for minute-level wake or stages.
4. **Planned quiet-wake nights.** On a few evenings, lie still but awake for a timed 20–30
   minutes, phone timer noted, before trying to sleep. This directly measures gap 2: how much
   still wake is labelled sleep. It is a protocol suggestion, not from a paper.

**Rules for any tuning:**
- Freeze the constants before scoring held-out nights.
- Never tune on the nights used to judge.
- Report per-night results, not only pooled ones.
- Keep the two existing fixture nights as parity tests, not as accuracy evidence.

The owner's own nights are public fixtures (`docs/conventions.md`). A headband's raw EEG is a
new kind of personal data, so whether to commit labels only, or nothing, needs a decision.

### 4. Recommended next step

This is too big and too uncertain for one spec. Run **`/wayfinder` on "sleep accuracy and
stages"**, with a map roughly like this:
1. **Measuring stick first.** A spec for an accuracy harness, with no app change:
   - a `SerenixCore` seam that scores a night's minute labels against a reference hypnogram
     (EBE sensitivity, specificity, κ; Time Asleep, WASO and onset bias);
   - an adapter for Walch's PhysioNet nights.

   Output: today's labeller's real numbers, the baseline for everything after.
2. **Decide the Wake Bout and Time Asleep question** with those numbers, before any 5-minute
   minimum Wake Bout ships (gap 7).
3. **Sleep/wake improvements**, each kept only if the harness shows a gain on held-out nights:
   - Webster-style rescoring;
   - a per-night HDCZA-style threshold;
   - HR- and RMSSD-based quiet-wake detection;
   - a temperature onset cue;
   - re-tuning the "set by eye" constants.

   Each gain breaks hr-tracker parity (spec 003 user story 5), so it needs a decision to let
   Serenix lead hr-tracker, or to change both.
4. **Owner data collection:** headband plus diary, 10–14 nights. A hardware purchase and a
   privacy decision for the owner.
5. **Sleep stages** as their own spec, after 1–4:
   - Start with a 3-class (wake/NREM/REM) model trained on Walch's data from motion, HR and
     time since onset.
   - Then light/deep/REM using RMSSD and respiratory rate, once owner headband nights exist.
   - Show stages honestly: WHOOP itself reaches only κ ~0.47.
   - Needs an ADR, since architecture.md says "Not in v1" and a trained model's constants are a
     new kind of artefact.
   - ADR 0005 is unaffected: light, deep and REM are generic terms, not WHOOP's.

## Open / uncertain
- **Constants not checked against the original papers**, which are paywalled: the Cole–Kripke
  weights, Oakley's thresholds and Webster's rules were read from pyActigraphy. AASM's wake rule
  and sleep-onset wording were seen only via secondary copies; the arousal rule was confirmed on
  AASM's own site.
- **Numbers read through summaries:** Walch's per-feature and per-classifier numbers and
  Altini's per-stage numbers come from tables read through a summariser. Confirm before quoting
  them in a spec. Altini reports no κ.
- **Untested on the Strap:** whether its quaternion turn behaves like van Hees' gravity-only arm
  angle (it also includes rotation about the vertical), and whether a model trained on Apple
  Watch accelerometer and PPG data transfers to it.
- **WHOOP 5.0:** no peer-reviewed PSG validation of its staging was found, so the "match the
  vendor" bar is set from WHOOP 3.0 and 4.0.
- **No n = 1 protocol in the literature:** the 10–14-night headband plan in §3 is a synthesis.
- **Unknown accuracy of the current labeller:** how well it scores against PSG is unknown until
  step 1 of the map runs. The gaps in §2 come from the literature and the code, not from
  measurement.
