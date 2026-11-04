# Glossary — Serenix

> The project's shared (ubiquitous) language. Code, specs, tests, and conversation all use
> these terms, so one precise word replaces a paragraph of explanation. Filled in by /kickoff
> and kept current by the `domain-modeling` skill. Definitions only — no implementation details.

Personal wellness tracking from a wearable's raw sensor data: sleep, overnight physiology, and
daily scores, computed on the user's phone without the wearable vendor's subscription.

## The user

**Profile**:
The user's name, and optionally their birth year, sex and Max HR, kept only on the phone, used to
address them and to work out Load and their Usual Need.
_Avoid_: account, user account, login

## Devices and data

**Strap**:
The wrist-worn Whoop band the user owns (a Whoop 5.0 in v1), treated as a sensor that stores
raw readings.
_Avoid_: band, device, tracker, wearable (when the Whoop specifically is meant)

**History Record**:
One second of raw readings stored on the Strap: heart rate, RR intervals, motion, skin
temperature, steps, and (during an SpO2 Window) an SpO2 reading.
_Avoid_: sample, data point, packet

**History Sync**:
The transfer of every History Record the Strap holds that is newer than the last acknowledged
one, from the Strap to the phone.
_Avoid_: download, backfill, import

**SpO2 Window**:
A short period, during sleep, in which the Strap measures blood-oxygen saturation and writes
readings into its History Records.

**Record Counter**:
The Strap's sequence number for a History Record, one higher for each record it stores. Together
with the record's timestamp it identifies a History Record: after a reboot the Strap can reuse
a Record Counter for a new record.
_Avoid_: index, record ID

**Batch**:
A group of History Records the Strap sends together during a History Sync, ending with a Sync
Cursor.
_Avoid_: chunk, page, burst

**Sync Cursor**:
An opaque position in the Strap's storage, given by the Strap at the end of each Batch. Echoing
it back acknowledges the Batch, and the Strap then never sends those History Records again.
The Strap keeps it; the phone never stores or computes it.

**Frame**:
One message exchanged with the Strap: a command, a reply, or data.
_Avoid_: packet, message

**Sync Log**:
The record of every Frame exchanged with the Strap, in order, with direction and time. Kept on
the phone and shared only when the user chooses to.
_Avoid_: debug log, trace

**Live HR**:
The user's heart rate as the Strap measures it right now, streamed only while it is on screen.
Never stored, and never a History Record.
_Avoid_: realtime HR, current HR, streaming HR

## Sleep

**Sleep Period**:
The main stretch of a night from Sleep Onset to Final Wake, including brief wake bouts inside
it.
_Avoid_: sleep session

**Sleep Onset**:
The moment the user first falls asleep within a Sleep Period.

**Final Wake**:
The moment the user last wakes at the end of a Sleep Period.

**Time in Bed**:
The span around a Sleep Period during which the user is lying down but not up and about.

**Time Asleep**:
The part of a Sleep Period spent asleep: from Sleep Onset to Final Wake, minus the Wake Bouts
inside it.
_Avoid_: sleep duration, total sleep

**Wake Bout**:
One unbroken stretch of wake inside a Sleep Period, between Sleep Onset and Final Wake.
_Avoid_: awakening, interruption, disturbance

**Heart Rate Trace**:
The user's heart rate through one Night's Time in Bed, in 5-minute steps, kept with the Night.
_Avoid_: overnight HR, HR series, HR graph

**Usual Need**:
The Time Asleep the user needs on a night with no Sleep Debt to repay.
_Avoid_: typical need, base need, sleep baseline

**Sleep Need**:
How much Time Asleep the user needs on a given night: their Usual Need, plus extra to repay
Sleep Debt.
_Avoid_: sleep goal, sleep target

**Sleep Debt**:
How far the user's Time Asleep has fallen short of their Usual Need over recent Nights, added
up, with Nights whose Time Asleep exceeds their Usual Need paying the shortfall back.
_Avoid_: sleep deficit, sleep owed

**Night**:
The dated record of one night's sleep: a Sleep Period together with the Nightly Metrics and
scores drawn from it, dated by the local calendar date of its Final Wake.
_Avoid_: sleep, cycle

**Night window**:
The stretch from local noon on one Day to local noon on the next, in which Serenix looks for one
Night. Its Night is dated one of those two Days.
_Avoid_: sleep window, night range

**Nap**:
A stretch of sleep outside the Sleep Period. A Nap never makes a Night.

**Day**:
One local calendar day, midnight to midnight.
_Avoid_: cycle

## Metrics and scores

**Baseline**:
The user's typical Sleeping HR, HRV, respiratory rate and skin temperature, and the Spread of
each, taken over their most recent Nights. It also holds their typical Load, taken over their
most recent Days. SpO2 has no Baseline.
_Avoid_: norm, average, usual (alone, when the Baseline is meant)

**Spread**:
How much one Nightly Metric usually varies from Night to Night for the user; part of that
metric's Baseline.
_Avoid_: variability (clashes with HRV), SD, deviation

**Zone**:
Where one Nightly Metric sits against its Baseline (or, for SpO2, against fixed levels): In
range, Watch or Out of range.
_Avoid_: status, colour, traffic light

**Nightly Metrics**:
The physiological measures taken over one Sleep Period: Sleeping HR, HRV, respiratory rate, skin
temperature, and SpO2.
_Avoid_: vitals, biometrics

**Sleeping HR**:
The user's lowest sustained heart rate during a Sleep Period. Abbreviated SHR in code and where
space is tight.
_Avoid_: overnight HR, sleep HR, nocturnal HR, Resting HR (when sleep is meant)

**Resting HR**:
The user's lowest sustained heart rate on a Day while awake and still, outside the Sleep Period.
Abbreviated RHR in code and where space is tight.
_Avoid_: awake HR, daytime HR

**Max HR**:
The highest heart rate the user can reach: estimated from their age unless they enter it.
_Avoid_: HRmax (in prose), peak HR

**HRV**:
Heart-rate variability during a Sleep Period, expressed as RMSSD in milliseconds.

**Sleep Score**:
Serenix's rating of how well the user slept in one Sleep Period.
_Avoid_: sleep performance, sleep quality

**Sleep Sufficiency**:
The part of Sleep Score that rates how much of the user's Sleep Need their Time Asleep met.
_Avoid_: hours vs needed, duration score

**Sleep Efficiency**:
The part of Sleep Score that rates the share of the Sleep Period the user spent asleep. Unlike
the common measure of the same name, it leaves out Time in Bed outside the Sleep Period.
_Avoid_: continuity, restfulness

**Sleep Consistency**:
The part of Sleep Score that rates how close the user's Sleep Onset and Final Wake came to the
times they fell asleep and woke on recent Nights.
_Avoid_: regularity, sleep timing

**Calibrating**:
The state of Readiness while too few Nights exist to form an HRV or Sleeping HR Baseline.

**Readiness**:
Serenix's rating of how prepared the user's body is for exertion, from their HRV and Sleeping HR
against Baseline, their Time Asleep, and the previous Day's Load.
_Avoid_: recovery (WHOOP's term)

**Load**:
Serenix's measure of how much cardiovascular exertion the user accumulated over a Day.
_Avoid_: strain (WHOOP's term), effort, exertion score

**HR Zone**:
One of five bands of heart rate by share of Max HR, from HR Zone 1 (50–60%) to HR Zone 5
(90–100%); heart rate under 50% is in no HR Zone. Always "HR Zone" in full, never bare "Zone",
which means a Nightly Metric against its Baseline.
_Avoid_: heart rate zone (in code), training zone, Zone (alone)

**Stress**:
Serenix's measure of physiological stress through a Day.

## Body

**Weigh-in**:
One reading of the user's body weight on a Day. When a Day has several, the lowest counts.
_Avoid_: weight entry, measurement

**Trend Weight**:
The user's body weight with the day-to-day swings of water and food smoothed out of their
Weigh-ins.
_Avoid_: moving average, smoothed weight, true weight

**Weight Goal**:
The weight the user is working toward: a Start Weight on a start date and a Goal Weight. A
Weight Goal loses, gains or holds weight; one that loses or gains has a Pace, and one that holds
has a band around its Goal Weight instead.
_Avoid_: target, plan

**Start Weight**:
The Trend Weight a Weight Goal counts progress from.

**Goal Weight**:
The weight a Weight Goal aims to reach.

**Pace**:
The change in weight per week a Weight Goal plans for, whether the user chose it as a rate or as
a date to reach Goal Weight by.
_Avoid_: speed, target rate

**Weekly Rate**:
How fast Trend Weight is actually changing, per week.
_Avoid_: speed, velocity

**Milestone**:
A mark on the way from Start Weight to Goal Weight, passed when Trend Weight reaches it.
_Avoid_: checkpoint

**Intake**:
The calories and macros the user logs as eaten on a Day.
_Avoid_: consumption, food log total

**Complete Day**:
A Day the user marks as having all of its Intake logged.
_Avoid_: closed day, finished log

**Calories Burned**:
Serenix's estimate of the energy the user spent on a Day, from their heart rate and Load.
_Avoid_: active energy, TDEE

**Expenditure**:
Serenix's estimate of the energy the user spends per day, worked out from their Intake on
Complete Days and the change in their Trend Weight.
_Avoid_: TDEE, maintenance, metabolism

**Calorie Target**:
The Intake the user aims for each Day.
_Avoid_: budget, calorie goal

**Deficit Check**:
Serenix's watch for HRV and Sleeping HR worsening against Baseline while the user eats below
their Expenditure.
_Avoid_: recovery guard (WHOOP's term), overreaching alert

**Diet Break**:
A planned stretch of eating at Expenditure in the middle of a Weight Goal that loses weight.
_Avoid_: refeed (a shorter thing), maintenance phase

**Check-in**:
What the user logs about one Day's habits and how they felt: Water, Caffeine, Alcohol, Mood and
Motivation.
_Avoid_: journal (WHOOP's term), tags, diary

**Alcohol**:
The alcohol the user drank on a Day, kept as grams of ethanol and shown in the units of their
country.
_Avoid_: drinks (as a measure)

**Habit Link**:
An association Serenix finds between a Check-in habit and a Nightly Metric or score, with no
claim that one causes the other.
_Avoid_: correlation, insight, discovery

**BP Reading**:
One measurement of the user's systolic and diastolic blood pressure, with their pulse.
_Avoid_: BP entry, measurement

**BP Session**:
Two or more BP Readings taken a minute apart at one sitting, averaged.

**BP Category**:
Where a BP Session's average, or a single very high BP Reading, sits: Normal, Elevated, High
stage 1, High stage 2 or Very high.
_Avoid_: Zone (a Nightly Metric against its Baseline), status
