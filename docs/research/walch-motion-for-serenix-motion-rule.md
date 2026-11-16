# Can the Walch 2019 sleep-accel nights drive Serenix's motion rule?

**Date:** 2026-11-16 · **Unblocks:** the wayfinder ticket (map [#78](https://github.com/ellismchardy/serenix/issues/78)) "What the accuracy harness measures and
reports": the harness's motion input format and the adapter that turns Walch's raw acceleration
(and the Strap's History Records) into it.

## Answer
- **Yes, but not as the Strap's 2° quaternion turn.** Walch's motion files are raw 3-axis
  acceleration in g, ~50 Hz with irregular phone-clock timestamps and short gaps, and nothing
  else: no gyroscope, no attitude, no quaternion. Serenix's rule needs a per-second turn angle,
  and from an accelerometer only the change in the *direction of gravity* (tilt) can be
  recovered. Turning about the vertical axis is invisible to it.
- **The Strap has no raw acceleration in its History Records.** The per-second `0x12` record
  carries the four floats Serenix treats as an orientation quaternion, plus 9 undecoded bytes
  (`d[32:41]`) that "rise with activity". Neither is a decoded accelerometer reading, and a
  once-per-second record can't hold ~50 Hz samples anyway.
- **The Strap's quaternion can be turned into the same tilt signal**, by rotating the vertical
  into the Strap's frame each second. On the owner's two fixture nights this tilt-only turn
  catches 81–85% of the seconds the full quaternion turn marks active (it never marks one the
  full turn doesn't). Minutes with ≥ 10 active seconds agree on 97.4–98.7% of minutes. Tilt
  flags 17–20% fewer such minutes (44 vs 53, and 24 vs 30). So most of what the rule sees is tilt.
- **Recommendation: derive the same tilt angle on both sides.** Make the harness's motion input
  a per-second "gravity-direction change in degrees" series. Walch's adapter makes it from
  1-second medians of acceleration. The Strap's adapter makes it from the quaternion. Run the
  rule on that, then report separately, on the owner's nights, the gap between the tilt-only
  rule and the shipped quaternion rule (the ~2% minute disagreement above, growing with more
  nights). Don't feed quaternion turn on one side and accelerometer angle on the other as if
  they were one signal.
- **The 2° threshold won't transfer as-is.** The Apple Watch accelerometer's resting noise in
  degrees of tilt per second is unknown and won't match the Strap's (~0.2°, median 0.22° tilt
  in a Sleep Period). The harness should sweep the threshold, or set it per night from that
  night's noise as HDCZA does, and not hard-code 2°.

## Findings

### 1. What Walch's motion files contain
- **Files and format.** One `[subject-id]_acceleration.txt` per subject under `motion/`. Each
  line is a timestamp in seconds since PSG start, then x, y, z acceleration in g. Heart rate is
  `[id]_heartrate.txt` (seconds since PSG start, bpm). Labels are `[id]_labeled_sleep.txt` with
  stage codes 0 wake, 1–3 N1–N3, 5 REM. 31 subjects, 2.2 GB, v1.0.0 published 2019-10-08, ODC-By
  v1.0 ([PhysioNet sleep-accel 1.0.0](https://physionet.org/content/sleep-accel/1.0.0/)). The
  page states neither sampling rate nor epoch length.
- **Rate and timestamps.** The paper says acceleration was "sampled at approximately 50 Hz"
  (20 Hz for the first two subjects, to save battery), from Apple Watch Series 2 and 3
  ([Walch et al. 2019, *Sleep* 42(12):zsz180](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/)).
  The collection app asks Core Motion for raw accelerometer updates at 1/60 s
  (`motionManager.accelerometerUpdateInterval = 1.0/60.0`). It stamps each sample with
  `Date().timeIntervalSince1970` when the handler runs, not with the sensor's own timestamp, and
  uses `startAccelerometerUpdates` only. It reads no `deviceMotion`, gravity, attitude or gyro
  ([ojwalch/sleep_accel](https://github.com/ojwalch/sleep_accel), `SleepAccelerometer WatchKit
  Extension`). So the timestamps are irregular, with delivery jitter, and there is no rotation
  data of any kind.
- **Gaps.** "Short windows of time with missing data", put down to server-side issues, affected
  under 3% of recording time and were filled by interpolation. Recordings where the battery died
  were cropped to the valid stretch ([Walch 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/)).
  The authors' `make_counts.m` reports gaps over 1 s, then resamples to a 50 Hz grid with
  `interp1`
  ([sleep_classifiers `source/make_counts.m`](https://github.com/ojwalch/sleep_classifiers/blob/main/source/make_counts.m),
  repo HEAD `c357a9a`, 2026-10-26). `MotionService.load_raw` removes repeated rows
  ([`motion_service.py`](https://github.com/ojwalch/sleep_classifiers/blob/main/source/preprocessing/motion/motion_service.py)).
- **Which wrist.** Not fixed: the authors note they didn't require the non-dominant wrist
  ([Walch 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/)).
- **How Walch used motion.** Only the **z axis**, band-passed 3–11 Hz, rectified, binned into
  128 levels, maxed per second, and summed per 15 s into activity counts. That is the te
  Lindert / Oakley method via `actant`. Classification is on 30-second PSG epochs
  (`Epoch.DURATION = 30`)
  ([`activity_count_service.py`](https://github.com/ojwalch/sleep_classifiers/blob/main/source/preprocessing/activity_count/activity_count_service.py),
  [`epoch.py`](https://github.com/ojwalch/sleep_classifiers/blob/main/source/preprocessing/epoch.py)).
  The band-pass removes gravity, so Walch's counts carry no orientation. The harness has to work
  from the raw `motion/` files, not from Walch's derived features.
- **Heart rate** comes from HealthKit samples, every ~8–10 s, which the paper interpolates to
  1 Hz ([Walch 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6930135/);
  [sleep_accel `HeartRateHandler.swift`](https://github.com/ojwalch/sleep_accel)). The Strap gives
  HR every second, so the rule's heart-rate wake extension will see a much smoother HR on Walch
  nights.

### 2. A per-second turn angle from raw acceleration
- **The published method is an angle of the gravity vector.** van Hees 2015 takes a rolling
  5-second median of each axis, which leaves mostly gravity. It computes the arm angle
  `atan(a_z / √(a_x² + a_y²))·180/π`, averages it per 5-second epoch, and calls sustained
  inactivity "no change larger than 5° over at least 5 minutes"
  ([van Hees 2015, *PLoS One* 10(11):e0142533](https://pmc.ncbi.nlm.nih.gov/articles/PMC4646630/)).
  HDCZA reuses the same z-angle, takes a 5-minute rolling median of absolute differences between
  successive 5-s values, and sets the threshold to the night's 10th percentile × 15
  ([van Hees 2018, *Sci Rep* 8:12975](https://pmc.ncbi.nlm.nih.gov/articles/PMC6113241/)). In
  the 2015 paper, z is the axis perpendicular to the skin.
- **A per-second version** (an inference, not a published method): take the median of each axis
  over each 1-s bin (~50 samples), normalise it to a unit gravity direction, and use the angle
  between successive seconds' directions. This is the accelerometer counterpart of Serenix's
  `2·acos(|q₁·q₂|)`. The 2-axis direction change catches more than van Hees' 1-axis z-angle. It
  doesn't depend on which device axis faces the skin, so it is the same for Apple Watch and
  Strap without knowing either one's axis layout.
- **What it misses against a full quaternion:**
  1. **Rotation about the vertical (yaw).** A turn about the gravity axis leaves the
     gravity direction in the sensor frame unchanged, so an accelerometer can't see it, for
     example sliding a flat arm across the mattress. A quaternion from gyro fusion includes it.
     This is the gap measured in §4.
  2. **Motion without rotation.** Neither signal sees translation (the arm moving without
     turning). Both see the arm swinging.
  3. **Linear acceleration leaks into the gravity estimate** while the arm moves. The 1-s (or
     van Hees' 5-s) median damps it but doesn't remove it. This tends to *add* apparent tilt
     during movement, so it errs toward "active". That matters little for a sleep/wake rule.
  4. **No sensor fusion.** The Strap's floats may come from on-device fusion with a gyroscope
     (hr-tracker doesn't know). The Watch data has none, so its tilt is noisier at rest. That is
     why the threshold has to be re-set for the Walch nights.

### 3. Does the Strap carry raw acceleration?
- **Not in anything decoded.** Serenix decodes `motion` as four float32 at body offset 33, which
  is `d[41:57]` of the notification. Everything else it decodes is HR, RR, counter, timestamp,
  steps, skin temperature, measurement mode and SpO2
  (`src/SerenixCore/Whoop5HistoryRecordDecoder.swift`).
- **hr-tracker's protocol notes** (`docs/protocol.md`; one Strap, hardware `WG50_r52`, firmware
  `50.38.1.0`; the repo is private, read through `gh` on 2026-11-16) mark `d[41:57]` as "4 ×
  float32 LE, usually near unit norm". They doubt it is an orientation quaternion because 12% of
  records fall outside a norm of 0.9–1.1. `d[32:41]` is unknown: "`d[37]`, `d[38]` rise with
  activity". The rest of `d[75:120]` is mostly constant. No accelerometer, gyroscope or
  IMU field is identified. The `0x1a` variant holds 24 Hz optical (PPG) samples, not motion.
- **A quick look at `d[32:41]`** in the raw History Sync fixture
  (`tests/SerenixCoreTests/Fixtures/HistorySync-2026-10-27.txt`, 1,036 `0x12` records) shows
  `d[32:34]` constant `00 60`. `d[34:36]` as u16 varies (~200 at rest, 2,000–4,000 when moving),
  which looks like an activity magnitude. It has no x/y/z triple shape. One unlabelled scalar a
  second couldn't give a direction anyway.
- **Inside a Sleep Period the quaternion norm is well behaved.** Outside 0.9–1.1 on 0.2% of
  seconds (29–30 Oct, 21:05–03:42 UTC) and 0.6% (28–29 Oct, 21:00–05:00). Across a whole
  24-hour file it is 1.6%. The 12% in hr-tracker's notes is likely daytime.

### 4. Measured on the owner's nights: full quaternion turn vs tilt-only turn
Method: for each second, the full turn is Serenix's `2·acos(|q₁·q₂|)`. The tilt is the angle
between the reference vertical (0,0,1) rotated into the Strap's frame by consecutive
quaternions. Consecutive means at most 2 s apart, as in `MotionMinutes.longestActiveGap`. "Wake
minutes" here means only the ≥ 10-active-second test, not the full `SleepPeriod` rule
(scratch script, not committed). The four possible float orders and conjugations gave numbers
within ±1 point of each other. The first is shown.

| Stretch | Seconds | Median turn: full / tilt | Seconds > 2°: full / tilt | Full-only seconds | Tilt-only seconds | Minutes ≥ 10 active: full / tilt | Minutes agreeing |
|---|---|---|---|---|---|---|---|
| 29–30 Oct Sleep Period, 21:05–03:42 UTC (`Night-2026-10-30.csv`) | 23,818 | 0.28° / 0.22° | 4.29% / 3.48% | 193 of 1,022 (19%) | 0 | 30 / 24 | 98.5% of 397 |
| 28–29 Oct, 21:00–05:00 UTC (`Night-2026-10-29.csv`) | 20,389 | 0.23° / 0.17° | 9.39% / 7.88% | 308 of 1,914 (16%) | 0 | 53 / 44 | 97.4% of 340 |
| Same file, whole 24 h, 12:00–12:00 | 37,598 | 0.62° / 0.47° | 39.2% / 36.2% | 1,128 of 14,733 (8%) | 0 | 336 / 325 | 98.3% of 629 |

- The full-turn figures match the earlier note's 0.28° median and 4.3% over 2° for this
  Sleep Period ([sleep-wake-and-sleep-stages.md](sleep-wake-and-sleep-stages.md)).
- Tilt never exceeds the full turn, as expected: a tilt change is part of the full rotation.
- The disagreement is all in one direction. Tilt sees less, so a tilt-only rule would call
  slightly fewer minutes wake and slightly overstate Time Asleep. That is the same direction
  actigraphy already errs.

### 5. Recommended harness input
1. **Harness motion input:** a per-second series of `(utc or seconds-since-start, tiltDegrees?)`,
   with missing seconds left empty, not interpolated. The Serenix rule already drops turns across
   gaps over 2 s.
2. **Walch adapter:** sort and de-duplicate the samples. Bin them into whole seconds since PSG
   start, take the per-axis median, normalise, and take the angle to the previous second's
   vector. Seconds with no samples stay empty: under 3% of time, per the paper.
3. **Strap adapter:** rotate the vertical by each History Record's quaternion and take the angle
   between successive seconds. This lets the shipped rule and the harness share one code path
   behind a "turn" function.
4. **Report two numbers, not one.** (a) Accuracy against PSG of the tilt-based rule on Walch, at
   each threshold swept. (b) On the owner's nights, how far tilt-based Sleep Periods, Time Asleep
   and Wake Bouts move from quaternion-based ones. That is the transfer gap. Without (b), a Walch
   score says nothing about the shipped rule.
5. **Epochs.** Walch scores 30-s PSG epochs, and Serenix labels minutes. The harness has to
   choose a mapping, for example scoring each 30-s epoch by its Serenix minute. That belongs in
   the harness spec, not here.

## Open / uncertain
- **Is `d[41:57]` really a quaternion, and is its reference z vertical?** hr-tracker doubts it
  (12% off-norm). The tilt calculation above assumes the reference frame's z is up. All four
  float orders and conjugations gave near-identical results, but so might a frame that isn't
  gravity-aligned. Check it on the Strap: lay it still in several orientations and see whether
  the rotated vertical follows gravity.
- **`d[32:41]` is undecoded.** `d[34:36]` looks like an activity magnitude. If it turns out to be
  a per-second motion summary, it could be a third, simpler harness input. Unverified.
- **Apple Watch axis layout and resting tilt noise** were not confirmed: Apple's Core Motion page
  didn't render for fetching. The direction-change method doesn't need the axis layout. The noise
  floor has to be measured from the Walch files themselves, at the threshold sweep.
- **Only two nights, one person, one Strap** back the mismatch numbers in §4. The 97–99% minute
  agreement may not hold on restless nights, and it covers only the ≥ 10-second test, not the
  5-minute median, the HR extension or the Sleep Period choice.
- **Different hardware, different wrists.** Walch's subjects wore a Watch on either wrist. The
  Strap's fit and band differ. A tilt-based rule tuned on Walch may not carry over, which is
  why number (b) in §5 matters.
- **Walch HR is ~0.1 Hz interpolated to 1 Hz.** The rule's heart-rate wake extension (6 bpm
  above a 61-minute median) will behave differently on it than on the Strap's per-second HR.
- **Paper details came through a summariser** (sampling rate, gap share, devices); the code
  facts were read directly from source.
