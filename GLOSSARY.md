# Glossary — Serenix

> The project's shared (ubiquitous) language. Code, specs, tests, and conversation all use
> these terms, so one precise word replaces a paragraph of explanation. Filled in by /kickoff
> and kept current by the `domain-modeling` skill. Definitions only — no implementation details.

Personal wellness tracking from a wearable's raw sensor data: sleep, overnight physiology, and
daily scores, computed on the user's phone without the wearable vendor's subscription.

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
The Strap's sequence number for a History Record, one higher for each record it stores. It
identifies a History Record.
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

**Night**:
The dated record of one night's sleep: a Sleep Period together with the Nightly Metrics and
scores drawn from it, dated by the local calendar date of its Final Wake.
_Avoid_: sleep, cycle

**Nap**:
A stretch of sleep outside the Sleep Period. A Nap never makes a Night.

**Day**:
One local calendar day, midnight to midnight.
_Avoid_: cycle

## Metrics and scores

**Baseline**:
The user's typical HRV and Resting HR, taken over their most recent Nights.
_Avoid_: norm, average (when the personal reference is meant)

**Nightly Metrics**:
The physiological measures taken over one Sleep Period: Resting HR, HRV, respiratory rate, skin
temperature, and SpO2.
_Avoid_: vitals, biometrics

**Resting HR**:
The user's lowest sustained heart rate during a Sleep Period.
_Avoid_: RHR (in prose; fine as an abbreviation in code)

**HRV**:
Heart-rate variability during a Sleep Period, expressed as RMSSD in milliseconds.

**Sleep Score**:
Serenix's rating of how well the user slept in one Sleep Period.
_Avoid_: sleep performance, sleep quality

**Calibrating**:
The state of Readiness while too few Nights exist to form a Baseline.

**Readiness**:
Serenix's rating of how prepared the user's body is for exertion, derived from Nightly Metrics
relative to their own Baseline.
_Avoid_: recovery (WHOOP's term)

**Load**:
Serenix's measure of how much cardiovascular exertion the user accumulated over a Day.
_Avoid_: strain (WHOOP's term), effort, exertion score

**Stress**:
Serenix's measure of physiological stress through a Day.
