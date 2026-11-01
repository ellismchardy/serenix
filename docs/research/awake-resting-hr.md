# How should an awake Resting HR be worked out for a Day from 1 Hz wrist data, as distinct from Sleeping HR?

**Date:** 2026-11-01 · **Unblocks:** spec 007 (Sleeping HR and Resting HR): the awake Resting HR method's constants

## Answer
- **Still minute = no steps and few active seconds, with HR present.** Count a minute as still when
  it has at least 30 History Records with heart rate > 0 (the existing `fewestRecordsPerMinute`),
  **0 steps** (the "non-movement" cadence band, 0 steps/min), and fewer active seconds than a wake
  minute (`wakeActiveSeconds` = 10, same 2° turn rule). This stands in for the published gate
  "MET < 1.5" (the sedentary threshold) and Apple's "motion below a threshold". No vendor publishes
  the exact motion number, so the active-second cutoff is Serenix's own constant.
- **Settle for 4 minutes, then average 5.** Drop the first **4 still minutes** of every unbroken
  still run (Speed et al. 2023: 4 min of inactivity gives a reliable HR; Polar asks for 3–5 min
  lying still; Apple's in-app text says "several minutes"). The Day's Resting HR is the **lowest
  mean heart rate over 5 consecutive settled still minutes**. A 5-minute mean is less noisy than
  Speed's single lowest minute, and it is the span Polar's own protocol uses.
- **Raised HR after exercise is handled by the statistic, not a fixed lockout.** Apple warns that
  a seated rest straight after a workout is "sedentary" but still well above resting HR, and it
  solves this by analysing sedentary samples across the whole Day. A lowest-5-minute rule does
  the same: a post-exercise window is rarely the lowest one. No source publishes a lockout
  length. If spec 007 wants one anyway, it would be Serenix's own constant (see Open).
- **Keep sleep out by Day boundary and by sleep label.** Exclude every minute inside the Night's
  Sleep Period. Because Naps are not detected, also exclude minutes that the existing sleep
  classifier would label as sleep (an unbroken run of `shortestSleepRun` = 7 sleep minutes)
  anywhere in the Day. Apple's Resting HR excludes sleep. Fitbit's and Garmin's include it, so
  theirs are not awake values. If a Nap slips through, it pulls the value down by up to the
  day/night gap (~4 bpm on average).
- **Minimum data: 8 hours worn while awake**, plus at least one 5-minute settled still window.
  Otherwise the Day has no Resting HR (Speed et al. 2023 used ≥ 8 h daytime wear; Fitbit's
  cohort study used ≥ 20 h/day, but that count includes sleep). On "about 10–20% lower":
  that holds for **mean** awake HR against **mean** asleep HR (about 12–15%). Awake *resting* HR
  against the night's lowest is a smaller gap: about **4 bpm (~7%)**.

## Findings

### Vendor definitions
- **Apple (HealthKit, current docs, read 2026-11-01).** `restingHeartRate` is "an estimation of the
  user's lowest heart rate during periods of rest". It is distinct from a sedentary heart-rate
  sample: "if the user finishes a high-intensity workout, and then sits down to rest, the next
  heart rate sample may be marked as a sedentary sample, but it is still much higher than the
  user's actual resting heart rate". The system "estimates the resting heart rate by analyzing
  sedentary heart rate samples throughout the day" and may replace earlier estimates as the day
  goes on ([Apple Developer: restingHeartRate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate)).
- **Apple Health app text** (as quoted in a [Jan 2026 blog post](https://leancrew.com/all-this/2026/01/resting-heart-rate-and-the-apple-watch/),
  a lead rather than a primary source): an average "measured when you've been inactive or
  relaxed" for several minutes. It states that "Resting heart rate does not include your heart rate while you're
  asleep."
- **Apple patent US 12,239,427 B2** (filed 2023-06-16, priority 2017-06-04). Heart rate is
  labelled "sedentary" when the user's motion is "below a threshold" (no value given). An at-rest
  state is described as "several minutes with no gross motion". A "physiological baseline resting
  heartrate, using intraday measurements" is estimated from sedentary-context values and "updated
  throughout the day" ([Google Patents](https://patents.google.com/patent/US12239427)). No
  numbers for the threshold, the statistic or the post-workout handling.
- **Fitbit / Google.** The formula is proprietary. Fitbit's 92,457-person cohort study says Fitbit's
  daily RHR is "calculated by a proprietary formula", is "primarily calculated during periods of sleep",
  and was treated as valid only if the device was worn ≥ 20 h that day
  ([Quer et al., PLOS ONE 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7001906/)). So Fitbit's RHR
  is mostly a sleeping value, not an awake one.
- **Garmin.** The official article was not reachable. Forum posts quote it as "the lowest 30 minute
  average in a 24 hour period", which can fall in sleep
  ([Garmin forum](https://forums.garmin.com/sports-fitness/healthandwellness/f/vivoactive-4-series/369768/resting-heart-rate-average)).
  This is a lead only.
- **WHOOP.** Measures RHR "each night", as a dynamic average weighted towards the last slow-wave
  sleep period ([WHOOP: normal resting heart rate](https://www.whoop.com/thelocker/normal-resting-heart-rate-improve-fitness),
  per search snippet; the page returned 403). This is a sleeping value. In Serenix terms it is SHR.
- **Polar** (support page, read 2026-11-01). Lows from continuous HR "are NOT the same as your resting
  heart rate". Polar's protocol is to measure on waking, lie down, wait about a minute, then lie
  still for 3–5 min and take the lowest HR, repeated over consecutive mornings and averaged
  ([Polar support](https://support.polar.com/en/support/the_what_and_how_of_polars_continuous_heart_rate)).
- **Oura.** Its RHR is the night's lowest, sampled every 10 min overnight. Daytime HR is a
  separate 1-min-every-5-min feature ([Oura help](https://support.ouraring.com/hc/en-us/articles/360025588793),
  via search snippet).

### Published algorithms with numbers
- **Speed et al., "Measure by measure: Resting heart rate across the 24-hour cycle", PLOS Digital
  Health 2(4):e0000236, 2023** (Google/Fitbit authors, Fitbit Charge 4, 60-s epochs).
  - Inactive = estimated MET < 1.5.
  - Daytime and night-time RHR = the lowest HR "when still" in each part. Night = the tracker's
    primary sleep period.
  - "a minimum rest time of 4 minutes provides a reliable measurement of HR during inactivity".
  - Valid only with ≥ 8 h daytime wear and ≥ 3 h night wear.
  - Mean daytime RHR was 54.5 bpm, night-time 50.5 bpm. The paired difference was **+3.9 ± 3.8 bpm**
    (n ≈ 19k). 53% of 24-h minima fell between 03:00 and 07:00.
  - Naps are not mentioned ([PMC10146540](https://pmc.ncbi.nlm.nih.gov/articles/PMC10146540)).
- **Vital Connect patent US 10,582,862** ("basal heart rate", filed 2015-04-22).
  - Activity is the signal magnitude area of 1-s acceleration windows. Inactive when the
    normalised activity is < 0.1 (example value, "learned... from clinical data").
  - HR from active periods is excluded.
  - Basal HR is the **16th percentile** of a **30-min FIFO buffer** at 1 Hz (1,800 values), or
    mean − 1.0 × SD ([Google Patents](https://patents.google.com/patent/US10582862)).
- **Microsoft patent US 10,932,715 B2** (filed 2018, priority 2015-06-15).
  - Samples 1–2 min every ~10 min, and scores each sample's quality (motion, orientation; HR between
    35 and 85 bpm).
  - Aggregates usable samples by mean, and blends a new low as 40% new + 60% current minimum.
  - The percentage of usable samples required is not stated
    ([Google Patents](https://patents.google.com/patent/US10932715)).

### What "still" means in activity terms
- Sedentary behaviour is "any waking behavior characterized by an energy expenditure ≤1.5 METs,
  while in a sitting, reclining or lying posture"
  ([SBRN Terminology Consensus, Tremblay et al., IJBNPA 2017](https://pmc.ncbi.nlm.nih.gov/articles/PMC5466781/)).
- Cadence bands: 0 steps/min = "non-movement", 1–19 = "incidental movement", and ≥ 100 steps/min
  ≈ moderate intensity. US adults spend ~4.8 h/day of wear at 0 steps/min (Tudor-Locke et al.,
  NHANES 2005–06, via [Bath research portal](https://researchportal.bath.ac.uk/en/publications/patterns-of-adult-stepping-cadence-in-the-2005-2006-nhanes/)
  and search snippets; abstracts only).

### Exercise and raised HR
- In the first minutes after stopping, HR "does not return to baseline" within 6 min even after
  low-intensity exercise, and the curve plateaus ~4 min after stopping
  ([NCT05561608 protocol](https://cdn.clinicaltrials.gov/large-docs/08/NCT05561608/Prot_SAP_000.pdf),
  via search snippet).
- Full cardiac autonomic recovery takes up to 24 h after low-intensity aerobic exercise, 24–48 h
  after threshold-intensity, and ≥ 48 h after high-intensity exercise
  ([Stanley, Peake & Buchheit, Sports Med 2013](https://pubmed.ncbi.nlm.nih.gov/23912805)).
  This is too long to lock out. It is part of what a Day's Resting HR is meant to show.

### Clinical measurement
- The ESH consensus on elevated heart rate does not fix a rest period. It asks studies to report
  the rest period, posture, duration and number of readings
  ([Palatini et al., J Hypertens 34(5):813–821, 2016](https://research.regionh.dk/en/publications/management-of-the-hypertensive-patient-with-elevated-heart-rate-s/),
  abstract).
- Posture matters. Seated HR ran ~12% above supine HR in one Brazilian thesis
  ([UFJF](https://repositorio.ufjf.br/jspui/handle/ufjf/4523); low weight). Daytime still minutes
  mix sitting and lying, so an awake Resting HR is posture-mixed in a way a Sleeping HR is not.

### Day versus night (the "10–20% lower" check)
- **Mean awake vs mean asleep HR (ambulatory monitoring):**
  - 78 ± 12 → 67 ± 10 bpm, a dip of 12.5 ± 8.6%, in 76 kidney-transplant patients with diary-defined
    periods ([Gluskin … Ben-Dov, BMC Nephrol 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6661097/)).
  - 72–74 → 63 bpm (~13–15%) in 70 older adults
    ([Okada et al., Am J Physiol Heart Circ Physiol 2013](https://pmc.ncbi.nlm.nih.gov/articles/PMC3761347/)).
- Non-dipping of HR is conventionally a < 10% fall, computed as (day − night) / day
  ([Akhtar et al., Front Neurol 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8637909)).
- **Lowest awake-still vs lowest asleep:** +3.9 bpm, about 7% of the 54.5 bpm daytime value
  ([Speed et al. 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC10146540)).
- So "10–20% lower" is right for average HR. Comparing Resting HR with Sleeping HR (both lowest
  sustained values) should expect roughly **3–8 bpm**, with a wide spread (SD 3.8 bpm).

### Naps
- No vendor source says how naps are kept out of an awake RHR. Apple excludes sleep but doesn't
  say how naps are found. Fitbit and Garmin include sleep on purpose.
- NREM sleep in a 50–80 min afternoon nap lengthens RR intervals significantly versus pre-nap
  wake (p ≤ 0.016) ([AlQatari et al., Nat Sci Sleep 12:661–669, 2020](https://www.dovepress.com/changes-in-heart-rate-variability-and-baroreflex-sensitivity-during-da-peer-reviewed-article-NSS)).
  Night sleep has a lower HR than nap sleep at the same stage (Univ. of Kentucky nap-vs-night
  study, abstract via search). So a missed Nap biases the Day's Resting HR **down**, by at most
  about the day/night gap above.

## Open / uncertain
- **Mapping to our turn rate.** No source gives a motion number we can carry over: Apple
  says "below a threshold", Vital Connect gives a normalised 0.1, and Speed uses MET < 1.5. "0
  steps and < 10 active seconds (at 2°/s) in the minute" is Serenix's own mapping. It should be
  checked on fixture days: does desk work (typing, phone use) fall inside it, and does it still
  leave enough still minutes?
- **Steps resolution.** The Strap's step count is a running total. Whether it counts single
  steps reliably enough for a "0 steps in the minute" rule is unverified.
- **Post-exercise lockout.** No source sets one. If the lowest-5-minute rule still picks a
  post-workout window on fixture days, a lockout (for example, 30 min after any minute at ≥ 100
  steps/min) would be Serenix's own, unsourced constant.
- **Statistic.** The choices in use are: lowest single minute (Speed), 16th percentile of 30 min
  (Vital Connect), lowest 30-min average (Garmin, unverified), and mean of good samples blended
  into a running minimum (Microsoft). "Lowest 5-minute mean" is a judgement among these, not a
  published standard.
- **Nap exclusion.** Reusing the sleep classifier's sleep-minute labels outside the Sleep Period
  is untested. A quiet seated awake stretch might be labelled sleep, and that would remove good
  still minutes. A Nap shorter than 7 minutes would get through either way.
- **Day vs Sleep Period overlap.** A Day (midnight to midnight) contains the tail of one Sleep
  Period and maybe the start of the next. Both are excluded, so a late riser has fewer waking
  hours, which counts towards the 8-hour minimum.
- **Sources not read in full:** Garmin's official RHR article (unreachable), WHOOP's page (403),
  Fitbit's help article (not found on the current Google help site), and the medRxiv Fitbit
  Charge HR validation preprint (403).
