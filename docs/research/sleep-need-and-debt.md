# How do established trackers and the sleep literature work out Sleep Need and Sleep Debt?

**Date:** 2026-11-02 · **Unblocks:** the Sleep Need and Sleep Debt rules (issue #34), which
also move Readiness's Time Asleep input from a fixed 7 h mark to the Night's Sleep Need
(question: issue #32)

## Answer
- **Typical need comes from one of two sources: the person's own Nights, or a fixed figure by
  age.** WHOOP learns a personal "baseline" from your own sleep (one WHOOP article says it looks
  at the past 28 days). Oura uses your sleep over the past 90 days and drops unusually short or
  long nights. Garmin starts from an age figure (about 8 h under 35, about 7.5 h over 65) and
  keeps every recommendation between 7 h and 9 h. The guidelines give the fixed fallback:
  AASM/SRS say 7 h or more for adults, and NSF says 7–9 h (7–8 h for adults 65 and over). In the
  research, need differs from person to person by about ±1 h around 8.4 h (Kitamura 2016: 7.3–9.3
  h in 15 young men). Nobody publishes the exact estimator.
- **Debt looks back days to two weeks. Oura and the research show that it is repaid slowly.**
  Oura adds up the shortfall against need over the **past 14 days, with recent days weighted
  more**. Garmin says the three previous nights "can play a role", and also counts extra sleep
  as a "bank" that lowers the next night's need. WHOOP adds a "need from sleep debt" term but
  doesn't publish the look-back or the decay. Studies agree that one long night doesn't clear
  debt. After 5 nights of 4 h, one 10 h night in bed (about 9 h asleep) did not fully restore
  alertness (Banks 2010). An hour of habitual shortfall took about 4 days of free sleep to clear
  (Kitamura 2016). No vendor publishes how much debt is repaid per night.
- **Most vendors raise need after a day of exertion, but the research behind that is weak.**
  WHOOP adds a "need from recent strain" term. Garmin says a hard workout can raise need a lot
  and a quiet day can lower it a little. Oura doesn't put activity into need. The research only
  shows small effects of exercise on how long people sleep (Kredlow 2015). No study gives an
  amount of extra need per unit of Load.
- **Vendors that see naps take them off the need (WHOOP, Garmin) or count them as sleep (Oura).**
  WHOOP's API shows nap need as zero or negative, and Garmin says naps "will never increase"
  need. Serenix doesn't detect Naps, so it can only leave them out. A user who naps will then
  look as if they owe more Sleep Debt than they do.
- **New users get population defaults or nothing.** Oura shows Sleep Debt only after 5 Nights in
  the past 14 days. Its Readiness takes up to 2 weeks to learn averages. Fitbit's Labs feature
  asks for at least 5 days of wear. Garmin always has its age figure to fall back on. WHOOP
  calibrates its baselines over the first weeks of wear (2–4 weeks, depending on the source).
  A rule that would match these: use a fixed figure (say 8 h, kept within 7–9 h) until enough
  Nights exist, then use the person's own figure. That rule is an inference from the sources, not
  something any of them publishes.

## Findings

### Published research and guidelines

**How much sleep adults need (population figures)**
- AASM and SRS consensus (2015): "Adults should sleep 7 or more hours per night on a regular
  basis." Sleeping more than 9 h "may be appropriate for young adults, individuals recovering from
  sleep debt, and individuals with illnesses". Need varies between people for "genetic,
  behavioral, medical, and environmental" reasons.
  ([Watson et al., Sleep 2015;38(6):843–4, PMC4434546](https://pmc.ncbi.nlm.nih.gov/articles/PMC4434546/))
- NSF (2015): 7–9 h is recommended for young adults and adults, and 7–8 h for older adults (65
  and over). ([Hirshkowitz et al., Sleep Health 2015;1(4):233–43, PMID
  29073398](https://pubmed.ncbi.nlm.nih.gov/29073398/))

**Measuring one person's need**
- In this study, 15 healthy young men slept as long as they liked (12 h in bed a night) for 9
  nights in a row.
  - **Method:** the authors fitted an **exponential decay** to the falling Time Asleep. The level
    it settled at was taken as the person's optimal sleep duration (OSD).
  - **Need and habit:** OSD was **8.41 ± 0.18 h (range 7.29–9.26 h)** against a habitual
    **7.37 h** at home. That left a "potential sleep debt" of **1.04 h (range −0.58 to 2.73
    h)**.
  - **Debt mattered more than sleep:** the debt predicted sleepiness better than the hours
    slept.
  - **Rebound:** the first extended night ran **10.59 h**.
  - **Repayment:** the authors say "only 1 h of PSD takes four days to recover to their optimal
    level".
  - ([Kitamura et al., Sci Rep 2016;6:35812,
    PMC5075948](https://pmc.ncbi.nlm.nih.gov/articles/PMC5075948/))
- This study gave 16 h in bed a day. Time Asleep settled at **8.9 h in younger** and **7.4 h in
  older** healthy adults (aged 60–76). Need, or the ability to sleep, falls with age.
  ([Klerman & Dijk, Curr Biol 2008;18(15):1118–23,
  PMC2582347](https://pmc.ncbi.nlm.nih.gov/articles/PMC2582347/))

**How debt builds and how it is repaid**
- Two weeks of 6 h or 4 h in bed caused cumulative, dose-dependent deficits. Six hours or less
  a night was equivalent to up to 2 nights of total sleep deprivation. People were largely
  unaware of the decline: sleepiness ratings did not separate the 6 h and 4 h groups. Lapses grew
  almost linearly with wakefulness beyond about **15.84 h a day**, which implies about 8.2 h of
  daily need. That figure is our arithmetic, not the authors' claim.
  ([Van Dongen et al., Sleep 2003;26(2):117–26, PMID 12683469](https://pubmed.ncbi.nlm.nih.gov/12683469/))
- After 5 nights of 4 h in bed, people were given one recovery night of 0–10 h in bed. Recovery
  rose with the dose along an exponential curve, but it was **still incomplete at 10 h in bed
  (8.96 h asleep)**. The authors say complete recovery may need a longer night or "multiple
  nights". ([Banks et al., Sleep 2010;33(8):1013–26,
  PMC2910531](https://pmc.ncbi.nlm.nih.gov/articles/PMC2910531/))
- With 5 h nights on weekdays, free weekend sleep added only about **66 min** on average. It did
  not prevent the metabolic harm once short nights resumed.
  ([Depner et al., Curr Biol 2019;29(6):957–67, doi
  10.1016/j.cub.2019.01.069](https://doi.org/10.1016/j.cub.2019.01.069); abstract and the
  [University of Colorado release](https://www.colorado.edu/today/2019/02/28/catching-sleep-weekend-doesnt-work)
  read, full text not read)

**Exertion and sleep**
- A meta-analysis of 66 studies found that acute exercise has a **small** effect on total sleep
  time, and so does regular exercise. The effects depended on sex, age, fitness, and the type,
  timing and length of exercise. ([Kredlow et al., J Behav Med 2015;38(3):427–49, PMID
  25596964](https://pubmed.ncbi.nlm.nih.gov/25596964/), abstract only) No source was found that
  gives extra minutes of need per unit of training load.

### WHOOP — Sleep Need
- **Four parts that add up:** the official developer API's `sleep_needed` object has
  `baseline_milli`, `need_from_sleep_debt_milli`, `need_from_recent_strain_milli` and
  `need_from_recent_nap_milli`. The docs page shows them only in an example (27,395,716 /
  352,230 / 208,595 / −12,312 ms, about 7.6 h + 6 min + 3.5 min − 0.2 min). The docs also say
  "Naps reduce the amount of sleep needed by a member for the next Cycle."
  ([WHOOP Developer docs, Sleep](https://developer.whoop.com/docs/developing/user-data/sleep),
  read 2026-11-02) The field descriptions (debt is extra need from earlier shortfall, strain need
  is added need, nap need is zero or negative) come from a
  [third-party copy of the schema](https://raw.githubusercontent.com/api-evangelist/whoop/refs/heads/main/json-schema/whoop-sleepneeded-schema.json),
  not from WHOOP's page.
- **Locker article ("How much sleep do I need"):**
  - **The four inputs:** baseline, strain, sleep debt and naps.
  - **Baseline:** "determined by your physiology, which WHOOP begins to learn about as soon as
    you put on the Strap".
  - **Debt:** extra sleep needed tonight "due to insufficient sleep on previous nights".
  - **Naps:** need is "reduced by the amount of time you napped for".
  - **Typical patterns:** WHOOP looks at bed and wake times, duration and efficiency over the
    **past 28 days**.
  - ([whoop.com/thelocker/how-much-sleep-do-i-need](https://www.whoop.com/us/en/thelocker/how-much-sleep-do-i-need/);
    HTTP 403 to direct fetch, so this comes from search excerpts only)
- **Not published:** how far back debt looks, how much of it carries over each night, how the
  strain term grows with Strain, and the exact calibration period. A
  [WHOOP community post](https://community.whoop.com/t/how-is-100-of-the-my-sleep-need-calculated/527)
  (a lead only) gives "Baseline + Strain + Previous Sleep Debt − Naps" and says the baseline is
  learned over about 28 days. Another WHOOP page says baselines calibrate after two weeks.
- WHOOP's Sleep Performance is hours slept as a share of Sleep Need. The user can aim for 100%,
  85% or 70% of need (search excerpt of the Locker article).

### Oura — Sleep Debt and Sleep balance (pages updated September–October 2026)
- **Sleep need:** "Your daily sleep need is based on your typical sleep patterns over the past
  90 days. It filters out unusually short or long nights to estimate a balanced, personalized
  baseline."
- **Sleep Debt:** "calculated by looking at your total sleep each day" against that need,
  including long and short sleep sessions. It is "calculated over the past two weeks, giving more
  weight to the most recent days".
- **Levels:** None (0 h), Low (<2 h), Moderate (2–5 h), High (>5 h).
- **Minimum data:** "at least five nights of sleep data within the past 14 days".
- **Not stated:** whether sleep beyond need repays debt or builds a bank.
- Source for these four points: [Oura Support, Sleep
  Debt](https://support.ouraring.com/hc/en-us/articles/46233324892691), updated 2026-10-14.
- **Blog (published 2025-12-15, updated 2026-09-24):**
  - **Need:** "derived from your 90-day sleep history".
  - **Naps:** "A short nap can chip away at recent sleep debt."
  - **Repayment:** recent debt clears "with a few consistent nights", but "chronic, long-term
    debt takes weeks of consistency".
  - No decay constant is given.
  - ([Oura blog, Sleep debt](https://ouraring.com/blog/sleep-debt/))
- **Readiness's Sleep balance contributor:**
  - **What it measures:** "assesses the amount of sleep and possible sleep debt over the past two
    weeks compared to your baseline", together with age-based recommendations (it cites AASM 7–9
    h).
  - **Sleep contributor:** compares the last 24 h of sleep, "including confirmed naps", with
    your baseline.
  - **Warm-up:** averages take up to two weeks to learn.
  - ([Oura Support, Readiness
    Contributors](https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors),
    updated 2026-10-07)
- **Activity:** not an input to Oura's sleep need or Sleep Debt in any page read.

### Garmin — Sleep Coach (blog dated 2025-02-28; current manuals)
- **Inputs:** "your age, daily and longer-term activity levels, recent sleep history, naps and
  heart rate variability (HRV)".
- **Age baseline:** about **8 h** for adults under 35, falling with age to about **7.5 h** over
  65.
- **Activity:** a hard workout "can increase the amount of sleep you need", and a low-activity
  day can lower it.
- **Sleep history:** short nights add debt, and extra sleep is banked and lowers the next
  night's need.
- **Naps:** they can lower need. Search excerpts of other regional copies say naps "will never
  increase" need and that the three previous nights "can play a role".
- **Bounds:** the coach "won't ever recommend you get less than seven hours or more than nine
  hours".
- **Warm-up:** none is described. The age figure is always there to fall back on.
- Source for the points above: [Garmin blog, Five factors Sleep Coach
  uses](https://www.garmin.com/en-GB/blog/?p=10566).
- **Current manuals:** the Venu 4 manual lists "sleep and activity history, circadian rhythm,
  HRV status" and naps as inputs. It gives no weights.
  ([Venu 4 manual, Sleep
  Tracking](https://www8.garmin.com/manuals/webhelp/GUID-2CF5620C-E585-4E0A-9CC3-9565533EEE4D/EN-US/GUID-70D41BFB-2BB2-4933-BF95-47FF63140112.html))
- Garmin's blog also says the estimate updates during the day, in 10-minute steps. This comes
  from a search excerpt and was not confirmed on the page read.

### Fitbit
- **Sleep Schedule (2016):** a sleep goal that defaults to **8 h**, or follows "personalized
  recommendations" from your sleep data. It has no published formula and no Sleep Debt.
  ([Google blog, 2016-06-20](https://blog.google/products/fitbit/fitbit-unveils-personalized-sleep-schedule-feature))
- **Personalized Sleep Schedule (Fitbit Labs, 2025):** an opt-in experiment, US only, for adults
  18 and over, on Android.
  - **Inputs:** sleep data plus several daytime surveys on how you feel. These estimate sleep
    need and sleep debt and suggest bed and wake times.
  - **Data:** reportedly needs **at least 5 days** of wear.
  - **Sources:** [9to5Google, 2025-03-17](https://9to5google.com/2025/03/17/fitbit-personalized-sleep-schedule-lab/),
    which links the [Google help
    page](https://support.google.com/googlepixelwatch/answer/14566053#zippy=%2Cpersonalized-sleep-schedule-lab).
    The help page's Labs section could not be read here, so these details are secondary.
  - **Status:** a January 2026 teardown says sleep need and debt metrics for the main app are
    not yet live. Fitbit's current method is unconfirmed.

### Comparison (inference from the above, not a decision)
| | Typical need | Debt look-back | Repayment / decay | Exertion | Naps | New user |
|---|---|---|---|---|---|---|
| WHOOP | learned from own sleep (~28 days cited) | unpublished | unpublished | adds need | subtract | population figures while calibrating |
| Oura | own last 90 days, outliers dropped | 14 days, recent weighted more | "a few consistent nights"; unpublished | not used | count as sleep | Sleep Debt needs 5 Nights in 14 days |
| Garmin | by age (8 h → 7.5 h), adjusted | about 3 nights | banks extra sleep; unpublished | adds or subtracts | subtract, never add | age figure; 7–9 h bounds |
| Fitbit (Labs) | sleep + daytime surveys | unpublished | unpublished | unpublished | unpublished | ~5 days of wear |
| Research | ~8.4 ± ~1 h (young adults); less with age | n/a | exponential; 1 h takes ~4 days; one 10 h night not enough | small effect | n/a | guideline 7–9 h |

## Open / uncertain
- **No vendor publishes a formula.** None gives the debt look-back for WHOOP and Garmin, the
  weighting for Oura, the share repaid per night, or how much extra need a unit of exertion adds.
  Serenix's rules will be its own design, and test values must come from its spec (ADR 0005).
- **WHOOP pages were read only through search excerpts** (HTTP 403). The developer docs were
  read directly, but they show the four parts only in an example and don't define them. The 28-day
  window and the calibration period (2 weeks against about 28 days) conflict between sources.
- **Fitbit's current method is unclear.** The Labs feature is experimental. Its help page section
  couldn't be read, and the main-app sleep need and debt metrics seemed unreleased as of January
  2026.
- **Learning need from free-living sleep is biased.** Kitamura's habitual sleep was about 1 h
  under the need measured under lab conditions. A median of the user's own Time Asleep (as Oura
  does) may learn a chronically short sleeper's habit, not their need. Garmin's 7 h floor and the
  guideline floor of 7 h are one guard against that. This is an inference.
- **Repayment dynamics come from small lab studies** (n = 15 to about 160, mostly young). The
  "4 days per hour" figure is a single study's estimate, and Banks 2010 measured one recovery
  night only.
- **Exertion raising need is vendor practice, not established science.** The meta-analytic
  effects are small and depend on many moderators. Serenix's Load is already a Readiness input,
  so adding it to Sleep Need too would count it twice in Readiness. That is a design point, not a
  finding.
- **Naps:** Serenix doesn't detect Naps (and a Nap never makes a Night), so napping users will
  show more Sleep Debt than they carry. This limitation should be stated in the spec.
- **Age:** need falls with age (NSF 7–8 h for 65 and over; Klerman & Dijk; Garmin). The Profile's
  optional birth year could set the fixed fallback, but no source publishes a curve beyond these
  points.
