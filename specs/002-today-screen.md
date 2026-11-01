# 002 — Today screen

**Status:** approved
**Last updated:** 2026-11-01

## Problem
Once History Sync (spec 001) gets History Records onto the phone, the user still has nowhere
to see what they mean. The point of Serenix is to open the app in the morning and see at a
glance how they slept, how ready they are, and whether anything is off against their own
normal, then dig into one number when it looks wrong.

## Goal
Opening Serenix shows the Today screen: last night's Readiness, Sleep Score, Load, Time Asleep
and Nightly Metrics, each compared against the user's Baseline. The user can step back through
earlier Days, open a detail popup for any number, and reach Strap status and Debug from a
profile menu.

## User stories
1. As a Strap owner, I want to see last night's Readiness as one big number and word, so that
   I know at a glance how hard to push today.
2. As a Strap owner, I want each Nightly Metric coloured by its Zone, so that I can spot the
   one that is off without reading every number.
3. As a Strap owner, I want to see how HRV and Resting HR compare to my Baseline, so that I
   understand why Readiness is what it is.
4. As a Strap owner, I want to step back through earlier Days, so that I can look at a past
   Night the same way.
5. As a new Strap owner with fewer than 4 Nights, I want to see that Serenix is Calibrating and
   how far along it is, rather than scores that mean nothing yet.
6. As a Strap owner who didn't wear the Strap, or whose sync hasn't finished, I want the screen
   to say there's no Night yet, not show yesterday's Night as today's.
7. As a Strap owner, I want to tap any number for more detail, so that I can see where it came
   from.
8. As a Strap owner, I want the Strap's connection, battery and last sync in one menu, along
   with Sync now and Debug.

## Behavior
**Which Day is shown.** Serenix opens on today: the local calendar Day of the current time. The
header shows "Today" and the date (e.g. "Sun 1 Nov"); other Days show their date and "Night".
‹ moves one Day earlier and › one Day later. Arrows move by Day, not by Night. ‹ is disabled on
the Day of the earliest Night, and › on today. The Night shown is the one dated that Day
(GLOSSARY: dated by the local date of its Final Wake).

**No Night for the Day.** On today, "No Night yet". On an earlier Day, "No Night recorded". Both
still show that Day's Load. Serenix never shows another Day's Night in its place.

**Top row.** On the left, a sync pill showing the History Sync state from spec 001:
- **Connecting:** "Connecting…".
- **Syncing:** "Syncing", with 001's progress bar and time left shown under the pill.
- **Up to date:** "Synced HH:mm", the time the last sync finished.
- **Failed:** "Sync failed". Tapping it shows the reason and a Retry button.

Tapping the pill when no sync is running starts one (001's "Sync now"). On the right, a profile
icon opens the profile menu.

**Rings.** Three rings, all 0–100 (ADR 0005):
- **Readiness**, in the middle and largest. It shows the number with "Readiness" under it, and
  the band word below the ring: **Ready** (67–100), **Steady** (34–66), **Take it easy** (0–33).
  The ring and word take the band's colour: green, amber, red. When Readiness is Calibrating,
  the ring is empty and shows "n/4", the Nights so far.
- **Sleep Score** on the left.
- **Load** on the right, labelled "Load so far" on today and "Load" on earlier Days.

**vs your Baseline.** HRV and Resting HR, each with its value, its difference from Baseline,
and a bar showing which way it moved from Baseline:
- HRV's difference is a whole-number percentage, e.g. "+14%".
- Resting HR's difference is in whole bpm, e.g. "−3 bpm".

The bar is green when the move is the good way: HRV up, Resting HR down. It is red otherwise.
When either Baseline is Calibrating, this section is one line instead: "Calibrating. Readiness
starts once 4 Nights form your Baseline. N to go."

**Tiles.** Under a heading of "Last night" (today) or the Day's date, six tiles in a 2-column
grid:
- **Time Asleep:** shows "7h 40m", Sleep Onset → Final Wake ("22:45 → 06:57"), and a trend line
  of the last 7 Nights. Tapping it opens the Sleep popup.
- **One tile per Nightly Metric**, in this order: Resting HR, HRV, respiratory rate, skin
  temperature, SpO2. Each shows the value with its unit, and a trend line of the last 7 Nights
  up to the Night shown. The value and the line under it take the colour of the metric's Zone.
  The line under the value is:
  - **Resting HR, HRV, respiratory rate, skin temperature:** the difference from Baseline,
    formatted as above. Respiratory rate and skin temperature are signed, to one decimal place,
    e.g. "+0.4".
  - **SpO2:** the Zone's level in words: "95% or above", "Below 95%", "Below 92%".

A metric whose Baseline is Calibrating shows white with "Calibrating" and has no Zone. SpO2
needs no Baseline, so it has a Zone from the first Night.

**Zones.** These are worked out on unrounded values. They are named constants and assumptions,
to be tuned once real Nights exist (see Open questions):

| Metric | In range (green) | Watch (amber) | Out of range (red) |
|---|---|---|---|
| HRV, d = (value − Baseline) / Baseline | d ≥ −5% | −15% ≤ d < −5% | d < −15% |
| Resting HR, d = value − Baseline (bpm) | d ≤ 1 | 1 < d ≤ 4 | d > 4 |
| Respiratory rate, \|value − Baseline\| (br/min) | ≤ 0.5 | ≤ 1.0 | > 1.0 |
| Skin temperature, \|value − Baseline\| (°C) | ≤ 0.3 | ≤ 0.6 | > 0.6 |
| SpO2, fixed levels (%) | ≥ 95 | 92 ≤ value < 95 | < 92 |

**Baseline.** For a given Night and metric, the Baseline is the **median** of that metric over
the up-to-14 most recent *earlier* Nights that have a value for it. With an even count it is the
mean of the two middle values. The Night shown is never part of its own Baseline. An earlier
Night is compared against its own Baseline, not today's. A metric's Baseline is Calibrating
until at least 3 earlier Nights have it, so the 4th Night with a value is the first with a
Baseline (docs/architecture.md: "calibrating until 4 Nights exist"). SpO2 has no Baseline.

**Missing values.** A score or Nightly Metric that the Night doesn't have shows "—" with no Zone
and no colour, as do Time Asleep and Load. Examples: no SpO2 Window, or a score whose spec hasn't
shipped yet. A missing value is skipped in trend lines and in Baseline, never counted as 0.

**Popups.** Each slides up over the screen and closes on a tap outside or a swipe down. Each
one describes the Night shown:
- **Readiness** (from the Readiness ring) shows:
  - the number and band word
  - HRV and Resting HR, each with value, Baseline (whole numbers) and difference
  - Sleep Score
  - "Baseline: your last N Nights"

  When Calibrating, it explains instead that Readiness needs 4 Nights to form a Baseline, and
  how many there are so far.
- **Sleep** (from the Sleep Score ring and the Time Asleep tile) shows:
  - Sleep Score
  - Time in Bed, as start–end and duration
  - Sleep Onset and Final Wake
  - Time Asleep
  - minutes awake within the Sleep Period: Final Wake − Sleep Onset − Time Asleep
- **Nightly Metric** (from its tile) shows:
  - the value and difference, or the SpO2 level, coloured by Zone
  - its values for the Night shown and up to 13 earlier Nights, as a chart and as a list of the
    5 most recent
  - the Baseline and its In range limits, drawn as a band, for metrics with a Baseline

Tapping the Load ring does nothing in this spec.

**Profile menu.** It slides up nearly full height, with a Done button, and contains:
- **Strap:** model ("Whoop 5.0"), connection ("Connected" or "Not found"), battery level, and
  when the last sync finished. Battery and model come from 001's handshake.
- **Sync now**, labelled **Retry sync** after a failed sync. It does the same as 001's Sync now.
- **Debug:** opens 001's debug screen, unchanged.
- **Footer:** app version, "MIT licensed", "Not affiliated with WHOOP, Inc."

Later specs add their own rows: Apple Health, Export data, Contact us, Report a bug, Write a
review.

**Formats.** Clock times are local, as "HH:mm" (24-hour). Durations are shown as "7h 40m". Units
are bpm, ms, br/min, °C and %. Respiratory rate and skin temperature have one decimal place; the
other metrics are whole numbers.

## Design decisions
- **`SerenixCore`: Baseline.** Given a Night and the earlier Nights, it returns, for each of
  Resting HR, HRV, respiratory rate and skin temperature, either the median or Calibrating
  (with the count so far). It is pure. The Readiness spec reuses it.
- **`SerenixCore`: Zone.** Given a metric, its value and its Baseline (none for SpO2), it
  returns In range, Watch or Out of range. The cut-offs are named constants, each commented with
  its unit and "assumption: from the 002 prototype, tune with real Nights".
- **`SerenixCore`: Today view.** One pure function. It takes:
  - the stored Nights (Nightly Metrics, Time Asleep, Sleep Onset, Final Wake, Time in Bed,
    Sleep Score and Readiness, any of which may be missing)
  - the Days with their Load
  - the Day to show
  - the current time and time zone
  - the History Sync state

  It returns a value describing everything above: the header and whether each arrow is enabled,
  the sync pill, the rings, vs your Baseline, the tiles with their trend-line values and Zones,
  and the content of each popup. It decides; it doesn't draw. Colours are not in it, only bands
  and Zones.
- **iOS shell: Today screen, popups, profile menu.** SwiftUI. It draws the Today view's output,
  maps band and Zone to colour, and sends taps back. It takes over 001's main screen, and the
  profile menu takes over 001's settings screen. 001's debug screen is reached from the menu.
- **Scores are inputs.** How Sleep Period, Nightly Metrics, Time Asleep, Sleep Score, Readiness
  and Load are worked out is each its own spec. Until one ships, its value is missing and shows
  "—", so this screen can be built before them.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own names, 0–100). No new ADR: every
  choice here is easy to change later.

## Seams under test
- **Today view (`SerenixCore`)**, fed hand-built Nights and Days with known values and a fixed
  current time. It catches which Day and Night are shown, arrows, "No Night yet / recorded",
  bands, Calibrating counts, Baseline (median, earlier Nights only, at least 3, missing values
  skipped), every Zone boundary, difference formats, Load "so far", trend-line values, missing
  values, popup content and the sync pill text. It misses layout, colours, taps, animation and
  the Strap facts in the menu, which are checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`, on Windows and in CI). Expected values are literals worked out by hand:
- [ ] With Nights dated 30 Oct and 1 Nov and the current time 1 Nov 08:12, the view shows the
      1 Nov Night under "Today" with › disabled; one step earlier shows 31 Oct as "No Night
      recorded" with that Day's Load; one more shows 30 Oct's Night with ‹ disabled.
- [ ] With no Night dated today, the view shows "No Night yet" and today's Load, and no other
      Day's values.
- [ ] Readiness 67 is Ready, 66 and 34 are Steady, 33 is Take it easy.
- [ ] Baseline for HRV over earlier values 50, 70, 60, 58 is 59 (even-count median); over 50,
      70, 60 it is 60.
- [ ] Baseline uses at most the 14 most recent earlier Nights: with 20 earlier Nights, the 6
      oldest change nothing.
- [ ] The Night shown is not in its own Baseline: changing its HRV changes its Zone but not its
      Baseline.
- [ ] An earlier Night's Baseline comes from Nights before it only: adding a newer Night leaves
      it unchanged.
- [ ] A metric with 2 earlier Nights is Calibrating ("Calibrating", no Zone); with 3, it has a
      Baseline.
- [ ] Earlier Nights missing a metric are skipped for that metric's Baseline and trend line, and
      don't count towards its 3.
- [ ] HRV against Baseline 60: 57 (−5%) is In range, 56.9 is Watch, 51 (−15%) is Watch, 50.9 is
      Out of range, 90 is In range.
- [ ] Resting HR against Baseline 52: 53 is In range, 53.1 is Watch, 56 is Watch, 56.1 is Out of
      range, 45 is In range.
- [ ] Respiratory rate against Baseline 14.0: 14.5 and 13.5 are In range, 15.0 is Watch, 15.1
      and 12.9 are Out of range.
- [ ] Skin temperature against Baseline 34.0: 34.3 is In range, 33.6 is Watch, 34.7 is Out of
      range.
- [ ] SpO2: 95 is In range, 94 and 92 are Watch, 91 is Out of range, including on a Night with
      no earlier Nights.
- [ ] Differences format as "+14%" for HRV, "−3 bpm" for Resting HR, and "+0.4" for respiratory
      rate and skin temperature; the SpO2 tile reads "95% or above", "Below 95%" or "Below 92%".
- [ ] A missing Nightly Metric, score, Time Asleep or Load shows "—" with no Zone.
- [ ] Load on today is labelled "Load so far"; on an earlier Day, "Load".
- [ ] When either Baseline is Calibrating, vs your Baseline is the single Calibrating line with
      the right "N to go".
- [ ] Each tile's trend line holds the 7 most recent Nights up to the Night shown, oldest first,
      without missing values.
- [ ] The Sleep popup's minutes awake equal Final Wake − Sleep Onset − Time Asleep.
- [ ] The Nightly Metric popup holds the Night shown and up to 13 earlier Nights, plus the
      Baseline and In range limits (none for SpO2).
- [ ] The sync pill reads "Connecting…", "Syncing", "Synced 08:10" or "Sync failed" for each
      History Sync state, and carries the failure reason.

Manual, on the iPhone with the sideloaded CI build (steps listed in the PR):
- [ ] After a sync with real Nights, the Today screen shows the rings, vs your Baseline and six
      tiles, with values matching the Today view's output for that data.
- [ ] Zone colours show green, amber and red as given, and the Readiness ring and word share the
      band colour.
- [ ] ‹ and › step through Days, and are disabled at the earliest Night and at today.
- [ ] Tapping the Readiness ring, the Sleep Score ring, the Time Asleep tile and each metric tile
      opens the right popup; a tap outside or a swipe down closes it; the Load ring does
      nothing.
- [ ] During a sync, the pill reads Syncing with 001's progress bar and time left under it; a
      failed sync's pill shows the reason and Retry restarts it.
- [ ] The profile icon opens the menu with the Strap's model, connection, battery and last sync;
      Sync now starts a sync; Debug opens 001's debug screen; Done closes the menu.
- [ ] All of 001's manual checks still pass with the main screen replaced by the Today screen.

## Non-goals (explicitly out of scope)
- How Sleep Period, Nightly Metrics, Time Asleep, Sleep Score, Readiness and Load are computed.
  Each is its own spec.
- The tab bar. It arrives with the Sleep screen spec.
- The Sleep screen, with its week strip and heart rate through the night, and the Trends screen.
  Both are later specs, already prototyped (see Notes).
- A Load popup with hourly Load; it belongs to the Load spec.
- Profile menu rows for Apple Health, Export data, Contact us, Report a bug and Write a review.
  Each comes with its own spec.
- Editing, deleting or hiding a Night; Naps; Stress.
- Notifications, widgets, or a Watch app.

## Open questions
- **Zone cut-offs** are the prototype's placeholders. Tune them once there are a few weeks of
  real Nights, and change the constants and their tests together.
- **Light mode.** The prototype is dark only. Assumption: the screen follows iOS light/dark,
  with the same band and Zone colours in both.
- **Write a review.** It needs the App Store, which needs the Apple Developer Program (ADR 0003).
  When its spec comes, it may link to GitHub instead.
- **Before `/plan`:** spec 001 must be merged first. This spec takes over 001's main and
  settings screens, and the plan builds on them.

## Notes
- Prototype: branch `prototype/homescreen`, file `src/SerenixApp/Prototype/home-screen-prototype.html`.
  Open it with `?variant=E`.
  - **Today:** the Today tab, including its popups and the profile menu with Debug.
  - **Sleep screen (later):** the Sleep tab.
  - **Trends screen (later):** the Trends tab.
  - **Load popup with hourly bars (later):** opens from the Load ring.

  Variants A–D are the four layouts E was combined from: A for rings and date arrows, B for the
  Readiness hero and Baseline bars, C for the tiles and the Sleep screen, D for Trends.
- Glossary changes in this spec: Baseline now covers respiratory rate and skin temperature, not
  SpO2. New terms: Time Asleep and Zone.
- Related: `specs/001-history-sync.md` (on `feat/history-sync` until it merges).
