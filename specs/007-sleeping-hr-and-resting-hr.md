# 007 — Sleeping HR and Resting HR

**Status:** approved
**Last updated:** 2026-11-04 (Days missing their values are queued on every launch, not once)

## Problem
Serenix calls the lowest sustained heart rate during a Sleep Period "Resting HR", as WHOOP and Oura
do. Resting HR proper is measured awake and at rest, and sits a few bpm higher (about 4 bpm on
average for these two "lowest" measures; the often-quoted 10–20% compares average awake and
average asleep heart rate). So the app labels a sleeping value as a resting one. Load is hurt
too: its formula (Banister, from Karvonen's heart-rate reserve) is defined against an awake
Resting HR, and feeding it the lower sleeping value makes Load read slightly high. And Apple
Health's resting heart rate means awake at rest, so the planned export would mislabel it.

The Strap already records all day and every History Sync brings those History Records to the
phone, so an awake Resting HR needs no constant connection (ADR 0006; spec 006's ADR 0007 holds
one only while Live HR is on screen).

## Goal
The Night metric is renamed Sleeping HR (SHR), unchanged in value and still driving Baseline,
Zones and Readiness. Each Day gets a new Resting HR (RHR), worked out from that Day's awake,
still History Records, shown on the Today screen and used by Load.

## User stories
1. As a Strap owner, I want the overnight value labelled Sleeping HR, so that I don't compare it
   with resting heart rates measured awake elsewhere.
2. As a Strap owner, I want to see my Resting HR for a Day, worked out while I was awake and
   still, without doing anything or keeping the app open.
3. As a Strap owner, I want today's Resting HR marked as "so far", since a stiller moment later
   in the Day can lower it.
4. As a Strap owner who naps, I want a nap not to count as resting, so that Resting HR doesn't
   creep down to my Sleeping HR.
5. As a Strap owner who barely wore the Strap one Day, or never sat still, I want that Day's
   Resting HR shown as "—", not a guess.
6. As a Strap owner, I want Load worked out against my awake Resting HR, as its formula intends.
7. As a Strap owner updating the app, I want my past Nights to keep their values under the new
   name.

## Behavior
**Sleeping HR.** Today's "Resting HR" Nightly Metric, renamed. Its method (spec 003), Baseline,
Spread and Zones (spec 004) and its role in Readiness and the Readiness advice (spec 002) don't
change. Everywhere it is shown it reads "Sleeping HR": its tile, its popup, vs your Baseline, the
Readiness popup and the advice ("Sleeping HR is up 4 bpm"). SHR and RHR are used only in code and
where space is tight (chart axes, a future widget).

**Resting HR of a Day.** Worked out from the History Records whose timestamps fall in the Day,
local midnight to local midnight (23 or 25 hours across a clock change), repeats counted once,
leaving out every record inside the Sleep Period (Sleep Onset up to Final Wake) of any Night that
overlaps the Day. The rest is taken minute by minute (clock minutes):
- **Worn minute:** at least 30 of its records have a heart rate above 0 (spec 003's
  fewest-records rule).
- **Still minute:** a worn minute with no steps (no record's step count is above the previous
  record's; a drop is a Strap reboot, not a step). Wrist movement doesn't count: at a desk the
  Strap turns more than 2° in most seconds of every minute (the fixture Day), so spec 003's
  active-second rule would leave only bedtime.
- **Still run:** consecutive still minutes. Any other minute, or a missing one, ends the run.
- **Settled window:** 5 consecutive minutes of a still run, all within its minutes 5 to 15. The
  first 4 minutes let heart rate settle; after minute 15 the user may have fallen asleep (a Nap).
  So a still run gives windows starting at its minutes 5 to 11, as far as the run reaches.
- **Resting HR** is the lowest mean heart rate over a settled window, taking every record in it
  with a heart rate above 0, in bpm.

There is no lockout after exercise: a raised stretch is never the lowest window. Resting HR is
missing when the Day has fewer than 480 worn minutes (8 hours) outside Sleep Periods, or no
settled window. Every constant (30 records, 4, 5, 15 and 480 minutes) is
named and cites docs/research/awake-resting-hr.md or spec 003.

**Today's is so far.** Today's Resting HR covers the records synced up to now, and is worked out
again as more arrive. It can only stay or fall as the Day goes on, except when a Night's Sleep
Period, rebuilt, swallows its window.

**When.** In each Day rebuild (spec 005), after the sync's Nights are rebuilt, the Day's Resting
HR is worked out and stored, then its Load. Resting HR is kept forever with the Day, like Load.
The 30-day and future rules of Day rebuilds apply; a Profile change doesn't change Resting HR.

**Load.** Uses the median Resting HR of recent Days (spec 005, Resting HR), not Nights.

**Today screen.** Under the tiles heading, the Time Asleep tile spans the full width, then the
metric tiles in a 2-column grid: Sleeping HR, Resting HR, HRV, respiratory rate, skin
temperature, SpO2. The Resting HR tile shows the Day shown:
- the name "Resting HR" with the same heart icon as Sleeping HR
- the value in whole bpm, e.g. "62 bpm", or "—" when missing
- on today, "So far today" where other tiles have their status word; on an earlier Day, nothing
- no Zone (white) and an empty gauge; tapping it opens the Resting HR popup (spec 011)

**Updating the app.** Nights stored by an earlier build keep their value, now as Sleeping HR.

**Days missing their values.** Each stored Day notes that its HR Zones (spec 006) and Resting HR
were kept when it was worked out, even when either is legitimately missing (no Max HR, no still
stretch). A Day without that note was stored by an earlier build, or opened by another build of
Serenix that doesn't store these values and dropped them. Every time Serenix opens, and on every
other Day rebuild pass (after a sync, after a Profile change), it queues one Day rebuild (spec 005)
for each stored Day without the note that is still due by spec 005's 30-day rule, unless that
Day's rebuild is already queued. A rebuilt Day gains the note, so it isn't queued again. Older
Days keep what they have. There's no "already done" flag: a flag can't see values lost after it
was set.

## Design decisions
- **`SerenixCore`: Resting HR of a Day (new).** Given a Day, its History Records, the Nights and
  a time zone, returns the Day's Resting HR in bpm, or nil. Pure; never reads the clock. Lives
  next to Load of a Day.
- **`SerenixCore`: Night and Nightly Metric.** The Night's Resting HR and the Nightly Metric case
  become Sleeping HR, with every Zone, Baseline, vs your Baseline, popup and advice use following.
- **`SerenixCore`: Load of a Day.** Takes the Days' Resting HRs in place of the Nights; its
  Resting HR median reads Days (spec 005).
- **`SerenixCore`: Today view.** Takes the Days' Resting HRs and gives a Resting HR tile with its
  value, "So far today" or nothing, and no Zone; the tile list gains it after Sleeping HR. The
  Resting HR tile is not a Nightly Metric (it belongs to a Day) and opens its own popup (spec 011).
- **`SerenixCore`: Day rebuilds** gains the missing-values queue: given the stored Days (each
  saying whether its values were kept), the Day rebuilds already queued, now and the time zone,
  the rebuilds to add because the Day's values weren't kept, it's still due, and it isn't queued
  yet; oldest first. A Day worked out by Load of a Day has its values kept.
- **Shell.** The stored Night field keeps its stored name (or maps from it) so past Nights keep
  their values. Each stored Day gains Resting HR and the optional "values kept" note (a missing
  note reads as not kept, so a store where it was dropped requeues). The Day rebuild works out
  Resting HR, then Load. The Today screen lays out Time Asleep full width, then the grid. Each
  rebuild pass asks the missing-values queue before working out the queued Days; the once-only
  UserDefaults flags for HR Zones and Resting HR go.
- **Apple Health (later spec).** The export writes Resting HR as resting heart rate. Sleeping HR
  is never written as resting heart rate.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0006 (no held connection). No new ADR: the
  method's constants are easy to change, and naming lives in GLOSSARY.md.

## Seams under test
- **Resting HR of a Day (`SerenixCore`)**, fed hand-built History Records and Nights with a fixed
  time zone, plus one real fixture Day. Catches still and worn minutes, steps, wrist movement,
  settling, the 15-minute cap, Sleep Period exclusion, the 8-hour rule, Day boundaries, a clock
  change, repeats, and how the method behaves on the user's real Strap. Expected values are worked
  by hand from this spec and committed as literals.
- **Load of a Day (`SerenixCore`)**: its Resting HR now from Days (criteria in spec 005).
- **Nights (`SerenixCore`)**: only the name changes; spec 003's fixture values stand.
- **Today view (`SerenixCore`)**, fed Nights and Days. Catches the names, the tile order, the
  Resting HR tile and the advice wording.
- **Day rebuilds (`SerenixCore`)**, fed hand-built stored Days, queued rebuilds and a fixed `now`
  and time zone. Catches which Days the missing-values queue adds: values not kept, still due,
  not already queued.

They miss the stored field's old name, storing Resting HR and the "values kept" note, the Day
rebuild order, calling the missing-values queue on each pass, the layout and the tap, which are
checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Resting HR of a Day, unless a criterion says otherwise: Europe/London, the Day 10 Nov 2026, no
Nights, one History Record per second, no turn between records, and the step count unchanged.
**The desk Day:** 08:00 to 17:00 (540 minutes) at 75 bpm with the step count rising by 1 a
second, except a still stretch from 12:00 to 12:20 whose minutes 1–4 are at 55 bpm, 5–9 at 62,
10–15 at 64 and 16–20 at 50.

- [x] The desk Day gives Resting HR 62 (the settling 55 and the 50 after minute 15 don't count);
      with minutes 5–9 at 66 instead, it gives 64 (minutes 10–14).
- [x] With the Strap turning 10° every second of the still stretch (wrist movement, no steps),
      the desk Day still gives 62.
- [x] With one step in the still stretch's minute 7, the run breaks: minutes 1–6 give no window,
      and the run from minute 8 settles until minute 11, so its windows reach minute 20 and
      Resting HR is 50. (The cap counts from each run's start.)
- [x] A drop in the step count (a Strap reboot) in the still stretch counts as no step: 62.
- [x] With only 29 records above 0 bpm (the rest 0) in the still stretch's minute 3, the run
      starts again at minute 4, its windows run from minute 8 to 18, and Resting HR is 55.6
      (minutes 14–18: 64, 64, 50, 50, 50); with 30 it gives 62.
- [x] The desk Day starting at 09:01 (479 worn minutes) has no Resting HR; starting at 09:00 (480)
      it gives 62.
- [x] The desk Day plus records from 00:00 to 07:00 at 45 bpm, still, gives 45; with a Night whose
      Sleep Period runs from 23:00 on 9 Nov to 07:00 on 10 Nov they are left out and it gives 62,
      and the desk Day starting at 09:01 plus them, with that Night, has no Resting HR.
- [x] Only the Day's records count: a still stretch at 50 bpm from 12:00 to 12:20 on 11 Nov
      leaves 10 Nov at 62. On 25 Oct 2026 (clocks go back) the desk Day built at local times
      gives 62, records from 23:00 UTC on 24 Oct (local midnight) count toward 25 Oct, and those
      before it toward 24 Oct.
- [x] The desk Day with every record repeated, or in a different order, gives 62.
- [x] On a real fixture Day (a full Day from the project owner's Strap, with steps): Resting HR is
      present, at least that morning's Night's Sleeping HR and no more than 15 bpm above it; the
      step count stays flat over a stretch sitting still and rises over a stretch walking.
- [x] Nights: the fixture night of 29–30 Oct 2026 gives Sleeping HR 48.1 bpm; no Night,
      Nightly Metric, Zone, Baseline or view in `SerenixCore` or the app still calls it Resting HR
      (searching the source for "restingHR" finds only the awake Resting HR).
- [x] Today view: tiles come as Sleeping HR, Resting HR, HRV, respiratory rate, skin temperature,
      SpO2, after the Time Asleep tile; the first is named "Sleeping HR".
- [x] Today view: on today with a Day Resting HR of 61.6, the Resting HR tile reads "Resting HR",
      "62 bpm" and "So far today", with no Zone (spec 011 adds its popup); on an earlier Day with Resting HR 58
      it reads "58 bpm" and no status; a Day without one reads "—" with an empty gauge.
- [x] Today view: Take it easy with Sleeping HR 56 against Baseline 52 says "Sleeping HR is up 4
      bpm"; vs your Baseline and the Readiness popup name "Sleeping HR".
- [ ] Day rebuilds: with now 30 Nov 2026 12:00, stored Days 10 Nov and 12 Nov without their values
      kept and 11 Nov with them kept, and nothing queued, queue 10 Nov then 12 Nov, each reading
      its local midnight to the next; 11 Nov isn't queued.
- [ ] Day rebuilds: with 10 Nov's rebuild already queued, only 12 Nov is added; with both
      queued, nothing is.
- [ ] Day rebuilds: with now 30 Nov 2026 12:00, a stored Day 31 Oct without its values kept
      isn't queued (no longer due); one stored 1 Dec isn't either (a Strap clock ahead).
- [ ] Day rebuilds: a Day worked out by Load of a Day has its values kept, even with no Resting
      HR and no HR Zones (no records, or no Max HR).
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app; no `heartRateZonesBackfilled` or `restingHRBackfilled` key is left in the
      source.
- [ ] On the phone (by hand): installed over the previous build, past Nights still show their
      value, now as Sleeping HR, and Days of the last 30 days gain a Resting HR.
- [ ] On the phone (by hand): after opening another build of Serenix that doesn't store HR Zones
      or Resting HR, then this one, Days of the last 30 days show their Resting HR and HR Zones
      again after a launch, without a new sync; a second launch queues nothing more for them.
- [ ] On the phone (by hand): after a sync covering a full Day, its Resting HR shows on the
      Resting HR tile, a few bpm above that morning's Sleeping HR; on today it reads "So far
      today"; Time Asleep spans the full width over a 2-column grid.

## Non-goals (explicitly out of scope)
- A Baseline, Spread, Zone, gauge position or popup for Resting HR; Resting HR in Readiness.
- Detecting Naps as such, or Naps in Time Asleep.
- A post-exercise lockout, posture, or a spot-check measurement on demand.
- Writing to Apple Health (its own spec; the mapping is fixed above).
- Holding a connection to the Strap, or any opt-in setting for one.
- Retuning Sleeping HR's method, Zones or the Readiness advice constants.

## Open questions
- **Fast sleepers.** Someone very short of sleep can fall asleep in under 10 minutes, letting a
  Nap into the window (pulling Resting HR toward Sleeping HR). The fixture Day shows whether it
  matters; accepted for now.
- **Stepless activity.** Driving, cycling or an arm workout has no steps, so it counts as still.
  Exercise raises heart rate and never gives the lowest window; driving could nudge Resting HR up
  a little, never below the truth. Accepted for now.
- **One fixture Day.** Steps only was chosen on one real Day (Resting HR 62.8 against that
  night's Sleeping HR 54.9). Check it against more Days as they're captured.

## Notes
- Research: docs/research/awake-resting-hr.md (Speed et al. 2023 for settle time, the 8-hour
  rule and the ~4 bpm gap; Polar for the 5-minute span; Apple for excluding sleep and analysing
  the whole Day).
- Changes specs 002 (tile layout, names, advice), 003 and 004 (name only) and 005 (Load's Resting
  HR from Days).
- Spec 006 (Load popup) shipped first (#25); its "no Nights (Resting HR 60)" default now reads
  "no Days with a Resting HR".
- The real fixture Day: 28 Oct 2026, from the owner's Bluetooth captures, with a `steps` column
  added. Its step count stayed flat sitting and rose at the gym, so the counter is usable. No
  capture holds the 27–28 Oct Night, so the owner agreed its reference is the 28–29 Oct Night.
- The still rule first also needed fewer than 10 active seconds (spec 003's 2° rule). On the
  fixture Day the wrist turned in 22–59 seconds of every desk minute, leaving no settled window
  once the Sleep Period was left out, so the owner chose steps only.
