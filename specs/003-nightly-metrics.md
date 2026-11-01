# 003 — Nightly Metrics

**Status:** built
**Last updated:** 2026-11-01 (Night rebuilds added during the build)
**Issue:** https://github.com/ellismchardy/serenix/issues/12 (wayfinder map)

## Problem
History Sync (spec 001) puts the Strap's History Records on the phone, and the Today screen
(spec 002) has a place for every Night value, but nothing turns one into the other. The screen
can only show sample Nights. The methods already exist and have been checked against the
owner's real nights in `hr-tracker`; they just aren't in the app.

## Goal
After a History Sync, each night the user slept with the Strap on becomes a Night with its Sleep
Period (Sleep Onset, Final Wake, Time in Bed, Time Asleep) and its Nightly Metrics (Resting HR,
HRV, respiratory rate, skin temperature, SpO2), worked out on the phone with hr-tracker's methods,
unchanged.

## User stories
1. As a Strap owner, I want last night's Time Asleep and Nightly Metrics to appear after the
   morning sync, so that the Today screen shows my real night instead of sample data.
2. As a Strap owner who opens the app at 3am, I want whatever has been recorded so far to show,
   and the full Night once I sync in the morning, so that an early look is never stuck.
3. As a Strap owner who didn't wear the Strap one night, I want that Day to show "No Night
   recorded", not a Night made from a few stray minutes.
4. As a Strap owner on a night with no SpO2 Window, or too little RR data, I want the missing
   Nightly Metric shown as "—", not a made-up value.
5. As the developer, I want the app's numbers to match hr-tracker's on the same History Records,
   so that every method checked there carries over without a second round of checking.

## Behavior
**Which records make a Night.** History Records are grouped into **night windows**: local noon
to the next local noon. Each window gives at most one Night: the Sleep Period with the most
sleep minutes inside it. The Night is dated by the local date of its Final Wake (GLOSSARY). If
two windows give Nights with the same date, the one with more Time Asleep is kept (on a tie, the one that ends first). No Sleep
Period in a window means no Night from it. Naps never make a Night, and sleep that crosses
local noon (e.g. a night shift) is not handled.

**Sleep Period.** Exactly `hr-tracker/tools/sleep.py` (method table in
`hr-tracker/docs/protocol.md#sleep-and-wake`), with the same constants:
- **Minutes.** Records are grouped by UTC minute. A minute with fewer than 30 records has no
  data. A second is *active* when the Strap turned more than 2° since the record before (from
  the motion quaternion, normalised; only when the records are 1–2 s apart).
- **Wake minutes.** ≥ 10 active seconds, or a median of ≥ 6 over the 5 minutes centred on it.
  A wake bout then runs on while the minute's mean HR stays ≥ 6 bpm above the 61-minute rolling
  median, for up to 10 extra minutes. Every other minute with data is a sleep minute.
- **Sleep Period.** Runs of ≥ 7 sleep minutes, merged while the wake between them is under 60
  minutes and has no minute without data. The period with the most sleep minutes wins.
- **Sleep Onset** is the start of its first minute; **Final Wake** is the end of its last.
  **Time Asleep** is its sleep minutes. **Time in Bed** widens the period outward until 3
  minutes in a row with ≥ 30 active seconds, or a minute without data.

**Nightly Metrics.** Exactly `hr-tracker/tools/metrics.py`, over the records from Sleep Onset to
Final Wake whose heart rate is above 0:
- **Resting HR:** the lowest 30-minute mean of heart rate, trying a start every 60th record.
- **HRV:** RMSSD over every RR interval in order, keeping 600–1,600 ms and successive
  differences under 200 ms.
- **Respiratory rate:** per 5-minute window with ≥ 200 kept RR intervals, the spectral peak at
  0.12–0.4 Hz of the RR tachogram (linearly resampled at 4 Hz, Hann window), in breaths a
  minute; the Night's value is the mean of the windows.
- **Skin temperature:** the mean of every record's skin temperature.
- **SpO2:** records in an SpO2 Window are grouped into windows (a gap of more than 5 s starts a
  new one); each window's value is the median of its readings from 85 to 100; the Night's value
  is the mean of the windows that have one.

The port keeps hr-tracker's quirks so the numbers match: minute means include heart rate 0,
the Resting HR search steps by records rather than seconds, and skin temperature includes the
first minutes while the Strap warms up. Changing any of them is a later change to both repos.

**Missing values.** A Nightly Metric is missing, and shows "—" (spec 002), when its method has
nothing to work on: Resting HR when the Sleep Period has under 30 minutes of records, HRV when
no RR pair survives the filter, respiratory rate when no 5-minute window has 200 beats, skin
temperature when no record has one, SpO2 when no SpO2 Window has a reading from 85 to 100. One
missing metric never stops the others or the Night.

**When.** Nights are worked out again date by date. A night window from noon on one Day to noon
on the next gives a Night dated one of those two Days, so each night window a sync's History
Records fall in queues both its dates. A date is worked out from the two night windows that can
give it (noon the Day before to noon the Day after) and its stored Night replaced, or removed if
there's no longer one. This includes a sync in the middle of the night: the Night it makes is
replaced by the next sync's. Dates are queued as each Batch is stored, kept on the phone, and
worked out after the sync ends or, if iOS ended Serenix first, at the next launch. History
Records are pruned after 30 days (docs/architecture.md), so a date whose History Records start
more than 30 days ago is never worked out again and its Night stays as it is; nor is a date
whose History Records start in the future (a Strap clock that's wrong). Both are checked when a
date is queued and again when it's worked out. Nights are kept forever.

**Sample Nights.** Debug's "Show sample Nights" switch and the sample Nights it shows are
removed from the app: the Today screen shows only real Nights.

## Design decisions
- **`SerenixCore`: Nights from History Records.** Given History Records and a time zone, it
  returns the Nights they make, one per night window that has a Sleep Period (one per date).
  Inside it, the Sleep Period finder and each Nightly Metric are separate pure functions with
  their constants named and commented with their unit and their source in hr-tracker
  (docs/conventions.md). It never reads the clock.
- **`SerenixCore`: Night rebuilds.** Given the times of History Records a sync stored, the
  current time and a time zone, it returns the dates to work out again, oldest first, each with
  the stretch of History Records to read. Each rebuild can say whether it's still due at a given
  time (the 30-day and future rules). Added during the build, when deciding which dates to redo
  turned out to be logic the shell shouldn't hold.
- **`Night`** keeps its existing fields; this spec fills Sleep Onset, Final Wake, Time in Bed,
  Time Asleep and the five Nightly Metrics. Sleep Score and Readiness stay missing until their
  specs ship.
- **Shell:** as each Batch is stored it asks Night rebuilds for the dates to queue and keeps the
  queue on the phone. After the sync (and at launch) it works through the queue one date at a
  time, off the main thread: it reads that date's History Records from the store, calls Nights
  from History Records, and saves the Night for that date in SwiftData (one per date), so at most
  two night windows are in memory. A date that fails goes to the back of the queue. The Today
  screen reads stored Nights.
- Follows ADR 0002 (logic in `SerenixCore`). No new ADR: porting a checked method is easy to
  change later.

## Seams under test
- **Nights from History Records (`SerenixCore`)**, fed the fixture night and hand-built History
  Records with a fixed time zone. It catches the whole Sleep Period method, all five Nightly
  Metrics, night windows, dating by Final Wake, two windows with one date, missing metrics and
  "no Sleep Period, no Night".
- **Night rebuilds (`SerenixCore`)**, fed hand-picked record times and a fixed `now` and time
  zone. It catches which dates each night window queues, the stretch read for each, repeats and
  order, the 30-day and future rules, and windows across a clock change.

Both miss when the rebuild runs, the queue kept on the phone, storing and replacing Nights,
pruning, and the Today screen showing them, which are checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Expected values are hr-tracker's output on the same records, committed as literals.

- [x] The 29–30 Oct 2026 fixture night (Europe/London) makes exactly one Night, dated 30 Oct,
      with Sleep Onset 21:05, Final Wake 03:42, Time in Bed 20:57–04:00 and Time Asleep 5h52.
- [x] On that Night: Resting HR 48.1 bpm, HRV 85.4 ms, respiratory rate 12.2 br/min, skin
      temperature 32.59 °C and SpO2 98.6%, each within ±0.05 of hr-tracker's unrounded value.
- [x] The same records in a different order, or with duplicate History Records, give the same
      Night.
- [x] Records split across two night windows give one Night per window that has a Sleep Period,
      each dated by its Final Wake's local date.
- [x] Two windows whose Nights share a date give one Night: the one with more Time Asleep.
- [x] A window whose longest run of sleep minutes is 6 makes no Night; 7 makes one.
- [x] A window with no records, or only minutes with fewer than 30 records, makes no Night.
- [x] The fixture night with every SpO2 Window removed has SpO2 missing and the other four
      Nightly Metrics unchanged.
- [x] The fixture night with every RR interval removed has HRV and respiratory rate missing and
      Resting HR, skin temperature and SpO2 unchanged.
- [x] Two sleep runs 59 minutes of wake apart make one Sleep Period; 60 minutes apart make two,
      and the one with more sleep minutes is the Night's.
- [x] Night rebuilds: History Records at 01:00 and 07:00 on 15 Nov 2026 (Europe/London) queue
      14 Nov (reading 13 Nov 12:00 to 15 Nov 12:00) and 15 Nov (14 Nov 12:00 to 16 Nov 12:00);
      adding one at 14:00 also queues 16 Nov; repeats and order change nothing; no times queue
      nothing.
- [x] Night rebuilds: with now 30 Nov 2026 12:00, a record at 31 Oct 13:00 queues only 1 Nov
      (its History Records start exactly 30 days earlier); 31 Oct and a 1970 time are skipped. A
      queued 1 Nov is no longer due one minute after 30 Nov 12:00.
- [x] Night rebuilds: with now 15 Nov 2026 11:00, a record at 16 Nov 01:00 queues 15 Nov but not
      16 Nov (its History Records start after now).
- [x] Night rebuilds: a record at 28 Mar 2027 03:00 UTC (the morning the clocks go forward)
      queues 28 Mar reading 27 Mar 12:00 UTC to 29 Mar 11:00 UTC.
- [x] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [x] On the phone (by hand): after a morning sync the Today screen shows last night's Time
      Asleep, Sleep Onset → Final Wake and all five Nightly Metrics; they match hr-tracker run on
      the same night's Sync Log within the tolerance above.
- [x] On the phone (by hand): syncing again later the same morning leaves the Night the same;
      a sync at 3am shows a partial Night that the morning sync replaces.
- [x] On the phone (by hand): closing Serenix from the app switcher in the middle of a morning
      sync, then opening it again, still shows last night's Night once that sync finishes.
- [x] On the phone (by hand): Debug has no "Show sample Nights" switch, and a Day without a
      Night shows "No Night recorded".

## Non-goals (explicitly out of scope)
- Changing any hr-tracker method or constant, including its quirks.
- Sleep stages (not planned), Naps, sleep that crosses local noon, and wake bouts shown to the
  user.
- Sleep Score, Sleep Need, Sleep Debt, Readiness, Load and Zone cut-offs: each its own spec
  (wayfinder map, issue 12).
- Baseline changes: spec 002's Baseline applies to the real Nights as it is.
- Writing to Apple Health.
- Working out a Night while the app is closed (a sync that has started still finishes, ADR 0006).

## Open questions
- **Fixture size.** One full night window is about 49,000 History Records (about 3 MB as CSV),
  untrimmed because trimming changes the Sleep Period. Assumption: commit it as one CSV with the
  fields the methods read; revisit if it slows `swift test` noticeably.
- **Night window in daylight-saving changes.** Local noon to local noon is 23 or 25 hours on a
  clock change. Assumption: fine, since nights don't cross noon.

## Notes
- Reference implementation: `hr-tracker/tools/sleep.py` and `tools/metrics.py`; their methods
  and the two reference nights are in `hr-tracker/docs/protocol.md` (Sleep metrics, Sleep and
  wake).
- Fixture: the owner's 29–30 Oct 2026 night, decoded from the iPhone Bluetooth captures in that
  morning's sysdiagnose with `hr-tracker/tools/history.py`. Only the History Records go in the
  repo (serial and device ID removed), never the `.pklg` or sysdiagnose (docs/conventions.md).
  hr-tracker on it gives exactly the protocol doc's numbers. The 28–29 Oct night (Resting HR
  54.9, HRV 68.8) is a second option if one more is wanted.
- Wayfinder map "Real metrics, Zones, Load and Readiness" (issue 12) holds the decisions that
  follow from real Nights.
