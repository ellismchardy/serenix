# 006 — Load popup

**Status:** built
**Last updated:** 2026-11-02 (built; CI and the phone checks open in the PR)
**Issue:** https://github.com/ellismchardy/serenix/issues/12 (wayfinder map)

## Problem
The Load ring shows one number (spec 005), but tapping it does nothing (spec 002), so the user
can't see where that number came from: when in the Day they worked hard, how hard, or whether
the Day was unusual for them. And with no way to see their heart rate on the phone right now,
they can't check what an effort is doing while they do it.

## Goal
Tapping the Load ring opens a Load popup that shows the Day's time in each HR Zone, hour by
hour, against the user's typical Load, and, on today, their Live HR from the Strap.

## User stories
1. As a Strap owner, I want to tap the Load ring and see how many minutes I spent in each HR
   Zone, so that I understand why my Load is what it is.
2. As a Strap owner, I want hourly bars of my HR Zones across the Day, so that I can see when
   I worked hard.
3. As a Strap owner, I want my Load next to my typical Load, so that I know whether the Day was
   hard for me.
4. As a Strap owner, I want my Live HR in a small pill on today's Load popup, so that I can see
   what my heart is doing right now.
5. As a Strap owner whose Strap is out of range, off my wrist or still connecting, I want the
   pill to show "—" quietly, not an error.
6. As a Strap owner looking at a Day from weeks ago, I want its HR Zones still there after its
   History Records are pruned, and an honest note when they were never worked out.
7. As a Strap owner who hasn't given an age or Max HR, I want the ring to keep sending me to add
   my age (spec 005).
8. As the developer, I want Live HR Frames in the Sync Log, so that a shared log shows what the
   Strap sent.

## Behavior
**Opening.** When the Load ring reads "Add your age", tapping it opens the profile menu (spec
005). Otherwise it opens the Load popup, on any Day, even when Load is "—" because the Day has
no History Records. The popup slides up and closes like spec 002's popups.

**Contents, top to bottom.**
1. **Live HR pill** at the top left, on today only (see Live HR). Earlier Days have no pill.
2. **The Day and Load**: the Day's date and its Load, or "—". On today, "As of your last sync at
   08:12" (the time the last History Sync ended, local time).
3. **Typical Load**: "Typical: 45 · today +12" ("that Day" on an earlier Day; differences
   signed, "−" for below, "±0" for equal). Typical Load is the median Load of the 28 Days before
   the Day shown, not counting it; missing Loads are skipped, a Load of 0 counts; an even count
   takes the mean of the middle two, rounded to a whole number with halves up. With fewer than
   4 such Days the line reads "Typical Load after 4 Days (N so far)". With the Day's Load
   missing, only "Typical: 45" shows.
4. **Heart rate zones**: under that heading, five rows, "Zone 1 · 50–60%" to "Zone 5 · 90–100%",
   each with a bar (its share of the Day's time in HR Zones) and its time, rounded to whole
   minutes: "42m" under an hour, "1h 05m" from an hour. Rows are rounded on their own and
   needn't add up to anything.
5. **Hourly bars**: one bar per local hour of the Day (23 or 25 across a clock change), each
   stacked by HR Zone from that hour's seconds in each, on a 0–60 minute scale. On today, hours
   after now are empty.
6. **Highest HR**: "Highest HR 172 bpm at 18:40", the highest heart rate in the Day's History
   Records with HR 0 skipped, even under the floor; the earliest time if it repeats. "—" with
   no heart rate over 0.
7. **Max HR used**: "Using Max HR 190 (entered)" or "Using Max HR 180 (estimated from your
   age)", the Max HR that Day's Load and HR Zones were worked out with.

A Day with no History Records shows "No heart rate recorded this Day" in place of items 4–7. A
Day with a Load but no stored HR Zones (worked out before this spec, its History Records since
pruned) shows "Heart rate zones aren't available for this Day" in place of items 4–7.

**HR Zones.** Each History Record with a heart rate counts as one second in the HR Zone its
exact share of Max HR falls in (not rounded to bpm), each band including its lower edge: ≥50%
and <60% is HR Zone 1, ≥60% HR Zone 2, ≥70% HR Zone 3, ≥80% HR Zone 4, ≥90% HR Zone 5, and above
Max HR still HR Zone 5. HR 0 and under 50% count in no HR Zone. The Day, Max HR and repeated
History Records follow spec 005 exactly, so time in HR Zones is exactly the seconds over Load's
floor.

**When they're worked out.** HR Zone seconds, hourly HR Zone seconds, Highest HR and its time,
and the Max HR used (and whether entered or estimated) are worked out with the Day's Load, in
the same Day rebuild (spec 005), stored with it and kept forever. Anything that redoes a Day's
Load redoes them (a sync, a Profile change). On the first launch after this ships, every Day
still due (the last 30) is queued once, as for a Profile change. Older Days keep their Load and
have no HR Zones. With no Max HR, nothing is stored and the ring says "Add your age".

**Today's popup is a snapshot.** Load, zones and bars come only from synced History Records.
Live HR never changes them and is never stored. Opening the popup never starts a sync; a sync
that ends while it's open refreshes its contents.

**Live HR.** While today's Load popup is open and Serenix is in the foreground (ADR 0007):
- With no sync running, Serenix connects to the Strap, sends Live HR on (`0x03 01`), and reads
  one `0x28` Frame a second. On closing the popup or leaving the foreground it sends Live HR off
  (`0x03 00`) and disconnects. Coming back with the popup still open reconnects.
- During a History Sync, it sends `0x03 01` on the sync's connection; on close or leaving the
  foreground it sends `0x03 00` and leaves the sync running (ADR 0006). The sync uses `0x28`
  Frames for Live HR instead of ignoring them (spec 001); nothing else about the sync changes.
- Live HR readings are never stored and never count toward Load.

**The pill** shows a heart and the bpm, e.g. "72". It shows a pulsing heart and "…" while
connecting, until the first reading. It shows a grey heart and "—", never an error or a reason,
when: no Strap is set up, Bluetooth is off, the connection fails or drops, the last reading was
0 (the Strap acquiring or off the wrist), or no reading has arrived for 5 seconds or more
(stale: five missed 1-second Frames, a named assumption). A new reading brings it back.

**Sync Log.** Every `0x03` command and `0x28` Frame goes in the Sync Log like any other Frame.
During a sync, in that sync's Sync Log; outside one, in a single Sync Log labelled "Live HR",
replaced at each new Live HR connection, not counted among the last 5 syncs' logs, and included
by "Share log". It never holds Profile fields.

## Design decisions
- **`SerenixCore`: Load of a Day** (spec 005) also returns the Day's seconds in each HR Zone,
  seconds in each HR Zone per local hour, Highest HR and its time, and the Max HR used with
  whether it was entered or estimated. One pass over the same records.
- **`SerenixCore`: HR Zone**: the five bands and which one a heart rate falls in for a Max HR.
- **`SerenixCore`: Typical Load**: given the Days with their Load and a Day, the typical Load
  or how many Days exist so far. The Readiness spec reuses it for the Load part of Baseline.
- **`SerenixCore`: Protocol** builds the Live HR on and off commands and decodes a `0x28` Frame
  into a Live HR reading (HR, Strap time); a bad CRC is a typed error, skipped. Layout from
  `hr-tracker/docs/protocol.md` ("Realtime HR packet").
- **`SerenixCore`: Live HR pill**: given the connection state, the last reading, when it
  arrived and the current time, what the pill shows. It never reads the clock.
- **`SerenixCore`: Today view** gains the Load popup's content, whether the Load ring opens the
  popup or the profile menu, whether the pill shows, and the last sync's end time.
- **Shell:** stores the new Day fields in SwiftData beside Load; queues every due Day once on
  the first launch after this ships; opens and closes the Live HR connection with the popup and
  the foreground, sharing a running sync's connection; feeds `0x28` Frames to the decoder and
  the pill; writes the Live HR Sync Log; draws the popup.
- ADR 0007 (new): a connection is held between syncs only while Live HR is on screen. Follows
  ADR 0002 (logic in `SerenixCore`), 0005 (own names) and 0006 (syncs finish in the background).

## Seams under test
- **Load of a Day (`SerenixCore`)**, fed hand-built History Records with spec 005's defaults. It
  catches HR Zone edges, exact shares, above Max HR, HR 0, repeats, hourly split, clock-change
  Days, Highest HR and the Max HR used. It misses storage.
- **Typical Load (`SerenixCore`)**: the 28-Day window, the Day left out, skipped and 0 Loads,
  the median and rounding, and the 4-Day minimum.
- **Protocol (`SerenixCore`)**, fed real `0x28` Frames trimmed from a capture: the byte layout,
  HR 0 while acquiring, and a bad CRC; and the bytes of `0x03 01` and `0x03 00`.
- **Live HR pill (`SerenixCore`)**: connecting, a reading, a 0 reading, the 5-second stale rule
  and no Strap.
- **Today view (`SerenixCore`)**: popup content, the ring's tap, the pill on today only, "As of
  your last sync", the typical Load line, and the no-records and not-available texts.

They miss the BLE connection, sending `0x03` mid-sync, foreground and background handling, the
Sync Log, storage, the first-launch queue and the drawing, which are checked by hand on the
phone (ADR 0002).

## Success criteria (must be checkable)
Unless a criterion says otherwise: Europe/London, sex Male, Max HR 190 entered, no Nights (Resting
HR 60), and one History Record per second. HR Zone lower edges for Max HR 190: 95, 114, 133,
152 and 171 bpm.

- [x] An hour at 164 bpm gives 3600 s in HR Zone 4 and none in the others; its hour bars hold
      HR Zone 4 only; Highest HR is 164 at the hour's first record; Max HR used is 190, entered.
- [x] 10 minutes each at 94, 95, 113, 114, 133, 152, 170, 171 and 200 bpm give HR Zone 1 1200 s
      (95, 113), HR Zone 2 600 s (114), HR Zone 3 600 s (133), HR Zone 4 1200 s (152, 170) and
      HR Zone 5 1200 s (171, 200); 94 bpm counts in none; Highest HR is 200.
- [x] The seconds in all HR Zones equal the seconds over Load's floor: an hour at 164 bpm plus an
      hour at HR 0 and an hour at 94 bpm gives 3600 s; the same records repeated or reordered
      give the same HR Zones and Highest HR.
- [x] With no Max HR and birth year 1986 on a Day in 2026, an hour at 162 bpm (90% of 180) is in
      HR Zone 5 and Max HR used is 180, estimated.
- [x] Hourly: an hour at 164 bpm from 23:30 to 00:30 on the night 31 Oct to 1 Nov 2026 puts
      1800 s of HR Zone 4 in 31 Oct's 23:00 hour and 1800 s in 1 Nov's 00:00 hour; 29 Mar 2026
      has 23 hours and 25 Oct 2026 has 25.
- [x] Highest HR: records at 150 bpm at 09:00 and 18:40 and 120 bpm elsewhere give "Highest HR
      150 bpm at 09:00"; a Day of only HR 0 gives "—".
- [x] Typical Load: Loads 30, 40, 50 and 60 on the 4 Days before, and 90 on the Day, give
      "Typical: 45 · today +45"; 30, 40, 51 and 60 give 46; a missing Load among them is skipped
      and a 0 counts; a Day 29 Days before isn't counted; with 3 Days, "Typical Load after 4 Days
      (3 so far)"; an earlier Day reads "that Day", a Load below typical "−", equal "±0"; with
      the Day's Load missing, just "Typical: 45".
- [x] Protocol: the real `0x28` fixture Frames decode to their HR and Strap time, the
      acquiring ones to HR 0; one with a changed byte and the old CRC is a bad-CRC error; Live HR
      on and off build the same bytes hr-tracker's `whoop5.py` sends, committed as literals.
- [x] Live HR pill: connecting with no reading shows "…"; a reading of 72 that arrived 4.9 s ago
      shows "72"; 5.0 s ago shows "—"; a reading of 0 shows "—"; no Strap, Bluetooth off or a
      failed connection shows "—".
- [x] Today view: a Day with Load 57, or with missing Load for no records, marks the ring as
      opening the Load popup; missing Load for no Max HR marks it as opening the profile menu.
- [x] Today view: today's popup has the pill and "As of your last sync at 08:12" for a sync
      that ended at 08:12; an earlier Day's has neither.
- [x] Today view: a Day with no records shows "No heart rate recorded this Day" and no zones,
      bars, Highest HR or Max HR used; a Day with a Load but no stored HR Zones shows "Heart
      rate zones aren't available for this Day"; zone times show "42m" and "1h 05m".
- [ ] `swift test`, `swift format lint --strict` and `swift build` pass, and the macOS CI job
      builds the app.
- [ ] On the phone (by hand): tapping the Load ring opens the popup with the zones, hourly bars
      stacked by HR Zone, Highest HR and Max HR used, and a tap outside or a swipe down closes
      it; with no age it still opens the profile menu.
- [ ] On the phone (by hand): on today the pill shows "…", then a heart rate within a few
      seconds that follows a few squats; on an earlier Day there's no pill.
- [ ] On the phone (by hand): with the Strap off the wrist or out of range, the pill goes to "—"
      within about 5 seconds and comes back when it's back; with no Strap set up it shows "—".
- [ ] On the phone (by hand): opening the popup during a sync shows Live HR and the sync still
      completes; closing it mid-sync leaves the sync running.
- [ ] On the phone (by hand): closing the popup, or leaving Serenix, stops Live HR and (outside a
      sync) disconnects; coming back with it open reconnects.
- [ ] On the phone (by hand): a shared log holds the `0x03` and `0x28` Frames, in the sync's log
      during a sync and in the "Live HR" log otherwise, and the last 5 syncs' logs are all still
      there.
- [ ] On the phone (by hand): after the update, Days in the last 30 show their HR Zones without
      a new sync; an older Day says they aren't available.

## Non-goals (explicitly out of scope)
- A connection held between syncs, background Live HR, a widget or Live Activity (ADR 0007).
- Live HR anywhere but today's Load popup, or recording it.
- Hourly Load (Load is log-scaled, so hours don't add up); HR Zones by Resting HR (heart rate
  reserve) or custom HR Zone edges.
- The hardest stretch of the Day, workouts, and HR Zones for a Night.
- Working HR Zones out again for Days whose History Records are pruned.
- Readiness, which will reuse Typical Load.

## Open questions
- **The `0x28` fixture.** The owner will capture a few seconds of real `0x28` Frames with
  `hr-tracker`'s `whoop5.py` (including the first HR 0 ones); the Protocol tests wait on it.
- **The 5-second stale limit** is a named assumption, to tune on the phone.
- **The unknown bytes** of a `0x28` Frame (`d[9]`, `d[14:16]`) are not read.

## Notes
- Live HR protocol: `hr-tracker/docs/protocol.md`, "Realtime HR packet" and command `0x03`;
  tested by the owner with `whoop5.py`.
- Specs 002 (popups, the Load ring), 005 (Load, Day rebuilds, "Add your age") and 001 (History
  Sync, Sync Log). ADRs 0002, 0005, 0006 and 0007 (new).
- Prototype: branch `prototype/homescreen`, the Load popup with hourly bars (`?variant=E`).
- HR Zone edges from Edwards, matching Load's 50% floor (docs/research/cardio-load-methods.md).
- Glossary: new terms HR Zone and Live HR.
