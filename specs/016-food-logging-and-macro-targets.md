# 016 — Food logging and Macro Targets

**Status:** built
**Last updated:** 2026-11-06
**Issue:** https://github.com/ellismchardy/serenix/issues/49 (Body tab map, spec 2)

## Problem
Serenix shows the user's weight and Weight Goal, but not what they eat. People losing or gaining
weight track calories and protein, fat and carbs somewhere else, against targets they work out
by hand. The adaptive Calorie Target in a later spec is worked out from logged Intake on
Complete Days, so logging has to exist first.

## Goal
Let the user log what they eat as plain numbers (Food Entries) and see each Day's Intake against
a Calorie Target they set and Macro Targets Serenix suggests for their Weight Goal.

## User stories
1. As a user, I want to log a Food Entry with its calories, and its protein, fat and carbs when I
   know them, without searching a food database.
2. As a user, I want to see today's calories and macros against my targets, and how much is
   left.
3. As a user, I want to set my Calorie Target and get protein, fat and carb targets that suit
   losing, gaining or holding weight, and change them if I prefer my own.
4. As a user, I want to mark a Day complete once I've logged everything, so a later estimate of
   my Expenditure only uses Days I logged fully.
5. As a user who forgot, I want to log, edit or delete a Food Entry on any past Day.
6. As a user, I want my food log in the Body data backup, and an older backup to still import.

## Behavior

### Food Entries
- A **Food Entry** has a time, calories (required) and, optionally, protein, fat and carbs in
  grams, and an optional short name (up to 40 characters, e.g. "Lunch").
- Its Day is the local Day of its time, as for Weigh-ins. Entries can be logged on today or any
  past Day, never in the future. The time defaults to now on today, and to 12:00 on a past Day.
- **Limits** (refused with a message): calories 0–5,000 kcal; protein, fat and carbs 0–500 g
  each; a time in the future.
- Calories are always typed. Serenix never works them out from the macros.
- Any Food Entry can be edited or deleted.

### Intake and Complete Days
- A Day's **Intake** is its Food Entries added up: calories, and protein, fat and carbs (a macro
  left blank counts as 0 in the sum).
- Each Day has a **Day complete** toggle, set by the user. A Day with no Food Entries can't be
  marked complete. Editing a Complete Day's entries keeps it complete; deleting its last entry
  makes it no longer complete.

### Calorie Target
- The user sets the **Calorie Target** by hand, in kcal per Day, from 800 to 6,000 (refused
  outside that, with a message). It can be changed or cleared.
- With no Calorie Target, the Food view shows Intake on its own: no targets, no "left".

### Macro Targets
Suggested from the Calorie Target, Trend Weight and the Weight Goal (issue #54,
`docs/research/macro-targets-by-goal.md`):
- **Protein:** 2.2 g per kg when the Weight Goal loses; 1.6 g/kg when it gains or holds, or with no
  Weight Goal. The kg is current Trend Weight, except when the Profile has a height and Trend
  Weight gives a BMI over 30: then it is the weight at BMI 25 for that height.
- **Fat:** 25% of the Calorie Target, at 9 kcal per g.
- **Carbs:** the calories left after protein (4 kcal/g) and fat (9 kcal/g), at 4 kcal per g. If
  that's under 130 g a Day, the Food view warns. If protein and fat use up the whole Calorie
  Target, carbs are 0 and the Food view says so.
- **No Trend Weight** (no Weigh-ins yet): no Macro Targets; the Food view says a Weigh-in is
  needed.
- **Overrides:** the user can set protein and fat in grams instead of the suggestions; carbs
  always fill what's left. An override that leaves carbs below 0 is refused, and so is one
  below 0 g or over 500 g (a Food Entry's macro limits, to catch typos), with or without a
  Calorie Target. "Use suggested" clears both overrides.
- Grams show as whole numbers; working stays unrounded.

### Screen
- The Body tab gains a **Weight | Food** switch at the top; Weight is the screen spec 015 built.
- **Food** shows one Day (today by default; a date picker reaches any past Day):
  - calories: Intake against the Calorie Target, with how much is left or over ("550 left",
    "120 over");
  - three bars, protein, fat and carbs, each against its Macro Target;
  - the carbs warning, when there is one;
  - the Day's Food Entries, newest first, each with its time, name, calories and macros;
  - the Day complete toggle, and a + button that opens the Food Entry sheet.
- A gear opens the targets sheet: Calorie Target, and protein and fat overrides with "Use
  suggested".

### Backup
- The Body data file becomes **version 2**: it adds Food Entries, Complete Days, the Calorie
  Target and the protein and fat overrides. A version 1 file still imports.
- Import keeps spec 015's rules: it asks first with the counts, skips exact duplicates (a Food
  Entry with the same time, name, calories and macros; a Complete Day already complete here), and
  refuses the whole file if any entry is outside the limits above. A file's Calorie Target and
  overrides are used only when none is set here; otherwise they're skipped.
- Food data, like all Body data, is never written to the Sync Log, `os.Logger` or bug reports.

## Design decisions
- **`SerenixCore`: Food view (new).** A pure function: given the Food Entries, Complete Days, the
  Calorie Target and overrides, the Weigh-ins and current Weight Goal, the Profile's height, the
  Day shown, the current time and the time zone, it returns everything the Food view shows: the
  Day's entries and Intake, Macro Targets, left or over, the carbs warning, whether the Day is
  or can be complete, and why an entry or target would be refused. It gets Trend Weight from the
  Body view, so the two can't disagree. Protein's 2.2 and 1.6 g/kg, the BMI 30 and 25 cut-offs,
  fat's 25%, the 4/9/4 kcal per g, the 130 g carbs floor and every limit are named constants
  citing issue #54.
- **`SerenixCore`: Food Entry (new)** value type, in kcal, grams and UTC.
- **`SerenixCore`: Body data file** goes to version 2 as above.
- **Shell.** The Weight | Food switch, the Food view, the Food Entry sheet and the targets sheet.
  Food Entries, Complete Days, the Calorie Target and overrides are Body data (ADR 0008: raw
  entries only, kept forever; Intake and Macro Targets are never stored), in their own store
  file beside the Weigh-ins' one, so a build that knows Weigh-ins but not food never opens it.
- Follows ADR 0002 and ADR 0008. No new ADR.

## Seams under test
- **Food view (`SerenixCore`)**, fed hand-built Food Entries, Complete Days, targets, Weigh-ins,
  a Weight Goal, a height, a Day, a time and a time zone. Catches every rule above: limits,
  Intake sums, Complete Days, Calorie Target, Macro Targets, BMI, overrides, left/over and the
  warnings. Misses drawing, the sheets and saving, checked by hand on the phone (ADR 0002).
- **Body data file (`SerenixCore`)**. Catches the version 2 round trip, add/skip counts for the
  new data, the target rule, refusing out-of-limit entries, and version 1 files still
  importing. Misses the share sheet, the file picker and the store, checked by hand.

## Success criteria (must be checkable)
Food Entries and Intake
- [x] Food Entries of 500 kcal (30 g protein) and 700 kcal (no macros) on one Day give Intake
      1,200 kcal and 30 g protein, 0 g fat, 0 g carbs.
- [x] A Food Entry at 23:30 local time counts on that Day, one at 00:30 on the next.
- [x] A Food Entry over 5,000 kcal, with a macro over 500 g, or in the future is refused with a
      message; one of 0 kcal is accepted.
- [x] A Day with no Food Entries can't be marked complete; deleting a Complete Day's last entry
      leaves it not complete; editing an entry keeps it complete.
Calorie Target and Macro Targets
- [x] A Calorie Target of 799 or 6,001 kcal is refused; 800 and 6,000 are accepted.
- [x] Trend Weight 80 kg, losing, Calorie Target 2,000: protein 176 g, fat 55.6 g (500 kcal),
      carbs 199 g.
- [x] Trend Weight 80 kg, gaining (or holding, or no Weight Goal), Calorie Target 2,000: protein
      128 g, fat 55.6 g, carbs 247 g.
- [x] Trend Weight 100 kg, height 175 cm (BMI 32.7), losing: protein is 2.2 × 76.5625 = 168.4 g;
      with no height it is 220 g.
- [x] Trend Weight 80 kg, losing, Calorie Target 1,500: carbs 105.3 g, with the under-130 g
      warning.
- [x] Trend Weight 100 kg, no height, losing, Calorie Target 1,000: carbs 0 g, with the "protein
      and fat use up the Calorie Target" message.
- [x] With no Weigh-ins there are no Macro Targets; with no Calorie Target there are no targets
      and no "left".
- [x] Overriding protein to 150 g and fat to 70 g at Calorie Target 2,000 gives carbs 192.5 g; an
      override leaving carbs below 0 is refused; "Use suggested" restores 176 g and 55.6 g.
- [x] A protein or fat override of −1 g or 501 g is refused, even with no Calorie Target.
- [x] Intake 1,450 kcal against 2,000 shows 550 left; 2,120 shows 120 over.
Backup
- [x] A version 2 file round-trips Weigh-ins, Weight Goals, Food Entries, Complete Days, the
      Calorie Target and overrides unchanged.
- [x] A version 1 file imports its Weigh-ins and Weight Goals.
- [x] Importing a file whose Food Entries and Complete Days are partly here reports the right add
      and skip counts; a file's Calorie Target is used only when none is set here.
- [x] A file with a Food Entry over 5,000 kcal imports nothing.
Shell (checked by hand on the phone, steps in the PR)
- [ ] The Weight | Food switch shows each view; logging, editing and deleting a Food Entry works,
      on today and on a past Day.
- [ ] The targets sheet sets the Calorie Target and overrides, and "Use suggested" works.
- [ ] The Day complete toggle saves, and survives relaunch.
- [ ] Export then import on a fresh install restores food data too.
- [ ] `swift test` passes and `swift format lint --strict` is clean; the macOS CI job builds.

## Non-goals (explicitly out of scope)
- A food database, barcode scanning, saved or repeated foods.
- Fibre, sugar, sodium, or kJ.
- Water, caffeine and alcohol (the Check-ins spec).
- Working the Calorie Target out from data, Expenditure and Calories Burned (spec 3 of the map).
- Calorie advice when off pace, and Diet Breaks (later specs).
- Writing Intake to Apple Health.

## Open questions
- **Older users' protein:** the research gives at least 1.2 g/kg over 65. Both defaults (1.6 and
  2.2) are already above it, so no separate rule. Assumption: fine; revisit if defaults change.

## Notes
- Spec 015 (weight trend and goals) for Trend Weight, the Body tab and the Body data file.
- ADR 0008 (Body data in its own store). Research: issue #54 and
  `docs/research/macro-targets-by-goal.md`; Complete Days from issue #52.
