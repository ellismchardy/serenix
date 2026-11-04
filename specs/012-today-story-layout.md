# 012 — Today Story layout

**Status:** built
**Last updated:** 2026-11-04

## Problem
The Today screen (spec 002) puts three rings first and the detail below in cards. Some mornings
the user wants to read their Night from top to bottom instead: what happened overnight, what it
means this morning, and how the Day is going. Right now there's only the one layout.

## Goal
The user can switch the Today screen between two layouts in the profile menu: **Rings** (spec
002's layout, the default) and **Story**, a timeline reading Night → this morning → today.

## User stories
1. As a user, I want to pick Story in the profile menu so the Today screen reads as a timeline.
2. As a user, I want my choice kept when I close and reopen Serenix.
3. As a user, I want to move between Days the same way in both layouts (week strip, calendar).
4. As a user, I want to tap a step in the Story to open the same popup Rings would open.
5. As a user with no Night for the Day shown, I want Story to say so and still show that Day's
   Load, as Rings does.
6. As a new user whose Readiness is Calibrating, I want Story to show that instead of a score.

## Behavior
**Setting.** The profile menu gets a **Today layout** choice next to Appearance: **Rings** or
**Story**. Rings until changed. The choice is kept on the phone across relaunches and applies at
once.

**What stays the same.** In Story, everything above the body is spec 002's: the top bar
(avatar, greeting, calendar, bell), the week strip, the sync pill and pull-to-sync. Which Day
is shown, and switching to today when Serenix comes back to the foreground, are also 002's.
Only the part below the week strip changes.

**Story body.** A vertical timeline of up to four steps, each a coloured dot on a line with a
small time label, a title, and a card:
1. **Sleep** (accent dot). Time label: Sleep Onset → Final Wake, in local time (e.g. "23:18 →
   06:51"). Title: "You slept" + Time Asleep (e.g. "You slept 7h 12m"). Card: the Sleep Score in
   a small ring, "<Time Asleep> of <Sleep Need> needed", and Sleep Efficiency as a percentage.
   Tapping it opens the Sleep popup.
2. **Overnight** (lighter accent dot). Time label: "Overnight". Title: "Nightly Metrics". Card:
   one row per Nightly Metric the Night has (Sleeping HR, HRV, respiratory rate, skin
   temperature, SpO2), each with its value, unit and Zone, the Zone as a pill in its colour.
   A metric the Night lacks has no row. Tapping a row opens that metric's popup.
3. **This morning** (band-coloured dot). Time label: "This morning". Title: "Readiness <n> —
   <band word>" (e.g. "Readiness 72 — Ready"). Body: the same advice text as 002's Readiness
   message, without the ✕. Tapping it opens the Readiness popup. While Readiness is
   Calibrating, the title is "Readiness calibrating — n/4" and there's no advice.
4. **Today so far** (amber dot). Time label: "Today so far" on today, "That Day" on an earlier
   Day. Title: "Load <n>". Card: a bar of the Day's Load against the user's typical Load, the
   Day's Resting HR when it has one. Tapping it opens the Load popup.

There are no rings and no vs your Baseline card in Story: the Zone pills carry that.

**No Night for the Day.** Steps 1–3 are replaced by 002's message ("No Night yet" on today, "No
Night recorded" on an earlier Day); step 4 still shows the Day's Load.

**Look.** The Look and Appearance are 002's: cards, accent and Zone colours, light and dark.

## Design decisions
- **Today view (SerenixCore)** gains the Story's content: the steps to show for the Day, in
  order, each with its time label and title text, and which popup a tap opens. Rings and Story
  draw from the same Today view, so the numbers can't disagree. The values are the ones the
  Today view already works out (Time Asleep, Sleep Need, Sleep Score, Zones, Readiness band and
  advice, Load); no new metric.
- **Today layout setting** is a shell preference kept in on-device storage beside Appearance,
  like 002's Appearance. Choosing it doesn't touch SerenixCore.
- **Today screen (shell)** draws either body under the shared top bar and week strip. The Story
  body is a new view; the popups are 002's / 006's / 010's / 011's, reused.

## Seams under test
- **Today view** (the existing SerenixCore seam, spec 002) — catches which Story steps show,
  their order, time labels, titles, Calibrating and no-Night cases, and which popup each tap
  opens; misses drawing, the setting's storage and taps reaching the popups.
- The shell (the setting, drawing, taps, Dark appearance) is checked by hand on the phone, with
  the steps listed in the PR (ADR 0002).

## Success criteria (must be checkable)
- [x] Today view tests: with a Night, the Story has the steps Sleep, Overnight, This morning,
      Today so far, in that order.
- [x] Today view tests: the Sleep step's time label is Sleep Onset → Final Wake in local time
      ("23:18 → 06:51") and its title is "You slept 7h 12m" for that Time Asleep.
- [x] Today view tests: the Overnight step lists only the Nightly Metrics the Night has, each
      with its Zone.
- [x] Today view tests: the This morning title is "Readiness 72 — Ready" for Readiness 72, and
      "Readiness calibrating — 2/4" with no advice when Calibrating with 2 Nights.
- [x] Today view tests: with no Night for the Day, the Story is 002's no-Night message plus the
      Load step; the Load step's time label is "Today so far" on today and "That Day" on an
      earlier Day.
- [x] Today view tests: each step (and each Overnight row) names the popup a tap opens: Sleep,
      the metric's, Readiness, Load.
- [x] `swift test` passes and `swift format lint` is clean.
- [ ] On the phone: the profile menu shows Today layout with Rings and Story; Rings is selected
      on a fresh install.
- [ ] On the phone: choosing Story changes the Today screen at once; after closing and
      reopening Serenix it is still Story.
- [ ] On the phone: in Story, the top bar, week strip, calendar, sync pill and pull-to-sync work
      as in Rings, and tapping each step opens the popup named above.
- [ ] On the phone: Story looks right in both Light and Dark appearance.

## Non-goals (explicitly out of scope)
- Any layout other than Rings and Story (the other prototype concepts B, D–J).
- A drawn Night timeline (sleep bar) inside the Sleep step card; the Sleep popup has one.
- Changing Rings (spec 002) in any way.
- Story-specific wording that judges the Night (e.g. "You recovered well"); titles are factual.
- Rearranging, hiding or reordering steps.

## Open questions
- Assumption: the This morning step has no ✕, since in Story it's a step, not a dismissable
  message; closing 002's Readiness message has no effect on Story.
- Assumption: the "That Day" time label for a past Day's Load step. A better label is welcome.

## Notes
- Design: prototype variant C, "Story timeline" (`?variant=C`, branch `prototype/homescreen-v2`,
  `src/SerenixApp/Prototype/home-screen-v2-prototype.html`). The spec keeps 002's top bar and
  week strip, which the prototype left out.
- Related: 002 (Today screen), 006 (Load popup), 008 (Readiness), 009 (Sleep Need), 010 (Sleep
  Score and Sleep popup), 011 (Metric popup).
