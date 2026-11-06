# 015 — Weight trend and goals

**Status:** built
**Last updated:** 2026-11-05
**Issue:** https://github.com/ellismchardy/serenix/issues/49 (map; decisions #50, #51, #59, #60, #61)

## Problem
Serenix knows the user's nights and days from the Strap, but nothing about their body weight.
People who want to lose, gain or hold weight use a separate app for a smoothed trend, a goal and
a pace. That app can't use the Strap's data, which later Body
specs need (Expenditure, Deficit Check). Weight is the base those specs build on.

## Goal
The user logs Weigh-ins on a new **Body** tab, sees their Trend Weight, and sets a Weight Goal to
lose, gain or hold, with a Pace checked against how fast Trend Weight is really moving and
warnings when that Pace is too fast.

## User stories
1. As a user, I want to log a Weigh-in in a couple of taps so that logging every morning is easy.
2. As a user, I want my Trend Weight to ignore daily water swings so that one salty meal doesn't
   make me think I've gained.
3. As a user losing weight, I want to set a Goal Weight and a Pace (as a rate or as a date) so
   that I know how fast to go and when I'll get there.
4. As a user, I want a warning when my Pace is faster than is sensible, without being stopped.
5. As a user, I want to see whether I'm on pace, and only after the first weeks' water drop has
   settled, so that the badge isn't wrong in week one.
6. As a user who has been off pace for a week, I want to be offered an easier goal.
7. As a user gaining weight (or holding it), I want goals and warnings that fit that.
8. As a user, I want Milestones, a projected date and progress so I can see how far I've come.
9. As a user who weighs in irregularly, I want gaps handled honestly: no invented weights.
10. As a user in the UK or US, I want my weight in st and lb or lb.
11. As a user, I want to back up all my Body data to a file and restore it, because a deleted
    sideload would otherwise lose it.
12. As a user who mistyped, I want to edit or delete any Weigh-in.

## Behavior

### Weigh-ins
- The **+** button opens a field with the last Weigh-in's weight filled in, and an editable date
  and time (now by default). A Weigh-in can't be in the future, and must be 20–350 kg (or the
  same in lb); anything else is refused with a message.
- A Weigh-in is kept in UTC; its Day is the local date it was taken (the current time zone).
- A Day can hold several Weigh-ins. The **lowest** on a Day is the one that counts; the others are
  kept and listed.
- The **Weigh-in list** shows every Weigh-in, newest first, each editable and deletable.

### Trend Weight
- Trend Weight starts at the first counted Weigh-in. At each later counted Weigh-in `w`, with `Δd`
  Days since the previous one: `T = T_prev + α·(w − T_prev)`, `α = 1 − 0.9^Δd` (so one Day gives
  0.1, the Hacker's Diet step; 3 Days gives 0.271). Issue #50.
- Days without a Weigh-in get no Trend Weight point: nothing is invented.
- After a gap of **more than 14 Days**, Trend Weight restarts at the new Weigh-in, and the chart's
  line breaks there.
- Trend Weight is never stored (ADR 0008); it's worked out each time.

### Weekly Rate
- Weekly Rate is the latest Trend Weight minus the Trend Weight at the last counted Weigh-in on
  or before 7 Days earlier, per week. It needs counted Weigh-ins at least 7 Days apart and no
  restart between them; otherwise there's none. (Not 28 days: Trend Weight is already smoothed.
  Issue #61.)

### Weight Goal
- A Weight Goal **loses**, **gains** or **holds**. Lose or gain comes from Goal Weight against
  Start Weight. Start Weight and the start date default to the current Trend Weight and today,
  and can be changed.
- **Lose and gain** have a **Pace**, chosen one of two ways:
  - **By rate:** losing 0.25, 0.5, 0.75 or 1.0 kg a week (lb units: 0.5, 1, 1.5, 2 lb); gaining
    0.1, 0.25 or 0.5 kg a week (lb units: 0.25, 0.5, 1 lb). Each option shows its share of
    current Trend Weight and its band's colour.
  - **By date:** the Pace is what reaches Goal Weight from the current Trend Weight by that date,
    worked out each time it's shown. The date can't be earlier than the date a 1%-a-week Pace
    would reach Goal Weight. Two quick picks offer the dates for 0.5% and 0.75% a week.
- **Pace bands** (as a share of current Trend Weight per week; issue #51):

  | | Sustainable | Aggressive (warn) | Too fast |
  |---|---|---|---|
  | Lose | ≤ 0.5% | > 0.5% to 1% | > 1% |
  | Gain | ≤ 0.5% (aim 0.25–0.5%) | > 0.5% to 1% | > 1% |

  Gaining's "Too fast" above 1% is our own call: no source sets a gain cap. Warnings never block
  saving.
- **Hold** has a band of ±1 kg around Goal Weight (editable from 0.5 to 3 kg in 0.5 kg steps) and
  no Pace, projection or Milestones. It shows **In band**, **Above band** or **Below band** from
  Trend Weight.
- Changing Goal Weight (same direction) or the Pace edits the Weight Goal. Changing direction
  (lose, gain, hold) ends it and starts a new one. Removing a Weight Goal ends it. Ended Weight
  Goals are kept (ADR 0008).

### Pace badge (lose and gain)
- **Settling in** while the Weight Goal is under 14 Days old **or** Weigh-ins span under 14
  Days: the cards say "Settling in, day N of 14" and still show Weekly Rate.
- After that, with Weekly Rate in the goal's direction as a share of Pace:
  - **On pace** — 90% of Pace or more (and not Too fast)
  - **A bit behind** — 60% to under 90%
  - **Off pace** — under 60%, zero, or the wrong direction
  - **Too fast** — over 125% of Pace **and** over 0.5% of Trend Weight a week
- **Ease the goal:** when the badge has been Off pace or Too fast on each of the last 7 Days, the
  Rate card offers: for a rate Pace, the next slower rate option (Off pace) or the rate nearest
  Weekly Rate (Too fast); for a date Pace, moving the date to the projected date (never earlier
  than the 1%-a-week date). It offers nothing that would leave the goal as it is. Those 7 Days
  count only from the Day the Weight Goal was last changed, so each edit (easing included) gets
  a full week before the next offer.

### Progress
- **Milestones**: every 1, 2 or 5 kg (lb units: 2, 5 or 10 lb), at whole multiples of the step
  between Start Weight and Goal Weight. One is passed when Trend Weight reaches it.
- **Progress** shows the share of the way from Start Weight to Goal Weight (0–100%), the change
  since start, and how much is left to go.
- **Reached**: when Trend Weight reaches Goal Weight (at or below for lose, at or above for gain),
  the Weight Goal is Reached and ends, a short celebration shows, and one tap starts a hold
  Weight Goal at that weight. A single Weigh-in past Goal Weight isn't enough on its own.
  - The celebration also offers **Undo**, since a mistyped Weigh-in can pull Trend Weight past
    Goal Weight. Undo reopens the Weight Goal as it was. A reopened goal is Reached again only
    once Trend Weight has been back on Start Weight's side of Goal Weight on a Day after the
    Undo, so it doesn't end again at once before the Weigh-in is fixed.
  - A lose or gain Weight Goal whose Goal Weight Trend Weight has already reached (at or above
    Trend Weight to lose, at or below to gain) can't be saved: "Your Trend Weight is already
    past this Goal Weight."
- **Projected date**: today plus the weeks Trend Weight needs at Weekly Rate. Shown only after
  Settling in, with Weekly Rate non-zero and toward Goal Weight. The Goal card shows it beside
  the **planned date** (the chosen date, or for a rate Pace, today plus the weeks left at Pace).

### Screen
- The **Body** tab joins the tab bar after Sleep and holds the weight screen only (prototype
  variant B): Trend Weight large, the last Weigh-in, change since start, the chart, then the
  Rate and Goal cards and the Milestones card. A gear opens the Weight Goal sheet.
- Chart ranges: 1W, 1M, 3M, 6M, All. Dots are counted Weigh-ins; the line is Trend Weight; a
  dashed line marks Goal Weight; "All" extends to the projected date with a dashed projection.
- **Empty and early states:** no Weigh-ins → "Log your first Weigh-in" and the + button, no
  chart; one Weigh-in → the number and one dot, no line; no Weight Goal → a "Set a goal" card in
  place of the goal cards.

### Units and Profile
- The Profile gains **Height** (cm, or ft and in) and **Units**: kg (default), lb, or st and lb.
- Weights show to one decimal: "82.4 kg", "181.7 lb", "12 st 13.7 lb". Everything is stored in
  kg; Units only change the display.

### Backup and import
- **Export** writes all Body data (Weigh-ins and Weight Goals, current and ended) to one JSON
  file, shared through the share sheet.
- **Import (JSON)** reads that file and asks first: "Add N Weigh-ins and M Weight Goals? K
  already here will be skipped." It adds to what's there; an exact duplicate (same time and
  weight, or the same Weight Goal) is skipped. A file that can't be read imports nothing and says
  why.
- Body data is never written to the Sync Log, `os.Logger` or bug reports.

## Design decisions
- **`SerenixCore`: Body view (new).** A pure function: given the Weigh-ins, the Weight Goals,
  the Profile's units, the current time and the time zone, it returns everything the weight
  screen shows: Trend Weight points with breaks, Weekly Rate, Settling in or the pace badge, the
  Pace band for the current Pace and for each rate option, the earliest allowed date and the
  quick-pick dates, Milestones, progress, projected and planned dates, Reached, whether to offer
  Ease the goal and with what, the hold band state, and every weight formatted in the chosen
  units. The step 0.9, the 14-Day restart, the 7-Day Weekly Rate, the 14-Day Settling in, the
  badge's 90% / 60% / 125% / 0.5% thresholds, the Pace bands and the 7-Day Ease the goal
  window are named constants, each citing its issue and research note.
- **`SerenixCore`: Weigh-in and Weight Goal (new)** value types, in kg and UTC. A Weight Goal
  holds its direction, Start Weight, start date, Goal Weight, Pace (rate or date) or hold band,
  Milestone step, and when it ended and why (Reached, changed, removed).
- **`SerenixCore`: Body data file (new).** Encodes all Body data as versioned JSON
  (`format`, `version: 1`) and decodes it; given the current data and a decoded file, returns
  what an import would add and skip. Errors are typed; nothing partial is returned.
- **`SerenixCore`: Profile** gains an optional height (cm) and Units.
- **Shell.** A new Body tab with the weight screen, the Weigh-in sheet, the Weight Goal sheet and
  the Weigh-in list; the Profile menu gains Height and Units, and Export / Import rows. Body data
  lives in its own SwiftData store, apart from History Records and Nights (ADR 0008). The shell
  passes stored values to the Body view and saves what the user enters; it decides nothing.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0008 (storage). No new ADR.

## Seams under test
- **Body view (`SerenixCore`)**, fed hand-built Weigh-ins and Weight Goals, units, a time and a
  time zone. Catches every rule above: Trend Weight and gaps, Weekly Rate, Pace bands, the
  badge and Settling in, Ease the goal, Milestones, progress, Reached, projection, hold, and
  unit formatting. Expected values are literals worked out from issue #50's formula. Misses
  drawing, the sheets and saving, checked by hand on the phone (ADR 0002).
- **Body data file (`SerenixCore`)**. Catches a lossless JSON round trip, the add/skip counts and
  duplicate rule, and unreadable files. Misses the share sheet, the file picker and writing to the store, checked by hand.

## Success criteria (must be checkable)
Weigh-ins and Trend Weight
- [x] Weigh-ins on consecutive Days of 80.0 then 79.0 kg give Trend Weight 80.0 then 79.9.
- [x] Weigh-ins of 80.0 then, 3 Days later, 79.0 kg give Trend Weight 79.729 (α 0.271).
- [x] With two Weigh-ins on one Day, only the lower one moves Trend Weight; both are listed.
- [x] Days without a Weigh-in have no Trend Weight point.
- [x] A Weigh-in 15 Days after the previous one restarts Trend Weight at its own value and marks
      a break; one 14 Days after does not.
- [x] A Weigh-in under 20 kg, over 350 kg or in the future is refused with a message.
Weekly Rate and badge
- [x] Trend Weight falling 0.5 kg over the last 7 Days gives Weekly Rate −0.5 kg a week; with no
      counted Weigh-in 7 or more Days before the latest, there is no Weekly Rate.
- [x] A Weight Goal 13 Days old shows Settling in, day 13 of 14, and no badge; at 14 Days (with
      Weigh-ins spanning 14 Days) it shows a badge.
- [x] With a lose Pace of 0.5 kg a week, Weekly Rate −0.45 is On pace, −0.44 is A bit behind,
      −0.29 is Off pace, +0.1 is Off pace.
- [x] At Trend Weight 80 kg and Pace 0.5 kg a week, Weekly Rate −0.63 is Too fast (over 125% and
      over 0.4 kg); at Trend Weight 140 kg and Pace 0.5, Weekly Rate −0.65 is On pace (under
      0.5% of 140 kg).
- [x] Ease the goal is offered only when the badge was Off pace or Too fast on each of the last 7
      Days; 6 Days is not enough.
- [x] After a Weight Goal is changed (easing included), Ease the goal waits for 7 Days counted
      from that change before it's offered again.
Pace and warnings
- [x] At Trend Weight 80 kg, a lose Pace of 0.25 kg is Sustainable, 0.5 kg (0.625%) Aggressive,
      1.0 kg (1.25%) Too fast; each rate option reports its share and band.
- [x] A gain Pace of 0.5 kg at 80 kg (0.625%) warns; 1.0 kg (1.25%) is Too fast; 0.25 kg is
      Sustainable.
- [x] A date Pace's earliest allowed date is the one a 1%-a-week Pace reaches Goal Weight by; the
      quick picks are the 0.5% and 0.75% dates.
- [x] A Pace in the Aggressive or Too fast band can still be saved.
Progress and goals
- [x] Start 88 kg, Goal 78 kg, step 2 kg gives Milestones 86, 84, 82, 80 (78 is the goal); at
      Trend Weight 83.9, 86 and 84 are passed.
- [x] Start 88, Goal 78, Trend Weight 83 shows 50% of the way, 5.0 kg lost, 5.0 kg to go.
- [x] Trend Weight reaching Goal Weight marks the Weight Goal Reached and ended, and offers a
      hold Weight Goal at that weight; a raw Weigh-in below Goal Weight with Trend Weight above it
      does not.
- [x] Undo after Reached reopens the Weight Goal; with Trend Weight still past Goal Weight it
      isn't Reached, and it is Reached again only after Trend Weight has been back on Start
      Weight's side on a Day after the Undo.
- [x] At Trend Weight 80 kg, a lose goal to 80 or 82 kg and a gain goal to 80 or 78 kg are
      refused as already reached; a lose goal to 79.9 kg can be saved.
- [x] The projected date is hidden during Settling in and when Weekly Rate is zero or away from
      Goal Weight; at 83 kg, Goal 78, Weekly Rate −0.5 it is 10 weeks after today.
- [x] A hold Weight Goal at 78 ± 1 kg shows In band at 78.9, Above band at 79.1, Below band at
      76.9, and has no badge, projection or Milestones.
- [x] Changing direction ends the Weight Goal and starts a new one; the ended one is kept.
Units
- [x] 82.4 kg shows as "82.4 kg", "181.7 lb" and "12 st 13.7 lb"; lb-unit Milestone steps are 2,
      5 and 10 lb.
Backup and import
- [x] Exporting then importing into empty Body data gives back identical Weigh-ins and Weight
      Goals.
- [x] Importing a file into data that already holds some of it reports the right add and skip
      counts and adds only the new entries.
- [x] A truncated or wrong-format file imports nothing and returns a typed error.
Shell (checked by hand on the phone, steps in the PR)
- [ ] The Body tab appears after Sleep; logging, editing and deleting Weigh-ins works; the Weight
      Goal sheet saves both Pace kinds and hold.
- [ ] After logging Weigh-ins, installing and opening a build from another branch, then
      reinstalling this one, every Weigh-in and Weight Goal is still there (ADR 0008).
- [ ] Height and Units in the Profile menu change the display only.
- [ ] Export shares a JSON file; importing it on a fresh install restores the data.
- [ ] `swift test` passes and `swift format lint --strict` is clean; the macOS CI job builds.

## Non-goals (explicitly out of scope)
- Calorie advice when off pace, Intake, Expenditure, Calories Burned (spec 3 of the map).
- Diet phases and Diet Breaks (later; the Deficit Check spec).
- Body measurements, body fat %, progress photos, weigh-in reminders (spec 1b).
- Reading weigh-ins from Apple Health or smart scales; writing to Apple Health (waits for the
  Health export).
- CSV export for a coach or doctor, and importing from other apps.
- Look-ahead smoothing that revises past Trend Weight.
- Food, Check-ins and blood pressure on the Body tab (their own specs).

## Open questions
- **Travel.** A Weigh-in's Day uses the time zone current when the Body view runs, as Nights and
  Days do. Assumption: good enough; revisit if it bites.

## Notes
- Map: [Wayfinder: Body tab](https://github.com/ellismchardy/serenix/issues/49); decisions in
  #50 (trend), #51 (safe rate), #59 (names), #60 (storage), #61 (scope).
- Research: `docs/research/trend-weight-smoothing.md`, `docs/research/safe-rate-of-weight-change.md`.
- ADRs: 0002 (pure core, thin shell), 0008 (Body data in its own store).
- Prototype: variant B of `src/SerenixApp/WellnessPagePrototype.html` on the unmerged branch
  `prototype/wellness-page` (local only, not pushed): the weight-first layout, goal sheet, pace
  warnings and badge. Its calorie-advice card is out of scope here.
