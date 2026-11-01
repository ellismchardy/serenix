# 002 — Today screen

**Status:** built
**Last updated:** 2026-11-01

## Problem
Once History Sync (spec 001) gets History Records onto the phone, the user still has nowhere
to see what they mean. The point of Serenix is to open the app in the morning and see at a
glance how they slept, how ready they are, and whether anything is off against their own
normal, then dig into one number when it looks wrong.

## Goal
Opening Serenix shows the Today screen: a greeting by name, then last night's Readiness, Sleep
Score, Load, Time Asleep and Nightly Metrics, each compared against the user's Baseline. The
user can pick an earlier Day, open a detail popup for any number, and reach their Profile,
Strap status and Debug from a profile menu. Sync shows itself only when there's something to
say.

## User stories
1. As a Strap owner, I want to see last night's Readiness as one big number and word, so that
   I know at a glance how hard to push today.
2. As a Strap owner, I want each Nightly Metric coloured by its Zone, so that I can spot the
   one that is off without reading every number.
3. As a Strap owner, I want to see how HRV and Resting HR compare to my Baseline, so that I
   understand why Readiness is what it is.
4. As a Strap owner, I want to pick an earlier Day and jump back to today, so that I can look
   at a past Night the same way.
5. As a new Strap owner with fewer than 4 Nights, I want to see that Serenix is Calibrating and
   how far along it is, rather than scores that mean nothing yet.
6. As a Strap owner who didn't wear the Strap, or whose sync hasn't finished, I want the screen
   to say there's no Night yet, not show yesterday's Night as today's.
7. As a Strap owner, I want to tap any number for more detail, so that I can see where it came
   from.
8. As a Strap owner, I want the Strap's connection, battery and last sync in one menu, along
   with Sync now and Debug.
9. As a Strap owner, I want Serenix to greet me by name, without an account or anything leaving
   my phone.
10. As a Strap owner, I want to see that a sync worked, or why it didn't, without a status taking
    up the screen the rest of the time.

## Behavior
**Which Day is shown.** Serenix opens on today: the local calendar Day of the current time. The
Night shown is the one dated that Day (GLOSSARY: dated by the local date of its Final Wake).

**Top bar.** On the left, the Day's date as a large title (e.g. "Sun 1 Nov") with a ▾. Tapping
it opens a date picker running from the Day of the earliest Night to today (just today when
there are no Nights); picking a Day shows it. Next to the title, a **Today** pill shows on any
Day other than today, and tapping it goes back to today. On the right, the profile avatar (see
Profile) opens the profile menu. There are no ‹ › arrows.

**Greeting.** On today, under the top bar: "Good morning", "Good afternoon" or "Good evening",
followed by ", " and the Profile name when there is one (e.g. "Good morning, Ellis"). Morning is
05:00–11:59, afternoon 12:00–17:59 and evening 18:00–04:59, local time. Earlier Days have no
greeting.

**No Night for the Day.** On today, "No Night yet". On an earlier Day, "No Night recorded". Both
still show that Day's Load. Serenix never shows another Day's Night in its place.

**Sync pill.** History Sync (spec 001) shows as a pill that slides down over the top of the
screen only when there's something to say:
- **Syncing:** grey, with a spinner, while connecting or syncing; 001's progress bar and time
  left show under it ("Starting…" until there's progress). It stays up until the sync ends.
  Tapping it offers Cancel (001's Cancel).
- **Sync successful:** green, with a ✓, when a sync finishes. It slides away after 3 seconds.
- **Sync paused:** amber, with a ⚠, when the Strap couldn't be reached: not found, Bluetooth
  off or not allowed, or the Strap disconnected mid-sync. Its detail adds "Serenix will try
  again next time you open it."
- **Sync failed:** red, with a ✕, when the sync failed for any other reason (e.g. a bad Frame
  or an error from the Strap).

Paused and failed stay up until tapped or swiped away; tapping shows the reason and a Retry
button. With no sync running and none just finished, no pill shows, and a sync the user
cancels shows none either. Which pill shows, and
whether a failure is paused or failed, is decided by the Today view; how long a pill stays up
is the shell's. Pulling down on the Today screen starts a sync (001's Sync now) unless one is
running.

**Rings.** Three rings, all 0–100 (ADR 0005):
- **Readiness**, in the middle, the same size as the other two. It shows the number, with
  "Readiness" and then the band word below the ring: **Ready** (67–100), **Steady** (34–66),
  **Take it easy** (0–33).
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
grid. Tiles have no trend line; a metric's history is in its popup.
- **Time Asleep:** shows "7h 40m" and Sleep Onset → Final Wake ("22:45 → 06:57"). It has no
  Zone and no gauge. Tapping it opens the Sleep popup.
- **One tile per Nightly Metric**, in this order: Resting HR, HRV, respiratory rate, skin
  temperature, SpO2. Each shows the metric's name with an icon, the value with its unit, a
  status word with a ✓, and a vertical gauge. The status word and the gauge take the colour of
  the metric's Zone.
  - **Status word:** "Normal" when In range. Otherwise "Low" or "High", by which side of the
    Baseline the value is on: HRV below Baseline is "Low"; Resting HR above Baseline is "High";
    respiratory rate and skin temperature are "Low" below Baseline and "High" above. SpO2 shows
    its level instead: "95% or above", "Below 95%", "Below 92%".
  - **Gauge:** a position from 0 (bottom) to 1 (top), clamped. For metrics with a Baseline, the
    Baseline sits at 0.5 and the Watch limit on each side at the ends: 0.5 + d / (2 × limit),
    with d signed and the limit from the Zone table (HRV: d as a fraction of Baseline, limit
    0.15; Resting HR: 4 bpm; respiratory rate: 1.0; skin temperature: 0.6). SpO2 runs on a
    fixed scale from 88% (0) to 100% (1).

A metric whose Baseline is Calibrating shows white with "Calibrating" and an empty gauge, and
has no Zone. SpO2 needs no Baseline, so it has a Zone from the first Night.

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
shipped yet. A missing Nightly Metric's tile has an empty gauge. A missing value is skipped in
popup charts and in Baseline, never counted as 0.

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

**Profile.** The user's name, kept only on the phone (GLOSSARY). On first launch, before the
Today screen, Serenix asks "What should we call you?" with a name field, Continue and Skip; it
never asks again, whichever is chosen. The name is trimmed of spaces; a blank name counts as
none. It can be added or changed from the profile menu. It is never sent anywhere, and never
appears in the Sync Log, a shared log or any report.

The **avatar** is a circle with the first letter of the name, upper-cased; with no name it
shows a person icon. It appears in the top bar and, larger, at the top of the profile menu.

**Profile menu.** It slides up nearly full height, with an ✕ to close it, and contains, as
rounded, grouped rows:
- **Header:** the large avatar and the name under it, or "Add your name" with no name. Tapping
  it edits the name.
- **Strap:** a "Connected" row with the Strap's model on the right ("Not found" before a Strap
  is paired), battery level, and when the last sync finished ("Sun 1 Nov 08:10", 24-hour).
  "Connected" means a Strap is paired with Serenix; each sync connects to it. Battery and model
  come from 001's handshake. Then **Sync now**, labelled **Retry sync** after a failed or paused
  sync; it does the same as 001's Sync now.
- **Debug:** opens 001's debug screen.
- **Footer:** app version, "MIT licensed", "Not affiliated with WHOOP, Inc."

Later specs add their own rows and sections: Integrations (Apple Health), Export data, Contact
us, Report a bug, Write a review.

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
  - the History Sync state, with what kind of failure it was (the Strap couldn't be reached, or
    another reason) and its reason
  - the Profile name, if any

  It returns a value describing everything above: the title, the date picker's range and whether
  the Today pill shows, the greeting, the avatar's letter and the menu header's name, the sync
  pill, the rings, vs your Baseline, the tiles with their status words, gauge positions and
  Zones, and the content of each popup. It decides; it doesn't draw. Colours and how long a pill
  stays up are not in it, only bands, Zones and which pill.
- **iOS shell: Today screen, popups, profile menu, name prompt.** SwiftUI. It draws the Today
  view's output, maps band and Zone to colour, times the sync pill, and sends taps back. It
  keeps the Profile name in on-device storage and tells the Today view what kind of sync failure
  happened. It takes over 001's main screen, and the profile menu takes over 001's settings
  screen. 001's debug screen is reached from the menu.
- **Scores are inputs.** How Sleep Period, Nightly Metrics, Time Asleep, Sleep Score, Readiness
  and Load are worked out is each its own spec. Until one ships, its value is missing and shows
  "—", so this screen can be built before them.
- Follows ADR 0002 (logic in `SerenixCore`) and ADR 0005 (own names, 0–100). No new ADR: every
  choice here is easy to change later.

## Seams under test
- **Today view (`SerenixCore`)**, fed hand-built Nights and Days with known values and a fixed
  current time. It catches which Day and Night are shown, the date picker's range and the Today
  pill, "No Night yet / recorded", the greeting, the avatar letter, bands, Calibrating counts,
  Baseline (median, earlier Nights only, at least 3, missing values skipped), every Zone
  boundary, status words, gauge positions, difference formats, Load "so far", missing values,
  popup content and which sync pill shows. It misses layout, colours, taps, animation, pill
  timing, the name prompt, storage and the Strap facts in the menu, which are checked by hand on
  the phone (ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`, on Windows and in CI). Expected values are literals worked out by hand:
- [x] With Nights dated 30 Oct and 1 Nov and the current time 1 Nov 08:12, the view on 1 Nov
      is titled "Sun 1 Nov" with no Today pill and shows the 1 Nov Night; the date picker runs
      from 30 Oct to 1 Nov. On 31 Oct it is titled "Sat 31 Oct", shows the Today pill and "No
      Night recorded" with that Day's Load. With no Nights, the picker runs from today to today.
- [x] With no Night dated today, the view shows "No Night yet" and today's Load, and no other
      Day's values.
- [x] Readiness 67 is Ready, 66 and 34 are Steady, 33 is Take it easy.
- [x] Baseline for HRV over earlier values 50, 70, 60, 58 is 59 (even-count median); over 50,
      70, 60 it is 60.
- [x] Baseline uses at most the 14 most recent earlier Nights: with 20 earlier Nights, the 6
      oldest change nothing.
- [x] The Night shown is not in its own Baseline: changing its HRV changes its Zone but not its
      Baseline.
- [x] An earlier Night's Baseline comes from Nights before it only: adding a newer Night leaves
      it unchanged.
- [x] A metric with 2 earlier Nights is Calibrating ("Calibrating", no Zone); with 3, it has a
      Baseline.
- [x] Earlier Nights missing a metric are skipped for that metric's Baseline and popup chart, and
      don't count towards its 3.
- [x] HRV against Baseline 60: 57 (−5%) is In range, 56.9 is Watch, 51 (−15%) is Watch, 50.9 is
      Out of range, 90 is In range.
- [x] Resting HR against Baseline 52: 53 is In range, 53.1 is Watch, 56 is Watch, 56.1 is Out of
      range, 45 is In range.
- [x] Respiratory rate against Baseline 14.0: 14.5 and 13.5 are In range, 15.0 is Watch, 15.1
      and 12.9 are Out of range.
- [x] Skin temperature against Baseline 34.0: 34.3 is In range, 33.6 is Watch, 34.7 is Out of
      range.
- [x] SpO2: 95 is In range, 94 and 92 are Watch, 91 is Out of range, including on a Night with
      no earlier Nights.
- [x] Differences format as "+14%" for HRV, "−3 bpm" for Resting HR, and "+0.4" for respiratory
      rate and skin temperature.
- [x] A missing Nightly Metric, score, Time Asleep or Load shows "—" with no Zone.
- [x] Load on today is labelled "Load so far"; on an earlier Day, "Load".
- [x] When either Baseline is Calibrating, vs your Baseline is the single Calibrating line with
      the right "N to go".
- [x] Tile status words against exact Baselines (HRV 60, Resting HR 52, respiratory rate 14.0,
      skin temperature 34.0): HRV 57 "Normal", 54 "Low"; Resting HR 53 "Normal", 55 "High";
      respiratory rate 15.0 "High", 13.0 "Low"; skin temperature 34.5 "High", 33.5 "Low"; SpO2
      97 "95% or above", 93 "Below 95%", 90 "Below 92%"; a Calibrating metric "Calibrating".
- [x] Gauge positions against the same Baselines: HRV 60 → 0.5, 55.5 → 0.25, 51 → 0, 75 → 1
      (clamped); Resting HR 54 → 0.75, 48 → 0; respiratory rate 14.5 → 0.75; skin temperature
      33.7 → 0.25; SpO2 97 → 0.75, 85 → 0 (clamped); a Calibrating or missing metric has no
      position.
- [x] Tiles carry no trend line; the Time Asleep tile has no Zone, status word or gauge.
- [x] The Sleep popup's minutes awake equal Final Wake − Sleep Onset − Time Asleep.
- [x] The Nightly Metric popup holds the Night shown and up to 13 earlier Nights, plus the
      Baseline and In range limits (none for SpO2).
- [x] Which sync pill shows: connecting and syncing → "Syncing"; a sync just finished → "Sync
      successful"; Strap not found, Bluetooth unavailable or the Strap disconnecting → "Sync
      paused", carrying its reason and "Serenix will try again next time you open it."; any
      other failure → "Sync failed" carrying its reason; idle with no sync just finished, or a
      sync the user cancelled → no pill.
- [x] The greeting on today with the name "Ellis" is "Good morning, Ellis" at 05:00 and 08:12,
      "Good afternoon, Ellis" at 12:00, and "Good evening, Ellis" at 18:00 and 04:59; with no
      name, or a name of only spaces, it is "Good morning" at 08:12; an earlier Day has no
      greeting.
- [x] The avatar letter for "ellis" is "E"; for "  Ellis " it is "E" and the menu name is
      "Ellis"; with no name there is no letter and the menu name is "Add your name".

Manual, on the iPhone with the sideloaded CI build (steps listed in the PR):
- [ ] After a sync with real Nights, the Today screen shows the rings, vs your Baseline and six
      tiles, with values matching the Today view's output for that data.
- [x] Zone colours show green, amber and red as given, and the Readiness ring and word share the
      band colour.
- [ ] The date ▾ opens a picker limited to the earliest Night through today; picking a Day shows
      it; the Today pill shows on other Days and returns to today.
- [x] Tapping the Readiness ring, the Sleep Score ring, the Time Asleep tile and each metric tile
      opens the right popup; a tap outside or a swipe down closes it; the Load ring does
      nothing.
- [ ] Each metric tile shows its icon, value, ✓ status word and a gauge in the Zone colour, with
      no trend line.
- [ ] The sync pill slides down while syncing with 001's progress bar and time left, and tapping
      it offers Cancel; "Sync successful" shows green with a ✓ and slides away after 3 seconds;
      with the Strap out of range, "Sync paused" shows amber with a ⚠; tapping a paused or
      failed pill shows the reason and Retry restarts the sync; with nothing to say, no pill
      shows. Pulling down on the Today screen starts a sync.
- [ ] On first launch Serenix asks "What should we call you?"; after Continue the Today screen
      greets by name, after Skip it greets without one, and the prompt never shows again.
- [ ] The avatar opens the menu with the name (or "Add your name") under a large letter (or
      person icon); editing the name there updates the greeting and avatar; the Strap rows
      show Connected and the model, battery, last sync, and Sync now / Retry sync; Debug opens
      001's debug screen; ✕ closes the menu.
- [ ] After a sync with a name set, the Sync Log shared from Debug doesn't contain the name.
- [ ] All of 001's manual checks still pass with the main screen replaced by the Today screen.

## Non-goals (explicitly out of scope)
- How Sleep Period, Nightly Metrics, Time Asleep, Sleep Score, Readiness and Load are computed.
  Each is its own spec.
- The tab bar. It arrives with the Sleep screen spec.
- The Sleep screen, with its week strip and heart rate through the night, and the Trends screen.
  Both are later specs, already prototyped (see Notes).
- A Load popup with hourly Load; it belongs to the Load spec.
- Profile menu rows for Apple Health (Integrations), Export data, Contact us, Report a bug and
  Write a review. Each comes with its own spec.
- Anything else in the Profile (photo, age, units), any account, sign-in or server, and other
  messages using the name. Each would be its own spec.
- Streaks and a "Health KPI" summary from the reference designs.
- Editing, deleting or hiding a Night; Naps; Stress.
- Notifications, widgets, or a Watch app.

## Open questions
- **Zone cut-offs** are the prototype's placeholders. Tune them once there are a few weeks of
  real Nights, and change the constants and their tests together.
- **Light mode.** The prototype is dark only. Assumption: the screen follows iOS light/dark,
  with the same band and Zone colours in both.
- **Write a review.** It needs the App Store, which needs the Apple Developer Program (ADR 0003).
  When its spec comes, it may link to GitHub instead.
- **SpO2 rounding.** Zones use unrounded values, so SpO2 94.6 shows "95%" with "Below 95%".
  Assumption: keep it, as the Zone table says; revisit if it confuses on real Nights.
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
  SpO2. New terms: Time Asleep, Zone and Profile.
- Redesign (2026-11-01): the top bar, sync pill, tiles and profile menu follow reference
  screenshots the owner shared in conversation. Their layout is taken, not their names or
  features (ADR 0005).
- Related: `specs/001-history-sync.md`.
