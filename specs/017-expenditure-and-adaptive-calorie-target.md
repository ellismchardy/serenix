# 017 — Expenditure and the adaptive Calorie Target

**Status:** approved
**Last updated:** 2026-11-08
**Issue:** https://github.com/ellismchardy/serenix/issues/49 (Body tab map, spec 3; research #52)

## Problem
Spec 016 lets the user log Intake and set a Calorie Target by hand, but the number they type is
a guess. What they actually spend shows up in their own data: what they ate on Complete Days and
how their Trend Weight moved. Serenix can work their Expenditure out from that and suggest the
Calorie Target that meets their Weight Goal's Pace, then keep it up to date as they go.

## Goal
Show the user's Expenditure, from their Profile at first and from their own logged data once
there is enough, and suggest (and optionally follow) a Calorie Target that meets their Pace.

## User stories
1. As a user, I want to see roughly how much energy I spend a Day, even before I've logged much.
2. As a user who logs consistently, I want that figure worked out from what I actually eat and
   how my Trend Weight moves, not from a formula.
3. As a user losing or gaining, I want a Calorie Target suggested for my Weight Goal's Pace, and
   the choice to have my Calorie Target follow it automatically.
4. As a user, I want to be stopped from a dangerously low Calorie Target, and told when my Pace
   can't be met safely.
5. As a user who skips logging some Days, I want those Days left out, never counted as eating
   nothing.

## Behavior

### Starting estimate
- Until there is enough logged data (below), Expenditure is the **starting estimate**: the
  Mifflin-St Jeor resting rate times the user's **Activity Level**.
  - Resting rate (kcal a Day) = 10 × Trend Weight (kg) + 6.25 × height (cm) − 5 × age + s, where
    s = +5 for male, −161 for female, and −78 (their midpoint) for "prefer not to say".
  - Age is the current year minus the Profile's birth year.
  - Activity Level: Mostly sitting × 1.2, Light × 1.375 (the default), Moderate × 1.55, Very
    active × 1.725. The user picks it in the targets sheet.
- With no height, no birth year or no Weigh-in, there is no starting estimate, and the targets
  sheet says which is missing.

### Expenditure from logged data
- For a Day D, its **window** is the 21 Days ending on D. The window has **enough data** when it
  holds at least 10 Complete Days, at least 8 Days with a Weigh-in, and at least 14 Days between
  its first and last Weigh-in Days.
- The window's figure = the mean Intake of its Complete Days + (Trend Weight on its first
  Weigh-in Day − Trend Weight on its last) × 7,700 kcal ÷ the Days between them. Days that aren't
  complete never count, not even as zero.
- Expenditure eases toward the data: on the first Day whose window has enough data, it moves
  10% of the way from the starting estimate (as of that Day) to the window's figure; on each Day
  after, 10% of the way from the previous Day's Expenditure to that Day's figure. A Day whose
  window lacks enough data leaves Expenditure where it was.
- Nothing is stored: Expenditure is worked out again each time from Intake, Complete Days and
  Weigh-ins (ADR 0008).

### Suggested Calorie Target
- The **suggested Calorie Target** = Expenditure − the Weight Goal's Pace × 7,700 ÷ 7 when losing,
  + that when gaining, and Expenditure itself when holding or with no Weight Goal. A date Pace
  uses the kg a week spec 015 works out for it.
- **Floor:** never below 1,200 kcal, nor below the resting rate (when there is one). When the
  Pace would need less, the suggestion is the floor and the targets sheet says the Pace can't be
  met safely at this Expenditure, with spec 015's Ease the goal offer.
- The suggestion is rounded to the nearest 10 kcal, except that a floored one rounds up, so it
  never ends below the floor; it is kept within spec 016's 800–6,000.
- With no Expenditure there is no suggestion.

### Adapt
- The targets sheet has an **Adapt my Calorie Target** switch (off by default). When on, the
  Calorie Target the Food view uses each Day is the suggestion; the typed Calorie Target is kept
  and used again if the switch goes off, or while there is no suggestion.
- When off, the typed Calorie Target applies as in spec 016, with the suggestion shown beside it.
- Macro Targets (spec 016) follow whichever Calorie Target applies.

### Screen
- The Food view shows Expenditure under the calories line: "Expenditure ~2,450 kcal · from your
  Profile" before there is enough data, "· from your last 21 Days" after; nothing when there is
  no Expenditure.
- The targets sheet gains the Activity Level picker, the Expenditure and the suggested Calorie
  Target with how it was worked out, the Adapt switch, and the floor message with Ease the goal.

### Backup
- The Activity Level and the Adapt switch travel with the food targets in the Body data file
  (still version 2: the new fields are optional, so older files import with Light and off).

## Design decisions
- **`SerenixCore`: Food view** gains the Profile's birth year and sex, the Activity Level and
  the Adapt switch as inputs, and returns Expenditure with its source (starting estimate, or
  logged data), the resting rate, the suggested Calorie Target, the floor flag, why there's no
  starting estimate, and the Calorie Target that applies. It works Expenditure out with a new
  pure `Expenditure` calculation over the Days up to the one shown, using the Body view's Trend
  Weight rule. 7,700 kcal/kg, the 21-Day window, the 10 / 8 / 14 thresholds, the 10% step, the
  Mifflin-St Jeor coefficients, the four activity factors and the 1,200 kcal floor are named
  constants citing issue #52 and `docs/research/adaptive-calorie-expenditure.md`.
- **`SerenixCore`: Food targets** gain the Activity Level and the Adapt switch (optional, so
  stored and backed-up targets from spec 016 still decode).
- **Shell.** The targets sheet's new controls and the Food view's Expenditure line; the two new
  settings live in `Food.store`'s targets row (ADR 0008). Body data is never logged.
- Follows ADR 0002 and ADR 0008. No new ADR.

## Seams under test
- **Food view (`SerenixCore`)**, fed hand-built Food Entries, Complete Days, Weigh-ins, a Weight
  Goal, Profile fields, food targets, a Day, a time and a time zone. Catches the starting
  estimate, the window, thresholds, easing, the suggestion, the floor and Adapt. Misses the
  sheet, the switch and saving, checked by hand on the phone (ADR 0002).
- **Body data file (`SerenixCore`)**. Catches the new settings round-tripping and older files
  importing with the defaults. Misses the share sheet and the store.

## Success criteria (must be checkable)
Starting estimate
- [ ] Male, age 30, 180 cm, Trend Weight 80 kg, Light: resting rate 1,780 kcal, Expenditure
      2,447.5 kcal from the Profile; female 1,614 → 2,219.25; "prefer not to say" 1,697 →
      2,333.375.
- [ ] Mostly sitting, Moderate and Very active give 1,780 × 1.2, × 1.55 and × 1.725.
- [ ] With no height, no birth year or no Weigh-in there is no Expenditure, and the reason names
      what's missing.
Expenditure from logged data
- [ ] A window of Complete Days averaging 2,000 kcal with Trend Weight unchanged gives a figure
      of 2,000; Days in the window that aren't complete are left out.
- [ ] A window averaging 2,000 kcal with Trend Weight 0.7 kg lower on its last Weigh-in Day than
      its first, 14 Days apart, gives 2,000 + 0.7 × 7,700 ÷ 14 = 2,385.
- [ ] A window with 9 Complete Days, or 7 Days with a Weigh-in, or 13 Days between its first and
      last Weigh-in, doesn't have enough data, so Expenditure stays the starting estimate.
- [ ] From a starting estimate of 2,447.5 and a window figure of 2,000 on each Day: 2,402.75 on
      the first Day with enough data and 2,362.475 on the next.
Suggested Calorie Target
- [ ] Expenditure 2,400: losing at 0.5 kg a week suggests 1,850; gaining at 0.25 kg a week
      2,675, rounded to 2,680; holding or no Weight Goal 2,400.
- [ ] Expenditure 1,800 for a female resting rate of 1,614, losing at 1 kg a week (1,800 − 1,100
      = 700) suggests 1,620 (the floor of 1,614, rounded up) and flags the Pace as not safely
      reachable; with no resting rate the floor is 1,200.
Adapt
- [ ] With Adapt on, the Calorie Target that applies (and the Macro Targets') is the suggestion;
      with it off, the typed one; with it on and no suggestion, the typed one.
Backup
- [ ] Food targets with an Activity Level and Adapt on round-trip; a file without them imports
      as Light and off.
Shell (checked by hand on the phone, steps in the PR)
- [ ] The Food view shows Expenditure with "from your Profile" and later "from your last 21
      Days".
- [ ] The targets sheet's Activity Level, Adapt switch and floor message with Ease the goal work.
- [ ] `swift test` passes and `swift format lint --strict` is clean; the macOS CI job builds.

## Non-goals (explicitly out of scope)
- Calories Burned from heart rate and Load (its own spec, once the formula's coefficients are
  checked against the paper; issue #53).
- Diet Breaks and the Deficit Check (spec 4 of the map).
- Notifications about the Calorie Target.
- Writing energy to Apple Health.

## Open questions
- **Window when the Trend Weight restarts:** a 14-Day gap restarts Trend Weight (spec 015).
  Assumption: a window whose Weigh-ins span a restart uses only the Weigh-ins after it, and so
  usually lacks enough data until 14 more Days pass.

## Notes
- Research: issue #52 and `docs/research/adaptive-calorie-expenditure.md` (method, 7,700
  kcal/kg, thresholds); `docs/research/calories-burned-from-heart-rate.md` (Mifflin-St Jeor).
- Builds on spec 015 (Trend Weight, Pace, Ease the goal) and spec 016 (Intake, Complete Days,
  Calorie Target, Macro Targets, food targets).
