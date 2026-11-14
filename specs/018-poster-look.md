# 018 — Poster look

**Status:** approved 2026-11-10; Body section revised 2026-11-14 for the shipped Body tab, awaiting approval
**Last updated:** 2026-11-14

## Problem
Serenix's look (spec 002, Look: light grey, white rounded cards, soft shadows, a purple accent)
reads as soft and calm. The owner wants it to feel like a performance tool: bold, direct,
numbers first. Prototyping (branch `prototype/performance-home`) chose concept **M**, a
Swiss-poster style, over eleven alternatives, and carried it to the Sleep and Body tabs.

## Goal
Every main tab (Today, Sleep, Body) is drawn in the Poster look, in light and dark, and each
tab's headline number carries a short verdict telling the user where they stand.

## User stories
1. As a user, I want the Today screen to lead with my Readiness as a huge number and a verdict
   (e.g. "GO HARD.") so that I know at a glance how hard to push.
2. As a user, I want the Sleep tab to lead with Sleep Score and a verdict, and the Body tab to
   lead with Trend Weight (Weight) or Intake (Food) the same way.
3. As a user in dark mode, I want the same layout on black, so that the Appearance setting still
   works.
4. As a user on Story layout (spec 013), I want Story drawn in the Poster look too.
5. As a user whose Readiness is Calibrating or missing, or who has no Night, no Weight Goal or
   nothing logged, I want no verdict rather than a wrong one.

## Behavior
**Replaces spec 002's Look.** The Look becomes the Poster look everywhere in the three tabs,
their popups and sheets. Nothing a tab shows, computes, or does on tap changes; only how it is
drawn. Rings and Story (spec 013) both remain, drawn in the Poster look.

**The Poster look.**
- **Paper:** off-white background (light) or near-black (dark), with type in the opposite colour.
  No cards, rounded corners or shadows: sections are separated by a full-width heavy rule
  (2 pt) with the section's name in small bold type on the left and an optional note on the
  right; rows inside a section by hairline rules.
- **Masthead:** a 6 pt rule across the top with "Serenix · <tab>" on the left and the Day
  (weekday and date) on the right.
- **Headline:** the tab's headline number in very large, tight, bold type, with its verdict
  beside it in condensed bold italic capitals in the accent colour, and a one-line caption under
  it.
- **Colour:** one accent, signal red. Band and Zone colours stay green, amber and red, shown as
  solid tags (white text on the colour) at the right of a row. Nothing else is coloured.
- **Tab bar:** Today, Sleep, Body as three equal cells under a heavy rule; the current tab is a
  solid block in the type colour with the paper colour as text.
- **Dark:** the same layout, paper and type swapped; red, green and amber unchanged.

**Verdicts.** Every headline has one, in capitals, ending with a full stop. A verdict about the
user's state is in the accent red; a **waiting verdict** (not enough data yet) is in the
secondary type colour, so it never reads as a warning:
- **Readiness** (Today) by band: Ready "GO HARD.", Steady "HOLD STEADY.", Take it easy
  "EASE OFF.". Waiting: Calibrating "N TO GO." with the Nights still needed (e.g. "2 TO GO.";
  the headline shows "n/4"); missing (no HRV) "NO HRV."; no Night "NO NIGHT.".
- **Sleep Score** (Sleep): 67–100 "STRONG NIGHT.", 34–66 "FAIR NIGHT.", 0–33 "ROUGH NIGHT.".
  Waiting: no Night "NO NIGHT."; tonight, before it's slept, "TONIGHT."
- **Weight** (Body): pace badge On pace "ON PACE.", A bit behind "A BIT BEHIND.", Off pace
  "OFF PACE.", Too fast "TOO FAST."; hold goal In band "IN BAND.", Above band "ABOVE BAND.",
  Below band "BELOW BAND.". Waiting: Settling in "SETTLING IN.", no Weight Goal "NO GOAL.", no
  Weigh-in "NO WEIGH-IN.".
- **Intake** (Food): under Calorie Target "ON TARGET." (within 10% of it) or "UNDER." / "OVER."
  beyond 10% either side, only on a Complete Day or a past Day; today before it's complete
  "LOGGING."; nothing logged "NOTHING LOGGED.". With no Calorie Target, "LOGGED." when anything
  is.

**Today.** Masthead and week strip, then: Readiness headline (Calibrating shows "n/4" in place
of the number). Then a **Load** section: the Day's Load as a large red number beside a bar from
0 to twice typical Load with a tick at typical Load, and spec 006's sentence as its note; with
no typical Load yet, the number alone. Then Sleep Score and Time Asleep side by side, then the
Nightly Metrics as rows (name, value, tag with the difference from Baseline in the Zone colour).
Taps open the same popups as today. The Readiness message keeps its text and ✕, drawn as a
ruled section.

**Sleep.** Sleep Score headline, caption from spec 012's Summary sentence. Then Time Asleep,
Sleep Need, Sleep Debt in three columns (Sleep Debt in red when over zero). Then spec 012's
sections in its order, each as a ruled section: the Night's chart (Heart Rate Trace in red,
Wake Bouts as amber columns, dotted Sleeping HR line), Your week (each Night a solid bar, short
Time Asleep in amber), What stood out (rows with tags), Tonight (a solid block in the type
colour).

**Body.** Weight | Food switch as a two-cell segmented bar under a heavy border. Weight: Trend
Weight headline with unit and pace verdict; chart (Trend Weight line in red, Weigh-ins as grey
dots, next Milestone dashed in green); Weekly Rate and Goal side by side; Milestones as a
segmented progress bar and rows; Weigh-ins. Food: Intake headline, a red bar toward Calorie
Target, Macro Targets as rows with thin bars and "N to go" tags, Food Entries, Mark Complete
Day and a red + button.

**Popups.** Each popup is a sheet of paper over the dimmed screen, with a short heavy grab bar,
the masthead (popup name left, the Night or Day right), a headline with verdict, then its
existing sections as ruled sections. Contents and order are those of their specs; only the
drawing changes:
- **Readiness** (spec 012): Readiness headline and band verdict, caption the band's advice; the
  band scale as three flat segments (the Night's at full colour) with a marker and a "usual 70"
  tick; Why as rows (name, value, points as a tag, a thin gauge under each); Your week as flat
  bars, the Day shown in the type colour.
- **Sleep Score** (spec 010): Sleep Score headline and verdict; Sleep Sufficiency, Sleep
  Efficiency and Sleep Consistency as rows with a big number and a thin bar each (in place of
  nested rings); Time Asleep as a red bar with a marker at Sleep Need; the Sleep Period
  timeline with Time in Bed in grey and usual times as dashed green lines.
- **Load** (spec 006): the Day's Load headline with a Load verdict (below), caption spec 006's
  sentence and the last-sync line; the bar against typical Load; How hard as one split bar and
  HR Zone rows; When as hourly stacked bars; Highest HR and Max HR used under a heavy rule.
  Live HR keeps its place.
- **Nightly Metric and Resting HR** (spec 011): the value headline with a metric verdict
  (below), caption spec 011's verdict sentence; the Zone scale as flat segments with a marker
  and a Baseline tick; Last 14 Nights as flat blocks (the Night shown outlined); Baseline,
  Lowest, Highest in three columns; the metric's text.
- **Sheets** (Weigh-in, Weight Goal, Food Entry, Macro Targets): fields as ruled rows, the
  primary button a solid block in the type colour, a destructive one in red.

Popup verdicts: **Load** under 0.8 × typical "EASIER DAY.", 0.8 to under 1.2 "USUAL DAY.", 1.2
to under 1.5 "HARDER DAY.", 1.5 and over "MUCH HARDER." (spec 006's bands); waiting: no typical
Load "LEARNING.", no Load "NO LOAD.". **Nightly Metric** In range "ABOUT USUAL.", Watch
"UNUSUAL.", Out of range "WAY OFF."; SpO2 "HEALTHY.", "A BIT LOW.", "LOW."; waiting:
Calibrating "N TO GO.", missing "NO DATA.". **Resting HR** has no Zone, so no verdict.

## Design decisions
- **Verdicts in `SerenixCore`.** One pure mapping from Readiness band, Sleep Score and pace
  badge to the verdict text (or none). The shell only draws it. No new stored data.
- **Theme in the shell.** The app's Theme is replaced by the Poster palette and type scale
  (paper, ink, accent red, rule widths, headline/verdict/label fonts), adaptive for light and
  dark. Shared shell pieces: masthead, ruled section header, tag, headline-with-verdict, tab
  bar. Each tab composes these; no tab draws a card.
- **Fonts:** system SF fonts (heavy/condensed italic widths via SwiftUI), so no bundled fonts.
- Score names and scales unchanged (ADR 0005).

## Seams under test
- **Verdict mapping in `SerenixCore`** (input: band / score / pace badge state; output: text or
  none) — catches every threshold, wording and none-case; misses how it is drawn.
- **Hand check on the phone** (ADR 0002) for the shell, with the steps in the PR — catches the
  look in light and dark on all three tabs; misses nothing automatable.

## Success criteria (must be checkable)
- [ ] Readiness Ready, Steady, Take it easy give "GO HARD.", "HOLD STEADY.", "EASE OFF.";
      Calibrating with 2 of 4 Nights, missing and no Night give the waiting verdicts
      "2 TO GO.", "NO HRV.", "NO NIGHT.".
- [ ] The Load popup's verdict follows spec 006's sentence bands: under 0.8 "EASIER DAY.",
      0.8–1.2 "USUAL DAY.", 1.2–1.5 "HARDER DAY.", 1.5 and over "MUCH HARDER."; no typical Load
      gives waiting "LEARNING."; no Load gives waiting "NO LOAD.".
- [ ] A Nightly Metric popup's verdict is "ABOUT USUAL." (In range), "UNUSUAL." (Watch), "WAY
      OFF." (Out of range); for SpO2 "HEALTHY.", "A BIT LOW.", "LOW."; Calibrating gives
      waiting "N TO GO." and a missing value waiting "NO DATA.".
- [ ] Sleep Score 67, 34 and 33 give "STRONG NIGHT.", "FAIR NIGHT.", "ROUGH NIGHT."; no Night
      gives waiting "NO NIGHT.", tonight gives waiting "TONIGHT.".
- [ ] Each pace badge and hold state gives its verdict; Settling in, no Weight Goal and no
      Weigh-in give waiting "SETTLING IN.", "NO GOAL.", "NO WEIGH-IN.".
- [ ] Intake at 90%, 110%, 89% and 111% of Calorie Target on a Complete Day gives "ON TARGET.",
      "ON TARGET.", "UNDER.", "OVER."; today not complete gives waiting "LOGGING."; no Food
      Entries gives waiting "NOTHING LOGGED."; no Calorie Target with entries gives "LOGGED.".
- [ ] Every verdict is marked either a state verdict or a waiting verdict, and every waiting
      verdict above is marked waiting.
- [ ] `swift test` and `swift format lint --strict` pass; the macOS CI job builds the app.
- [ ] On the phone, in Light and in Dark: Today (Rings and Story), Sleep, Body Weight and Body
      Food show the masthead, headline with verdict, ruled sections, tags and the block tab bar,
      with no rounded cards or shadows, and no purple anywhere.
- [ ] On the phone, Today's Load section shows the Day's Load against a tick at typical Load, and
      the number alone while typical Load is learned.
- [ ] On the phone, every tap that opened a popup or sheet before still opens the same one.

## Non-goals (explicitly out of scope)
- A Load target or suggested Load range (prototype concept M showed one; it needs its own spec).
- Keeping the old look as a choice.
- New metrics, rankings or detected workouts seen in other prototype concepts.
- Bundled custom fonts.
- Onboarding (spec 014) and the Debug view: restyled only as far as the shared Theme reaches.

## Open questions
- Sleep Score verdict thresholds (67 / 34) borrow Readiness's band edges; Sleep Score has no
  bands of its own (spec 010). Assumed fine; confirm.
- Verdict wording, especially "EASE OFF." and "ROUGH NIGHT.". Assumed as written.

## Notes
- Prototype: branch `prototype/performance-home`, file
  `src/SerenixApp/Prototype/performance-home-prototype.html`, variants M (Today), MW (Today,
  waiting verdict), MS (Sleep), MB (Body Weight), MF (Body Food), PR / PS / PL / PM (Readiness,
  Sleep Score, Load and HRV popups). Not merged.
- Changes the Look of spec 002; restyles specs 012, 013, 015, 016 without changing their
  behaviour.
