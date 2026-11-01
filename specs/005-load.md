# 005 — Load

**Status:** approved
**Last updated:** 2026-11-01
**Issue:** https://github.com/ellismchardy/serenix/issues/12 (wayfinder map); decisions in
https://github.com/ellismchardy/serenix/issues/16 and
https://github.com/ellismchardy/serenix/issues/18

## Problem
The Today screen has a Load ring (spec 002), but nothing works out Load, so it always shows "—".
Readiness (the next spec) needs the previous Day's Load, and the Readiness advice tells the user
to keep their Load under a number they can't see. Load needs a Max HR, which needs the user's age
or a measured Max HR, and the Profile holds only a name.

## Goal
After a History Sync, each Day the user wore the Strap gets a Load from 0 to 100: how much
cardiovascular exertion they built up that Day, worked out on the phone from their heart rate.
The Profile can hold their birth year, sex and Max HR so Load can be worked out.

## User stories
1. As a Strap owner, I want the Load ring to show how hard my Day has been so far, so that I can
   follow the Readiness advice's "keep your Load under N".
2. As a Strap owner, I want a lazy Day of sitting and walking about to score near 0 and a hard
   hour of exercise to score clearly higher, so that Load reflects exercise, not just being awake.
3. As a Strap owner who knows their Max HR from a test, I want to enter it, so that Load uses it
   instead of an estimate from my age.
4. As a Strap owner who hasn't given an age or Max HR, I want the Load ring to tell me to add my
   age, not show a made-up number.
5. As a Strap owner who adds or changes their age, sex or Max HR, I want recent Days' Load
   worked out again, so that the numbers I see agree with what I entered.
6. As a Strap owner who didn't wear the Strap one Day, I want that Day's Load shown as "—", not 0.
7. As a Strap owner, I want my birth year, sex and Max HR kept on my phone only, so that they
   never leave it.

## Behavior
**Which records.** A Day's Load uses the History Records whose timestamps fall in that Day, local
midnight to local midnight (23 or 25 hours across a clock change). Repeated History Records count
once.

**Max HR.** The Max HR the user entered, else estimated from age (Tanaka): `208 − 0.7 × age`, with
age = the Day's year − birth year. With neither, Load is missing. Max HR is never raised
automatically from heart rates the Strap sees.

**Resting HR.** The median Resting HR of up to 14 of the most recent Nights dated on or before the
Day (so the Night that ended that morning counts). Nights without a Resting HR are skipped. With
fewer than 14 such Nights, the median of those that exist; with none, a typical 60 bpm (named
assumption).

**Sum (Banister TRIMP, per second).** Each History Record with a heart rate HR counts as one
second:
- It counts nothing when HR is 0 or below 50% of Max HR (the floor, from Edwards).
- Otherwise r = (HR − Resting HR) / (Max HR − Resting HR), capped at 1 (an HR above Max HR counts
  as Max HR) and at least 0 (an HR below Resting HR counts nothing), and it adds
  `r · k · e^(b·r) / 60`.
- k and b come from the Profile's sex: Male k 0.64, b 1.92; Female k 0.86, b 1.67; Prefer not to
  say (the default, and when sex isn't set) their average, k 0.75, b 1.795.

Gaps between records count nothing; there is no minimum duration.

**Scale.** `Load = 100 · ln(1 + L) / ln(1 + L_max)`, where L is the sum and L_max is the sum for
24 hours at Max HR (r = 1) with the same k and b: `1440 · k · e^b`. Load is rounded to a whole
number. Rough values for a man with Max HR 190 and Resting HR 60: a Day at rest 0, 30 minutes at
112 bpm (brisk walk) 33, an hour at 120 bpm 43, an hour at 164 bpm (hard) 57, 24 hours at Max HR
100. All constants are named and commented with their unit and source (issue 16).

**Missing vs 0.** Load is missing ("—") for a Day with no History Records, and when there's no Max
HR (none entered, no birth year) or Max HR is at or below Resting HR. A Day with records but no
second over the floor has Load 0. Today's Load is "so far": the records synced up to now.

**Add your age.** When Load is missing because there's no Max HR, the Load ring shows "—" and its
label reads "Add your age" instead of "Load so far" / "Load". Tapping the ring then opens the
profile menu. Otherwise tapping the Load ring still does nothing (spec 002). A Day missing Load
for any other reason keeps the normal label.

**When.** Load is worked out Day by Day, in the same pass as spec 003's Night rebuilds: each sync
queues every Day its History Records fall on, kept on the phone, and after that sync's Nights are
rebuilt (so the morning's Night is there), each queued Day's Load is worked out and stored,
replacing the old one. The same rules as Night rebuilds apply: a Day whose records start more
than 30 days ago, or in the future, is skipped, checked when queued and when worked out. A
rebuilt Night doesn't redo later Days' Load. Load is kept forever.

**Profile changes.** Adding, changing or clearing birth year, sex or Max HR queues every Day whose
History Records are still on the phone (the last 30 days), and their Load is worked out again.
Older Days keep the Load they had (a known limit: their records are gone).

**Profile.** The profile menu's Profile section gains three rows under the name, all optional:
- **Birth year:** a picker from 100 years ago to 13 years ago, or not set (the default).
- **Sex:** Female, Male or Prefer not to say (the default), with the hint "Used only for
  heart-rate calculations".
- **Max HR:** a whole number of bpm from 100 to 230, or blank (the default). When blank and a
  birth year is set, it shows the estimate for today's year, e.g. "Estimated 180 from your age".

They are kept only on the phone, never sent anywhere, and never appear in the Sync Log, a shared
log or any report (docs/architecture.md). Nothing is added to first launch.

**Readiness advice.** Spec 002's Load constants are retuned to this scale, each still a named
assumption to tune with real Days: a Load of **55** or more yesterday counts as high (about a hard
hour); Steady says "keep your Load under **50** today" (about an hour of moderate exercise); Take
it easy says "under **33**" (about a 30-minute brisk walk).

## Design decisions
- **`SerenixCore`: Load of a Day.** Given a Day, its History Records, the Nights, the Profile's
  birth year, sex and Max HR, and a time zone, it returns the Load (0–100, whole number) or why
  it's missing: no History Records, or no Max HR (which drives "Add your age"). Inside it, the
  Resting HR median, the Max HR, the sum and the scale are separate pure functions. It never
  reads the clock.
- **`SerenixCore`: Day rebuilds.** Next to Night rebuilds: given the times of History Records a
  sync stored, the current time and a time zone, it returns the Days whose Load to work out
  again, oldest first, each with the stretch of History Records to read (local midnight to
  midnight), and each can say whether it's still due (the 30-day and future rules). Given only
  the current time and time zone, it returns every Day still due, for Profile changes.
- **`SerenixCore`: Profile** gains birth year, sex (Female, Male, Prefer not to say) and Max HR,
  each optional, with the allowed ranges above, and gives the estimated Max HR for a year.
- **`SerenixCore`: Today view.** The Days with their Load also say why a missing Load is
  missing, so it can label the ring "Add your age" and say that tapping it opens the profile
  menu. `DayLoad` carries the reason.
- **Readiness advice** constants change to 55, 50 and 33.
- **Shell:** it queues Days as each Batch is stored, alongside Night dates, and works them out
  after the Nights, one Day at a time off the main thread, storing one Load per Day in SwiftData.
  It stores the new Profile fields on the phone, draws the three rows, queues every due Day when
  one changes, and opens the profile menu from the ring when asked.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own name, 0–100). No new ADR: the
  method and constants are easy to change later.

## Seams under test
- **Load of a Day (`SerenixCore`)**, fed hand-built History Records, Nights and Profile fields
  with a fixed time zone. It catches the floor, the cap at Max HR, the clamp at Resting HR, the
  sex constants, Tanaka and its age, the Resting HR median and its 60 bpm fallback, the scale,
  rounding, Day boundaries, repeats, and every missing reason. Expected values are worked by
  hand from this spec's formula and committed as literals (hr-tracker has no Load).
- **Day rebuilds (`SerenixCore`)**, fed hand-picked record times and a fixed `now` and time zone.
  It catches which Days are queued, the stretch read, the 30-day and future rules, a clock
  change, and every due Day for a Profile change.
- **Today view (`SerenixCore`)**, fed Days with their Load. It catches "Add your age", which
  missing Loads keep the normal label, and the retuned advice.
- **Profile (`SerenixCore`)**: the allowed ranges and the estimated Max HR.

They miss the queue and storage, the order of Nights then Load, the profile menu rows, the tap on
the ring, and keeping the fields out of logs, which are checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Unless a criterion says otherwise: Europe/London, sex Male, Max HR 190 entered, no Nights (Resting
HR 60), and one History Record per second.

- [ ] An hour of records at 164 bpm gives Load 57; with sex Female 58; with Prefer not to say, or
      sex not set, 57.
- [ ] 30 minutes at 112 bpm gives 33; an hour at 120 bpm gives 43.
- [ ] 16 hours at 94 bpm (below 50% of Max HR) gives 0; an hour at 95 bpm gives 33.
- [ ] An hour at 200 bpm gives the same Load as an hour at 190 bpm: 64.
- [ ] 24 hours at 190 bpm gives 100.
- [ ] An hour at 164 bpm plus an hour of records with heart rate 0 gives 57; the same hour with
      every record repeated, or in a different order, gives 57.
- [ ] With Resting HR 100 entered through Nights, an hour at 96 bpm (over the floor, under Resting
      HR) gives 0.
- [ ] No Max HR, birth year 1986, sex Male: an hour at 154 bpm on a Day in 2026 (Max HR 180) gives
      56; with no birth year either, Load is missing because there's no Max HR.
- [ ] An entered Max HR wins over birth year: Max HR 190 with birth year 1986 gives 57 for an hour
      at 164 bpm.
- [ ] Resting HR: with Nights whose Resting HR are 50, 52 and 54, all dated on or before the Day,
      an hour at 120 bpm gives 45; adding a Night dated the Day after, at 90, changes nothing;
      with a Night of Resting HR 70 dated the Day itself and no others, it gives 41.
- [ ] Resting HR: with 15 Nights on or before the Day, the oldest at Resting HR 20, then 7 at 50
      and the 7 most recent at 70, an hour at 120 bpm gives 43 (median 60 of the 14 most recent;
      counting the oldest would give 45); a Night without a Resting HR is skipped, not counted.
- [ ] Max HR at or below Resting HR gives missing Load (Max HR 100 entered, Resting HR 100 from a
      Night).
- [ ] A Day with no History Records has missing Load; one with records but none over the floor
      has 0.
- [ ] Only the Day's records count: an hour at 164 bpm from 23:30 to 00:30 on the night 31 Oct to
      1 Nov 2026 counts 30 minutes toward each Day (each gives 49); on 29 Mar 2026 (clocks go
      forward) the Day runs 00:00 to 23:00 UTC.
- [ ] Day rebuilds: records at 23:00 on 14 Nov and 07:00 on 15 Nov 2026 queue 14 Nov and 15 Nov,
      each reading local midnight to midnight; repeats and order change nothing.
- [ ] Day rebuilds: with now 30 Nov 2026 12:00, a record at 31 Oct 13:00 queues nothing (its Day
      starts more than 30 days earlier), one at 1 Nov 01:00 queues 1 Nov, one at 30 Nov 13:00
      queues 30 Nov, and one at 1 Dec 01:00 queues nothing (its Day starts after now); for a
      Profile change, the 30 Days 1 Nov to 30 Nov are returned, oldest first.
- [ ] Profile: Max HR is accepted from 100 to 230 and refused outside it; birth year from 100 to
      13 years before the current year; the estimate for birth year 1986 in 2026 is 180.
- [ ] Today view: a Day whose Load is missing for no Max HR labels the ring "Add your age" and
      marks it as opening the profile menu; a Day missing Load for no records labels it "Load"
      ("Load so far" on today) and marks no tap.
- [ ] Readiness advice: a Load of 55 yesterday is mentioned as high, 54 isn't; Steady says "keep
      your Load under 50 today"; Take it easy says "keep your Load under 33 today".
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): with birth year set, after a morning sync the Load ring shows
      yesterday's Load on yesterday and "Load so far" on today; a Day with a workout reads clearly
      higher than a Day without one.
- [ ] On the phone (by hand): with no birth year or Max HR, the ring reads "—" and "Add your age",
      and tapping it opens the profile menu; setting a birth year fills in Load for the last 30
      days.
- [ ] On the phone (by hand): Birth year, Sex and Max HR rows appear in the profile menu, Max HR
      blank shows "Estimated N from your age", and they survive a relaunch.
- [ ] On the phone (by hand): a shared Sync Log contains no birth year, sex or Max HR.

## Non-goals (explicitly out of scope)
- A Load popup or hourly Load (a later spec); spec 002 had left it to this one.
- The Load Baseline (median of earlier Days' Load) and Readiness: the Readiness spec.
- Raising Max HR automatically from heart rates the Strap sees (after v1).
- Tuning the 50% floor, the curve or the advice constants against real Days.
- Redoing later Days' Load when a Night is rebuilt; redoing Days whose History Records are
  pruned.
- Asking for birth year, sex or Max HR at first launch (the planned onboarding flow).
- Writing Load to Apple Health, Stress, muscular load, and workouts.

## Open questions
- **A typical 60 bpm.** The Resting HR fallback with no Nights is a named assumption, not
  measured.
- **Day vs Night window.** Load uses midnight to midnight, so sleep after midnight falls in the
  next Day. It counts nothing (it's under the floor), so this doesn't matter in practice.

## Notes
- Research: docs/research/cardio-load-methods.md (issue 15). Method decisions: issue 16. How
  Readiness uses Load: issue 18.
- Specs 002 (Today screen, Load ring and advice) and 003 (Night rebuilds, which Day rebuilds sit
  next to). Spec 004 (Baseline Spread and Zones, PR 22) doesn't touch Load.
- Spec 002's Readiness message constants are updated to match (see its Readiness message).
