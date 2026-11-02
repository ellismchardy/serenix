# 009 — Sleep Need and Sleep Debt

**Status:** approved
**Last updated:** 2026-11-02 (approved)
**Issue:** https://github.com/ellismchardy/serenix/issues/34 (map: https://github.com/ellismchardy/serenix/issues/31)

## Problem
Serenix tells the user how long they slept but not how long they needed, and a run of short
Nights leaves no trace from one morning to the next. Readiness judges Time Asleep against a fixed
7 h whatever the week was like, and Sleep Score, still "—", needs a Sleep Need to measure
against.

## Goal
Each Night gets a Sleep Need, the user's Usual Need plus part of the Sleep Debt from the week
before, shown in the Sleep popup with that Sleep Debt. Readiness scores Time Asleep against it
(spec 008).

## User stories
1. As a Strap owner, I want to see how much sleep I needed last night, so I know whether my Time
   Asleep was enough.
2. As a Strap owner after a run of short Nights, I want my Sleep Need to go up a little, so the
   app reflects that I'm behind, without asking for an impossible night in bed.
3. As a Strap owner who slept long after a short Night, I want that long Night to pay the debt
   back.
4. As a Strap owner aged 65 or over, I want a Usual Need that fits my age once I've given my
   birth year.
5. As a new Strap owner, I want a Sleep Need from my first Night, without waiting for a Baseline.
6. As a Strap owner who didn't wear the Strap some nights, I want those nights left out, not
   counted as no sleep.
7. As a Strap owner, I want Readiness to judge a short Night against what I needed, not a fixed
   7 h.

## Behavior
For a Night dated D (spec 002: the local date of its Final Wake):

**Usual Need.** **8 h**, or **7.5 h** when the user is 65 or older: D's year minus the Profile's
birth year is 65 or more. With no birth year it is 8 h.

**Sleep Debt.** The Nights dated D − 7 to D − 1 count, D itself left out. A Night in that window
is skipped when it has no plausible Time Asleep (missing, negative or not a number, as the Time
Asleep tile treats it), the same as a date with no Night. Sleep Debt is the sum, over the Nights
that count, of (Usual Need − Time Asleep), each Night's Usual Need being D's. A Night longer than
Usual Need adds a negative amount, paying the shortfall back. The sum is never below zero: no
sleep is banked ahead. With no Nights that count, Sleep Debt is 0.

**Sleep Need.** Usual Need + ¼ of Sleep Debt, but never more than Usual Need + 1 h. It exists for
every Night, whether or not the Night's own Time Asleep is plausible, since it depends only on
the Nights before.

Examples, with no birth year (Usual Need 8 h):
- Earlier Nights of 6 h and 9 h: Sleep Debt 2 h − 1 h = 1 h, Sleep Need 8 h 15 m.
- Earlier Nights all 9 h: Sleep Debt 0, Sleep Need 8 h.
- Four earlier Nights of 6 h: Sleep Debt 8 h, a quarter is 2 h, so Sleep Need is capped at 9 h.

**Load** doesn't change Sleep Need: Readiness already reads the previous Day's Load.

**Always current.** Sleep Need and Sleep Debt are worked out whenever the Today view is, from the
stored Nights and the Profile's birth year, and are never stored. A sync that fills in an
earlier Night, or a change of birth year, updates them with nothing to rebuild.

**Sleep popup.** Spec 002's Sleep popup gains two rows after Time Asleep:
- **Sleep Need**, in hours and minutes as the Time Asleep tile writes them ("8h 15m").
- **Sleep Debt**, the same way ("1h 0m", "0h 0m"), with the caption "Your last N Nights", N being
  the Nights that counted ("Your last 1 Night" when N is 1), or "No earlier Nights" when N is 0.

**Readiness** (spec 008, changed with this spec): the Time Asleep score is −(hours short of the
Night's Sleep Need), and the Readiness popup's Time Asleep row shows the Night's Sleep Need as
its reference.

## Design decisions
- **`SerenixCore`: Sleep Need (new).** A pure function: given the Night's date, the earlier
  Nights and the birth year, it returns Usual Need, Sleep Debt, Sleep Need and how many Nights
  counted. Usual Need's two values, the age 65, the 7-Night window, the quarter and the +1 h cap
  are named constants, each citing issue #34 and `docs/research/sleep-need-and-debt.md`
  ("assumption: tune with real Nights").
- **`SerenixCore`: Readiness** takes the Night's Sleep Need in place of its fixed 7 h mark (spec
  008). Its other inputs, weights and curve don't change.
- **`SerenixCore`: Today view** gains the Profile's birth year as an input, works out Sleep Need
  once for the Night shown, and passes it to Readiness, the Readiness popup and the Sleep popup.
  The Sleep popup gains its Sleep Need and Sleep Debt rows.
- **Shell.** Passes the Profile's birth year to the Today view. No SwiftData change: nothing new
  is stored.
- Follows ADR 0002 (logic in `SerenixCore`). No new ADR: every constant is easy to change.

## Seams under test
- **Today view (`SerenixCore`)**, the seam of specs 002, 004 and 008, fed hand-built Nights, a
  birth year and a time zone. Through the Sleep popup and the Readiness text and popup it
  catches Usual Need by age, Sleep Debt's window, payback, floor and skipping, Sleep Need's
  quarter and cap, the caption's count, and Readiness against Sleep Need. It misses drawing and
  the shell passing the birth year, checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`). Unless a criterion says otherwise: the Night shown is dated 15 Nov 2026
with Time Asleep 8 h; no birth year; times in Europe/London. "Earlier Nights" are dated 14 Nov,
13 Nov and so on back, in that order. Expected values worked by hand from the rules above.

Usual Need and Sleep Need:
- [ ] With no earlier Nights, the Sleep popup shows Sleep Need "8h 0m", Sleep Debt "0h 0m" and
      "No earlier Nights".
- [ ] Birth year 1961 (65 in 2026) gives Sleep Need "7h 30m"; 1962 (64) gives "8h 0m".
- [ ] Birth year 1961 with one earlier Night of 6 h 30 m gives Sleep Debt "1h 0m" and Sleep Need
      "7h 45m".
- [ ] Earlier Nights of 6 h and 9 h give Sleep Debt "1h 0m" and Sleep Need "8h 15m".
- [ ] Four earlier Nights of 6 h give Sleep Debt "8h 0m" and Sleep Need "9h 0m" (capped).
- [ ] Earlier Nights all 9 h give Sleep Debt "0h 0m" (never below zero) and Sleep Need "8h 0m".
- [ ] The Night shown with no Time Asleep still shows Sleep Need "8h 15m" after earlier Nights of
      6 h and 9 h.

Window and skipping:
- [ ] Nights dated 8 Nov to 14 Nov count; a Night dated 7 Nov of 4 h changes nothing; the Night
      shown's own Time Asleep of 4 h changes nothing.
- [ ] Earlier Nights dated 14 Nov (6 h), 13 Nov (no Time Asleep) and 11 Nov (6 h) give Sleep Debt
      "4h 0m", Sleep Need "9h 0m" and "Your last 2 Nights".
- [ ] One earlier Night reads "Your last 1 Night"; seven read "Your last 7 Nights".

Always current:
- [ ] The same Nights give Sleep Need "8h 0m" with no birth year and "7h 30m" with birth year
      1961.
- [ ] Adding an earlier Night of 6 h on 14 Nov to the same Nights changes Sleep Need from
      "8h 0m" to "8h 30m".

Readiness (spec 008's criteria, changed with this spec, cover the score; these cover the link):
- [ ] Four earlier Nights of 6 h (Sleep Need 9 h) with the Night shown at 8 h, and the HRV and
      Sleeping HR of spec 008's usual Night, give Readiness 62, and the Readiness popup's Time
      Asleep row reads "8h 0m", "9h 0m", "−1h 0m".
- [ ] Earlier Nights of 6 h, 8 h, 8 h and 8 h (Sleep Need 8 h 30 m) give Readiness 66, Steady.

Build and phone:
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): the Sleep popup shows Sleep Need and Sleep Debt under Time Asleep,
      and they match the Time Asleep of the Nights before.
- [ ] On the phone (by hand): setting a birth year 65 or more years back lowers Sleep Need by
      30 m straight away, and the Readiness popup's Time Asleep reference follows.

## Non-goals (explicitly out of scope)
- Learning Usual Need from the user's own Nights: later, with tuning.
- Naps reducing Sleep Debt or counting toward Time Asleep: Serenix doesn't detect Naps.
- Load raising Sleep Need.
- Sleep Score: its own spec, next, which reads this Sleep Need.
- Showing Sleep Need or Sleep Debt anywhere but the Sleep popup and the Readiness popup's
  reference (no tile, no Trends, no Apple Health).
- Tuning Usual Need, the window, the quarter and the cap against real Nights: after this ships.

## Open questions
- **Every number is an assumption** (8 h, 7.5 h, 65, 7 Nights, ¼, +1 h). Tune them once there are
  a few weeks of real Nights, changing constants and tests together.
- **Age from years only.** The Profile holds a birth year, not a birth date, so a user turns 65 on
  1 January of that year. Accepted: it moves Usual Need by 30 m for at most a year.

## Notes
- Decision: issue #34. Evidence: `docs/research/sleep-need-and-debt.md`. Terms: Usual Need,
  Sleep Need and Sleep Debt (GLOSSARY.md).
- Changes spec 008 (Readiness's Time Asleep input). Spec 002's Sleep popup gains two rows.
- Map: issue #31. Next: the Sleep Score spec (decision: issue #35).
