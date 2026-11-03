# 011 — Metric popup

**Status:** built
**Last updated:** 2026-11-03 (built; by-hand checks carried to the PR)

## Problem
Tapping a Nightly Metric tile opens a line chart and a list of five numbers (spec 002). It
shows that a value moved, but not whether the move matters: the In range band is a faint
green stripe, Watch and Out of range don't appear at all, and nothing says what the metric is
or what tends to change it. Resting HR has no popup at all (spec 007), so its tile is the only
one that does nothing.

## Goal
Each metric tile (Sleeping HR, Resting HR, HRV, respiratory rate, skin temperature and SpO2)
opens a popup that shows where the value sits among the user's Zones, says in a sentence what
that means, shows the last 14 Nights at a glance, and explains what the metric is and what
moves it.

## User stories
1. As a Strap owner, I want to see last night's value on a scale of Out of range, Watch and In
   range with my Baseline marked, so that I can tell at a glance how unusual it was.
2. As a Strap owner, I want one plain sentence saying whether the value is about usual,
   unusual, or well outside my usual, so that I don't have to read the scale.
3. As a Strap owner, I want the last 14 Nights as coloured blocks, so that I can see whether
   this is a one-off or a run.
4. As a Strap owner, I want my Zones as exact ranges in the metric's unit, so that I know what
   number would count as Watch or Out of range for me.
5. As a Strap owner new to these metrics, I want a short description of what the metric is and
   what tends to move it, so that I know what to make of a change.
6. As a new Strap owner whose Baseline is still Calibrating, I want the popup to say how many
   more Nights it needs, not show a scale it can't fill.
7. As a Strap owner with a Night missing a value, I want the popup to say so rather than show
   a guess.
8. As a Strap owner, I want to tap Resting HR and see its last 14 Days and what it is, even
   though it has no Zone.

## Behavior
**Opening.** Tapping a Nightly Metric tile opens that metric's popup for the Night shown, as
in spec 002. Tapping the Resting HR tile now opens the Resting HR popup for the Day shown
(replacing spec 007's "no popup"). Both slide up and close like spec 002's popups.

**Nightly Metric popup, top to bottom.**
1. **Heading:** the metric's icon and name, and "Night of 2–3 Nov" (the evening before the
   Night's date, then its date).
2. **Value and pill:** the value as on the tile ("49 ms", or "—"), and a pill holding the
   tile's status word ("Low", "Normal", "Below 95%", …). The pill has a ✓ and the Zone's colour,
   or is plain grey text with no Zone (Calibrating or missing).
3. **Zone scale**, shown only when the value has a Zone: a horizontal bar of Zone segments, the
   Night's segment at full colour and the others faded, a marker at the value labelled with
   it, and a tick under the bar at the Baseline labelled "Baseline 62" (no tick for SpO2).
   Positions run 0 to 1, left to right, and are clamped to 0–1, so a value past an end sits at
   the end:
   - HRV and respiratory rate: 0.5 + z / (2 × 3.75), z as in spec 004.
   - Sleeping HR: 0.5 + d / (2 × 7.5), d = value − Baseline in bpm.
   - Skin temperature: 0.5 + d / (2 × 0.9), d = value − Baseline in °C.
   - SpO2: (value − 88) / 12.

   Each end is 1.5× as far from the Baseline as Out of range starts. The segments are fixed per
   metric:

   | Metric | Segments, left to right (from–to position) |
   |---|---|
   | HRV | Out of range 0–0.1667, Watch 0.1667–0.3, In range 0.3–0.8333, Watch 0.8333–1 |
   | Respiratory rate | Out of range 0–0.1667, Watch 0.1667–0.3, In range 0.3–0.7, Watch 0.7–0.8333, Out of range 0.8333–1 |
   | Sleeping HR | In range 0–0.7, Watch 0.7–0.8333, Out of range 0.8333–1 |
   | Skin temperature | Out of range 0–0.1667, Watch 0.1667–0.3333, In range 0.3333–0.6667, Watch 0.6667–0.8333, Out of range 0.8333–1 |
   | SpO2 | Out of range 0–0.3333, Watch 0.3333–0.5833, In range 0.5833–1 |

4. **Verdict sentence:**
   - With a Zone and a Baseline: the tile's difference, then "against your Baseline:", then
     "about usual for you." (In range), "unusual for you." (Watch) or "well outside your
     usual." (Out of range), e.g. "−21% against your Baseline: unusual for you." The last words
     are in the Zone's colour.
   - SpO2: "A healthy level." (In range), "A little low." (Watch), "Low." (Out of range).
   - Calibrating: "Calibrating: Serenix needs 3 earlier Nights with HRV to know what's usual
     for you (2 so far)." (the metric's name, and the earlier Nights that have it).
   - Missing value: "No HRV for this Night." (the metric's name).
5. **Last 14 Nights:** under that heading, 14 blocks in a row, one for the Night shown's date
   and each of the 13 dates before it, oldest on the left, each labelled with its weekday
   initial. A block takes its Night's Zone colour, judged against that Night's own Baseline as
   its tile was (spec 004). It is grey for a Night with a value but no Zone (Calibrating), and
   hatched where there is no Night or no value. The Night shown's block is outlined. Blocks
   can't be tapped.
6. **Facts:** Baseline (as a value with its unit, or "Calibrating"), Lowest and Highest. Lowest
   and Highest are over the values in the 14 blocks, formatted as on the tile, "—" with none.
   SpO2 shows only Lowest and Highest.
7. **What it is:** the metric's text from the table below.
8. **Your Zones,** shown when the Night has a Baseline, and always for SpO2: headed "Your Zones ·
   Baseline 62 ms" ("Zones" for SpO2), three rows, In range, Watch and Out of range, each with
   its Zone colour and its range from this Night's Baseline (and Spread), rounded as the
   metric's values are shown. The row of the Night's Zone is bold with "← this Night". With no
   value, no row is marked. A cut-off value belongs to the row the spec 004 table gives it.

   | Metric | In range | Watch | Out of range |
   |---|---|---|---|
   | HRV (L, H the In range band; W = exp(ln Baseline − 2.5 × Spread)) | "L–H ms" | "W–L ms, or above H ms" | "under W ms" |
   | Respiratory rate (L, H the band; W1, W2 = Baseline ∓ 2.5 × Spread) | "L–H br/min" | "W1–L or H–W2 br/min" | "under W1 or above W2 br/min" |
   | Sleeping HR (B = Baseline) | "under B+3 bpm" | "B+3 to B+5 bpm" | "B+5 bpm and up" |
   | Skin temperature (B = Baseline) | "B−0.3 to B+0.3 °C" | "B−0.6 to B−0.3 or B+0.3 to B+0.6 °C" | "under B−0.6 or above B+0.6 °C" |
   | SpO2 | "95% and up" | "92% to 95%" | "under 92%" |

9. **What moves it:** the metric's list from the table below, as bullets.

**Resting HR popup, top to bottom.** Spec 007's Resting HR has no Baseline or Zone, so its
popup is the same layout without anything that needs one:
1. Heading: the heart icon, "Resting HR" and the Day's date ("Today" on today).
2. The value as on the tile ("57 bpm" or "—"). No pill and no Zone scale.
3. Sentence: on today, "So far today. A stiller moment later today can still lower it."; on an
   earlier Day, none; with no Resting HR, "No Resting HR for this Day."
4. **Last 14 Days:** 14 blocks for the Day shown and the 13 Days before, all one neutral colour,
   hatched for a Day with no Resting HR; the Day shown is outlined.
5. Facts: Lowest and Highest over those Days.
6. What it is, and What moves it, from the table below. No Your Zones.

**Text.** Fixed per metric; the same every Night.

| Metric | What it is | What moves it |
|---|---|---|
| Sleeping HR | Your lowest sustained heart rate while asleep. Lower than usual is fine; a rise of a few bpm over your Baseline often comes with a late meal, alcohol, illness or hard training. | Alcohol · A late, heavy meal · Illness coming on · Hard training the day before · A warm bedroom |
| Resting HR | Your lowest sustained heart rate on a Day while awake and still, outside your Sleep Period. Load is worked out against it. It has no Baseline or Zone, so it isn't coloured. | Caffeine · Stress · How still you were during the Day · Fitness, over weeks |
| HRV | How much the time between your heartbeats varies while you sleep, as RMSSD. It's personal, so compare it only with your own Baseline. Higher than usual is generally a good sign; a drop well below it is worth noticing. | Alcohol · Short or broken sleep · Illness · Hard training · Stress |
| Respiratory rate | Breaths per minute while you sleep. It barely changes from Night to Night, so even a small rise above your Baseline stands out. | Illness, especially of the chest or airways · Being at altitude · Alcohol |
| Skin temperature | The temperature of the skin under the Strap while you sleep. Only the change from your Baseline matters: the number itself depends on the room, your bedding and how the Strap sits. | Fever or illness · The menstrual cycle · Room temperature and bedding · How tightly the Strap is worn |
| SpO2 | How much oxygen your blood is carrying, measured in short SpO2 Windows while you sleep. It's judged against fixed levels, not a Baseline. | Being at altitude · Pauses in breathing during sleep · A loose Strap |

**Gone.** The Nightly Metric popup's line chart, In range band and list of the 5 most recent
values (spec 002) are replaced by the above.

## Design decisions
- **`SerenixCore`: Nightly Metric popup** (the Today view's popup content, reshaped). For the
  Night shown it gives: value text, status word and Zone; the scale (its segments, the value's
  position and the Baseline's position, or none); the verdict text and which Zone colours its
  last words; 14 blocks (weekday initial and one of: a Zone, no Zone, or no value); the facts;
  the Zones heading and three rows (Zone, range text, marked or not), or none; and the two
  texts. It decides; it doesn't draw. It reuses spec 004's Zone, Baseline, Spread and In range
  limits, and each earlier Night's Zone comes from that Night's own Baseline, as its tile did.
- **`SerenixCore`: Zone** gains the scale position and segments per metric, and the Watch and
  Out of range limits for the Zones rows, as named constants next to the existing cut-offs
  (the 1.5× ends, SpO2's 88 to 100 scale).
- **`SerenixCore`: Resting HR popup (new),** from the Today view: value text, sentence, 14 Day
  blocks (initial, has a value or not), facts and the two texts, from the stored Days' Resting
  HR.
- **The metric texts** live in `SerenixCore` with the popup content, like the Readiness advice.
- **iOS shell:** draws both popups and maps Zone to colour, as for the tiles. The Resting HR
  tile opens its popup. Nothing new is stored.
- Supersedes spec 002's Nightly Metric popup and spec 007's "no popup" for the Resting HR tile.

## Seams under test
- **`SerenixCore` Today view** (its Nightly Metric and Resting HR popup content) — catches every
  number, position, segment, block, Zone row, sentence and text, and which Night or Day each
  block is; misses drawing, colours, layout and the tap, which are checked by hand on the phone
  (ADR 0002).

## Success criteria (must be checkable)
Nightly Metric popup (Today view):
- [x] HRV 48 against Baseline 60 with the typical Spread (0.15) has position 0.30 (to 2 dp),
      the In range segment, Baseline at 0.5, and verdict "−20% against your Baseline: about
      usual for you."
- [x] HRV against Baseline 60 with the typical Spread has Zones rows "48–87 ms", "41–48 ms, or
      above 87 ms" and "under 41 ms".
- [x] HRV 200 against Baseline 60 is Watch at position 1 (clamped), verdict ending "unusual for
      you."
- [x] Sleeping HR 57 against Baseline 52 is Out of range at position 0.8333 (to 4 dp), verdict
      "+5 bpm against your Baseline: well outside your usual.", and its Zones rows are "under 55
      bpm", "55 to 57 bpm" (unmarked) and "57 bpm and up" (marked).
- [x] Sleeping HR 40 against Baseline 52 is In range at position 0.
- [x] Respiratory rate with spec 004's seven Nights (Baseline 14.0, Spread 0.59304) has Zones
      rows "13.1–14.9 br/min", "12.5–13.1 or 14.9–15.5 br/min" and "under 12.5 or above 15.5
      br/min".
- [x] Skin temperature against Baseline 33.8 has Zones rows "33.5 to 34.1 °C", "33.2 to 33.5 or
      34.1 to 34.4 °C" and "under 33.2 or above 34.4 °C"; 34.3 is Watch at position 0.7778 (to 4
      dp).
- [x] SpO2 93 is Watch at position 0.4167 (to 4 dp), with no Baseline position, verdict "A
      little low.", facts Lowest and Highest only, and Zones heading "Zones" with rows "95% and
      up", "92% to 95%" (marked) and "under 92%".
- [x] Each metric's segments are exactly the table's, whatever the Night.
- [x] A Calibrating HRV with 2 earlier Nights has no scale and no Zones rows, a status word
      "Calibrating" with no Zone, verdict "Calibrating: Serenix needs 3 earlier Nights with HRV
      to know what's usual for you (2 so far).", and Baseline fact "Calibrating".
- [x] A Night missing HRV, with a Baseline, has value "—", no scale, verdict "No HRV for this
      Night.", and Zones rows with none marked.
- [x] The blocks are the Night shown's date and the 13 dates before it, oldest first, with
      weekday initials; with Nights on only 12 of those dates, 2 blocks have no value; a Night
      with a value but Calibrating has no Zone.
- [x] An earlier Night that was Watch against its own Baseline is a Watch block, even when it
      would be In range against the Night shown's Baseline.
- [x] Lowest and Highest are over the 14 blocks' values only, formatted as on the tile; "—" when
      none have a value.
- [x] Each metric's What it is and What moves it are exactly this spec's text.

Resting HR popup (Today view):
- [x] Today's popup has the sentence "So far today. A stiller moment later today can still lower
      it."; an earlier Day's has none; a Day with no Resting HR has value "—" and "No Resting HR
      for this Day."
- [x] Its 14 blocks are the Day shown and the 13 Days before, oldest first, with no Zone, and no
      value for a Day with no Resting HR; Lowest and Highest are over those Days.
- [x] It has no pill, scale, Baseline or Zones rows, and Resting HR's two texts.

By hand on the phone:
- [ ] Tapping each of the five Nightly Metric tiles opens its popup, and tapping the Resting HR
      tile opens the Resting HR popup; both close on a tap outside or a swipe down.
- [ ] The scale shows the Night's segment at full colour and the others faded, the marker at the
      value and the Baseline tick under the bar; the verdict's last words and the pill are in
      the Zone colour; blocks are coloured by Zone, grey, or hatched; the Night shown is
      outlined.
- [ ] Both popups read well in Light and Dark appearance.

## Non-goals (explicitly out of scope)
- A Baseline or Zone for Resting HR.
- Tapping a block to see an earlier Night (pick it in the week strip instead).
- A chart of more than 14 Nights, or trends over weeks (the later Trends screen).
- Text that changes with the user's values, sex or age, or any medical advice.
- Changing tiles, Zones, Baselines or Spreads (spec 004).

## Open questions
- None blocking. The metric texts are a first draft for the owner to edit at review.

## Notes
- Prototype: branch `prototype/vital-signs-popup`,
  `src/SerenixApp/Prototype/vitals-popup-prototype.html?variant=E` (variant B's Zone scale and
  blocks, with variant D's verdict, Zones table and texts). The scale ends, exact Zones rows,
  and per-Night block colours were settled after the prototype.
- Builds on specs 002 (popups), 004 (Baseline, Spread, Zones), 007 (Resting HR).
