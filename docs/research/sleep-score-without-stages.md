# How do sleep scores rate a night, and what can be done without sleep stages?

**Date:** 2026-11-02 · **Unblocks:** the Sleep Score formula: which inputs make up Serenix's
0–100 Sleep Score for a Night, how they are weighted, and its bands (issue #35; research for
issue #33)

## Answer
- **Every vendor's score combines three or four kinds of input.** The first is how much the
  user slept against a target, and every vendor uses it. The second is continuity: sleep
  efficiency, wake bouts and restlessness. The third is sleep stages, used by Oura, Fitbit,
  Garmin and Polar Sleep Plus Stages, but not by WHOOP. Some vendors add a fourth: a
  physiological "restoration" signal from heart rate or HRV during sleep (Fitbit restoration,
  Garmin sleep stress, WHOOP Sleep Stress, Oura's use of resting HR). Some also add timing or
  regularity (WHOOP Sleep Consistency, Oura Timing).
- **WHOOP's current Sleep Performance has no stage input, so it is the closest template for
  Serenix.** Its four components are Hours vs. Needed, Sleep Consistency, Sleep Efficiency and
  Sleep Stress. Polar's original Sleep Plus (before 2019) also rated nights without stages,
  using sleep time against a preferred amount, actual-sleep %, and a 1–5 continuity rating.
  Fitbit and Garmin do not score a night without stages ("To get a Sleep Score, you need to
  receive sleep stages", Fitbit). Oura counts REM and deep sleep as two of its seven
  contributors.
- **Published research supports a stage-free score.** The National Sleep Foundation's expert
  consensus agreed that four continuity measures indicate good sleep quality: sleep latency,
  awakenings longer than 5 minutes, wake after sleep onset (WASO) and sleep efficiency. It
  reached little or no consensus that sleep architecture (stages) does. Sleep regularity, as
  measured by the Sleep Regularity Index, predicted all-cause mortality more strongly than
  sleep duration in about 61,000 UK Biobank participants.
- **Serenix could compute every non-stage input from data it already has.** These are Time Asleep against Sleep Need;
  efficiency (Time Asleep ÷ Time in Bed); wake bouts inside the Sleep Period, as a count over
  5 minutes and total minutes; latency (from the start of Time in Bed to Sleep Onset);
  regularity of Sleep Onset and Final Wake over recent Nights; and Sleeping HR against its
  Baseline as a restoration signal. What it loses without stages is the REM and deep sleep
  share, which is 25 of 100 points in Fitbit's widely reported (unverified) split, 2 of 6 averaged
  components at Polar, and 2 of 7 contributors at Oura.
- **Few weights are published, and bands differ by vendor.** Fitbit's 50/25/25 split (time
  asleep / deep and REM / restoration) comes from Fitbit community moderators, not official
  help pages. Polar says its score is the average of its six components. WHOOP and Oura publish
  no weights; Oura says total sleep is the most important contributor. Bands: Oura 85/70/60;
  Garmin and Fitbit 90/80/60; WHOOP's Hours vs. Needed 85/70. Polar gives only a typical range
  of 70–85. ADR 0005 keeps Serenix on its own scale, so the weights and cut-offs are a design
  choice.

## Findings

### WHOOP — Sleep Performance
whoop.com and support.whoop.com returned HTTP 403/401 or a JavaScript shell to direct fetches.
The points below come from search excerpts of WHOOP's own pages (dated about 2025) and from the
developer API docs, which could be read.
- **Components:** the updated Sleep Performance combines four components:
  - **Hours vs. Needed (sufficiency):** sleep against the night's sleep need.
  - **Sleep Consistency:** how regularly the user goes to bed and wakes up.
  - **Sleep Efficiency:** the share of time in bed spent asleep.
  - **Sleep Stress:** "how much time you spent in high stress throughout the night".

  The earlier version was Hours vs. Needed alone. ([WHOOP Support, "WHOOP
  Sleep"](https://support.whoop.com/s/article/WHOOP-Sleep?language=en_US), search excerpt.)
- **Targets per component**, from the same support article (excerpt):

  | Component | Optimal | Sufficient | Poor |
  |---|---|---|---|
  | Hours vs. Needed | 85%+ | 70–85% | <70% |
  | Sleep Consistency | 80%+ | 70–80% | <70% |
  | Sleep Efficiency | 90%+ | 80–90% | <80% |
  | Sleep Stress | <1% of sleep | 1–5% | >5% |

  A WHOOP community moderator said 90%+ is still optimal for consistency, which conflicts with
  the 80% figure ([WHOOP Community](https://www.community.whoop.com/t/whoop-sleep-consistency/800),
  a lead only).
- **How components combine:** WHOOP's Locker article on the sleep metrics says that when the
  sleep opportunity is shorter than the need, better consistency, efficiency or stress has
  limited effect, and that one strong input cannot fully offset a weak one. No numeric weights
  are given. ([WHOOP, "How to improve sleep quality using four sleep
  metrics"](https://www.whoop.com/us/en/thelocker/sleep-capodilupo-whoop-metrics-rested/),
  search excerpt.)
- **Sleep Consistency method:** the timing of last night's sleep compared with the previous 4
  days, framed as the likelihood that the sleep/wake state at a given clock time matches across
  those days. WHOOP contrasts it with the Sleep Regularity Index, which uses longer spans. It
  needs at least 3 consecutive nights of wear.
  ([WHOOP, "Sleep Consistency: why we track it"](https://www.whoop.com/us/en/thelocker/new-feature-sleep-consistency-why-we-track-it/);
  [WHOOP Support, "What is Sleep
  Consistency?"](https://support.whoop.com/hc/en-us/articles/360019623493-What-is-Sleep-Consistency-);
  search excerpts.)
- **The API exposes the components.** The sleep `score` object has
  `sleep_performance_percentage`, `sleep_consistency_percentage` and
  `sleep_efficiency_percentage`. It also has a `stage_summary` that includes
  `total_in_bed_time_milli`, `total_awake_time_milli` and `disturbance_count`. The
  `sleep_needed` breakdown is `baseline_milli` + `need_from_sleep_debt_milli` +
  `need_from_recent_strain_milli` + `need_from_recent_nap_milli` (negative).
  ([WHOOP Developer docs, Sleep](https://developer.whoop.com/docs/developing/user-data/sleep),
  read 2026-11-02.) Stages are reported but none of the four published components is a stage
  measure.

### Oura — Sleep Score (support pages updated September–October 2026)
- **Bands:** 0–100, with **85–100 Optimal, 70–84 Good, 60–69 Fair, 0–59 Pay attention**. Total
  sleep time is "the most important factor". Oura's analysis also uses resting heart rate,
  body temperature and movement. ([Oura, Sleep
  Score](https://support.ouraring.com/hc/en-us/articles/360025445574-Sleep-Score), updated
  2026-09-25)
- **Contributors** ([Oura, Sleep
  Contributors](https://support.ouraring.com/hc/en-us/articles/360057792293-Sleep-Contributors),
  updated 2026-10-01):
  - **Total sleep:** light + REM + deep, naps included; 7–9 h for most adults.
  - **Efficiency:** % of time in bed asleep; about 85% indicates uninterrupted sleep. It drops
    if falling asleep takes over 20 min or with long or frequent wake-ups.
  - **Restfulness:** wake-ups, excess movement, getting out of bed. No numeric target.
  - **REM sleep:** about 1.5 h is optimal.
  - **Deep sleep:** adults average 15–20% (1–1.5 h).
  - **Latency:** ideally 15–20 min; under 5 min may mean overtiredness. Longest sleep period
    only.
  - **Timing:** sleep midpoint ideally between midnight and 3 a.m., depending on chronotype.
- **Not published:** contributor weights and how each maps to 0–100.
- **Without stages:** REM and deep sleep are 2 of 7 contributors. Oura documents no fallback.
  Every other contributor can be computed from sleep/wake alone.

### Fitbit (Google Health app) — Sleep Score
- **Current help article** ([Google Health Help, "What's the Sleep
  Score"](https://support.google.com/fitbit/answer/14236513?hl=en), read 2026-11-02):
  - **Components (no weights given):** sleep duration in the primary sleep window, time to
    sound sleep, sound sleep, restlessness (brief wakeful moments), full awakenings (only wake
    periods over 5 minutes count) and interruptions (total time awake between first falling
    asleep and finally waking).
  - **Scoring:** the score compares the night against targets tailored to age and gender.
  - **Bands:** **Excellent 90–100, Good 80–89, Fair 60–79, Poor <60**. Most users average 72–83.
  - **Without stages:** "To get a Sleep Score, you need to receive sleep stages."
- **Older Fitbit score:** a sum of time asleep, deep and REM sleep, and restoration, up to 100.
  - **Weights:** the commonly cited 50 / 25 / 25 split and the restoration definition (higher
    when sleeping heart rate is below daytime resting HR; lower with tossing and turning)
    come from Fitbit community moderator posts. Those pages now redirect to the Google Health
    community, so they could not be re-read here. Treat the weights as unverified.
  - **Possibly superseded:** the Google Health app's redesigned score may have replaced this
    split.

### Garmin — Sleep Score
- **Bands:** 0–100: "excellent (90–100), good (80–89), fair (60–79) and poor (0–60)".
  ([Garmin blog, 2025-03-14](https://www.garmin.com/en-US/blog/fitness/how-well-do-you-sleep-new-data-examines-garmin-users-sleep/))
- **Inputs:**
  - **Duration:** against age-based recommendations (generally 7–9 h, per the CDC).
  - **Quality:** stages (time in light, deep and REM, and the transitions between them), awake
    time, restlessness, and average stress during sleep, which is HRV-based.
  - Source: [Garmin blog, 2025-01-30](https://www.garmin.com/en-US/blog/?p=34517).
- **Not published:** weights. A search excerpt of a Garmin page mentions counting awakenings
  longer than 5 minutes; this was not confirmed on a page that could be read.
- **Without stages:** stages are central to the published "quality" half. Garmin documents no
  stage-free score.

### Polar — Sleep Plus Stages score and the older Sleep Plus
- **Sleep score (with stages):**
  - **Scale:** 1–100, typically 70–85.
  - **Components:** six, in three themes: Amount (sleep time against the preferred time; 7–9 h
    for adults, default 8 h); Solidity (long interruptions over 90 s, where about 15 min total
    is typical and none scores best; continuity 1–5, adult average 3.2; actual sleep %, adult
    average about 93%); and Regeneration (REM %, best at 25%; deep %, best at about 17%; both
    lose points above or below).
  - **Combination:** "Sleep score is the average of these scores", so the six components are
    equally weighted.
  - **Bands:** none named.
  - Source: [Polar Support, Sleep Plus Stages](https://support.polar.com/en/sleep-plus-stages-sleep-tracking),
    read 2026-11-02.
- **Sleep Plus (no stages; stages were added in 2019):**
  - **Measures:** sleep time from falling asleep to waking; actual sleep % (sleep time minus
    interruptions); continuity 1–5, from fragmented to very continuous, where 3–5 is good and
    values are individual; amount against a preferred sleep time, met when no more than 15 min
    short.
  - **Feedback:** compares actual sleep % with age-related cut-offs plus continuity, and an
    optional self-rating. No 0–100 score.
  - Source: [Polar Support, "The what and how of Polar Sleep
    Plus"](https://support.polar.com/en/support/Polar_Sleep_Plus); the stage history is from the
    [Sleep Plus white paper](https://www.polar.com/en/img/static/whitepapers/pdf/polar-sleep-plus-white-paper.pdf)
    (search excerpt).
  - **Fallback without continuous HR:** Polar shows "basic sleep data": sleep time,
    interruptions, actual sleep and continuity, without the score.
    ([Polar, Troubleshooting Sleep Plus Stages](https://support.polar.com/en/troubleshooting-polar-sleep-plus-stages),
    search excerpt.)
- **Polar sleep charge:** the night's sleep score against the user's own 28-day usual, in five
  categories. See [readiness-composite-scores.md](readiness-composite-scores.md).

### Published research
- **Continuity, not architecture, has expert consensus.** A National Sleep Foundation panel
  reviewed 277 studies using a modified Delphi process. It agreed that sleep latency, the number
  of awakenings over 5 minutes, WASO and sleep efficiency are appropriate indicators of good
  sleep quality. There was little or no consensus on sleep architecture or naps.
  ([Ohayon et al., Sleep Health 2017;3(1):6–19, doi
  10.1016/j.sleh.2016.11.006](https://doi.org/10.1016/j.sleh.2016.11.006); abstract read via
  [Duke Scholars](https://scholars.duke.edu/publication/1172405).) Numeric cut-offs are widely
  reported but were not read in the paper: good sleep is efficiency ≥85%, latency ≤30 min, ≤1
  awakening and WASO ≤20 min; poor sleep is efficiency ≤64%, latency ≥45 min, ≥4 awakenings and
  WASO ≥41 min. ([DiMe table](https://datacc.dimesociety.org/wp-content/uploads/2024/04/Connecting-Core-Measures_-Suggested-Recommendations-for-Interpreting-Data.pdf),
  a secondary source.)
- **Sleep Regularity Index (SRI):**
  - **Definition:** the likelihood that any two minutes 24 h apart are in the same sleep/wake
    state, rescaled as 200 × (p − ½). That gives −100 to 100: 100 is perfectly periodic sleep
    and 0 is random sleep.
  - **Data used:** whole weeks of non-missing data (1–4 weeks) from 30-day sleep diaries.
  - **Findings:** irregular sleepers had melatonin onset about 2.5 h later, and the SRI
    correlated with academic performance (r = 0.37).
  - Source: [Phillips et al., Sci Rep 2017;7:3216,
    PMC5468315](https://pmc.ncbi.nlm.nih.gov/articles/PMC5468315/).
- **Regularity predicts mortality more strongly than duration.**
  - **Study:** SRI computed from accelerometers in 60,977 UK Biobank participants.
  - **Result:** the top four SRI quintiles had 20–48% lower all-cause mortality than the least
    regular quintile. Regularity predicted mortality better than sleep duration did.
  - **Limits:** the study is observational, and UK Biobank participants are not diverse.
  - Source: [Windred et al., Sleep 2024;47(1):zsad253](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10782489/);
    details from the commentary and abstract.
- **SRI implementations differ.** Two open-source SRI packages gave markedly different scores
  for the same data.
  ([BIDMC Smith Center listing](https://smithcenter.bidmc.org/publications/comparison-sleep-regularity-index-sri-scores-calculated-open-source-packages-and),
  abstract-level only.)
- **Sleep health is multidimensional.** Buysse's definition is satisfaction, appropriate
  timing, adequate duration, high efficiency and sustained daytime alertness. The RU-SATED
  instrument adds regularity. ([Buysse, Sleep 2014;37(1):9–17, PMID
  24470692](https://pubmed.ncbi.nlm.nih.gov/24470692/); the dimension list is quoted in later
  reviews.) Stages are not among these dimensions.
- **Sleeping HR and HRV as a restoration signal.**
  - **Study:** 4,098 employees; HR, HRV and an HRV-derived recovery state over the first 3 h of
    sleep, compared within each person between nights with and without alcohol.
  - **Result:** alcohol lowered the recovery state dose-dependently, by 9.3, 24.0 and 39.2
    percentage units at low, moderate and high intake.
  - **What it supports:** an overnight HR/HRV signal compared with the person's own usual picks
    up disrupted overnight recovery.
  - Source: [Pietilä et al., JMIR Ment Health 2018;5(1):e23, doi
    10.2196/mental.9519](https://mental.jmir.org/2018/1/e23); abstract only.

### Inputs mapped to Serenix (inference from the above, not a decision)
| Input | Who uses it | Serenix source | Without stages? |
|---|---|---|---|
| Time Asleep against Sleep Need | WHOOP (Hours vs. Needed), Polar (vs. preferred), Oura, Fitbit, Garmin (vs. 7–9 h or age norm) | Time Asleep, Sleep Need (incl. Sleep Debt) | yes |
| Sleep efficiency | WHOOP, Oura, Polar (actual sleep %), NSF | Time Asleep ÷ Time in Bed | yes |
| Wake bouts / WASO / awakenings >5 min | Fitbit (full awakenings, interruptions), Garmin, Oura (restfulness), Polar (long interruptions, continuity), NSF | wake bouts inside the Sleep Period | yes (movement-only "restlessness" needs motion) |
| Latency | Oura, Fitbit (time to sound sleep), NSF | start of Time in Bed → Sleep Onset | yes, if Time in Bed starts before Sleep Onset |
| Regularity / timing | WHOOP (4-day consistency), Oura (midpoint), SRI | Sleep Onset and Final Wake of recent Nights | yes; needs ≥3–4 prior Nights |
| Restoration (overnight HR / HRV) | Fitbit (restoration), Garmin and WHOOP (sleep stress), Oura (resting HR) | Sleeping HR (and HRV) against Baseline | yes; overlaps Readiness |
| REM and deep share | Oura, Fitbit, Garmin, Polar | — | **no** |

## Open / uncertain
- **WHOOP's primary pages could not be read directly** (HTTP 403/401 or a JavaScript shell). The
  four components, the per-component targets and the Consistency method come from search
  excerpts. The excerpts disagree on the Consistency optimum (80% or 90%). How WHOOP combines
  the four into one percentage is not published.
- **Fitbit's 50/25/25 weights are unverified.** They come from community moderator posts that
  now redirect. The current Google Health help article lists different components with no
  weights, and it requires stages.
- **Garmin publishes no weights.** The "awake over 5 minutes" detail was not confirmed on a
  page that could be read. The poor band is written as "0–60" in one Garmin post and "below 60"
  elsewhere.
- **Polar's per-component scales** (how sleep time or actual sleep % maps to a component score
  before averaging) are not published.
- **NSF numeric cut-offs** (85% efficiency, 20 min WASO, and so on) come from secondary
  summaries. Only the Ohayon 2017 abstract was read.
- **Regularity needs history.** WHOOP uses 4 days and needs 3 nights; the SRI needs 1+ weeks.
  How a regularity input behaves on early Nights, or after a gap in wear, is a design question,
  as is how Naps would count (WHOOP's consistency may include naps; GLOSSARY says a Nap never
  makes a Night).
- **Sleeping HR is already a Readiness input**, so adding it to Sleep Score would count it
  twice. No vendor documents how it avoids double-counting between its sleep and readiness
  scores.
- **No vendor's sleep score has a published peer-reviewed validation** against an outcome. The
  research supports the individual inputs (continuity, regularity, duration), not any weighted
  combination of them.
