# 001 — History Sync

**Status:** built
**Last updated:** 2026-10-31

## Problem
Every Serenix feature (sleep, Nightly Metrics, scores) is computed from the Strap's History
Records, and today there is no way to get them onto the phone without a third-party app. The
download commands have only been observed in captures, never driven by our own code, so this is
the riskiest piece of the product and everything else waits on it.

## Goal
The user opens Serenix and every History Record the Strap holds that the phone hasn't received
yet ends up stored on the phone, with a debug screen that shows exactly what happened.

## User stories
1. As a Strap owner, I want to connect my Strap once, so that Serenix can sync it from then on.
2. As a Strap owner, I want my History Records synced whenever I open Serenix, so that my data
   is up to date without doing anything.
3. As a Strap owner, I want a "Sync now" button, so that I can sync on demand.
4. As a Strap owner whose sync was cut off (app closed, phone locked, Bluetooth dropped), I want
   the next sync to carry on, so that I never lose a History Record or get one twice.
5. As a Strap owner with nothing new on the Strap, I want the sync to finish quickly and say so.
6. As the developer without a Mac, I want to see and share the Sync Log from the phone, so that
   I can tell why a sync failed.
7. As a Strap owner with a big backlog, I want a sync to keep going when I lock the phone or
   switch apps, so that I don't have to watch Serenix for minutes while it finishes.
8. As a Strap owner with a big backlog, I want to see how far a sync has got and roughly how
   long is left, so that I know whether to wait.

## Behavior
**Connecting the Strap.** The main screen has a "Connect Strap" button; until it has been used
once, Serenix doesn't sync on its own. Serenix scans for a Strap and connects. If the iPhone is
already paired with the Strap (pairings belong to the phone, not to an app), it works straight
away. Otherwise iOS shows its pairing prompt, and if subscribing fails Serenix tells the user to
put the Strap in pairing mode (it times out after 1–2 minutes) and try again. Serenix gives up on
finding or connecting to the Strap after 30 seconds, and the user can cancel sooner. It then
remembers that Strap and reconnects to it automatically. One Strap only.

**When a History Sync runs.** Each time Serenix comes to the foreground, and when the user taps
"Sync now". A sync already running is not started twice.

**Continuing in the background.** A History Sync that has started keeps going when the phone
locks or the user switches apps, until it completes or fails: History Records keep arriving and
Batches keep being acknowledged. Coming back to Serenix shows the sync still running or its
result; it does not start a second one. Serenix never *starts* a sync while in the background,
and does not notify the user when a background sync ends. If iOS ends Serenix mid-sync, nothing
special happens: History Records already stored are kept, and the unacknowledged Batch comes
again on the next sync.

**One History Sync.**
1. Connect and subscribe to the Strap's notify channels.
2. Handshake, sending the same commands as the captured third-party app, in the same order:
   hello (`0x91`), set the Strap's clock to the phone's current time (`0x0a`, both observed
   forms), read the clock (`0x0b`), `0x61`, `0x45`, battery (`0x1a`).
   **Left out:** live HR on (`0x03 01`), which a sync doesn't need, and `0x3f`, which the Strap
   ignores.
3. Ask for the data range (`0x22`), then for history (`0x16`).
4. For each Batch: keep its History Records, and when the Batch ends, acknowledge it by echoing
   its Sync Cursor (`0x17`). Keep going until the Strap says the sync is complete.
5. Disconnect.

**History Records.** Only `0x2f` Frames of the per-second variant are History Records. Each one is
decoded (Record Counter, timestamp, HR, RR intervals, motion, skin temperature, steps, SpO2) and
stored together with its raw bytes. A History Record is identified by its Record Counter and
timestamp together, because after a reboot the Strap can reuse a Record Counter for a new
record. One whose Record Counter and timestamp are both already stored (or already received in
this sync) is ignored, so a Batch the Strap re-sends is never stored twice; one that only
shares a Record Counter is kept. Other Frames that arrive during a
sync (console logs, events, optical bursts, live HR) are logged and otherwise ignored.

**Empty sync.** When the Strap has nothing new, it sends an empty Batch whose Sync Cursor is all
`ff`. Serenix acknowledges it, the sync completes, and the status says "Up to date".

**Failures.** The sync stops and reports a reason, keeping every History Record already stored,
when: the Strap can't be found or connected, pairing is refused, a Frame fails its CRC check or
its length doesn't match its size (a Frame cut short), a per-second `0x2f` Frame can't be
decoded as a History Record (for example, a firmware update changed its length), the Strap
replies with an error status, a write to the Strap fails, the Strap disconnects or Bluetooth
turns off, the user taps Cancel, or the Strap sends nothing for **10 seconds**. A Batch
containing a Frame that failed one of those checks or couldn't be decoded is **not**
acknowledged, so the Strap keeps it and re-sends it next time. Disconnecting mid-sync is the
same: the unacknowledged Batch comes again.
The 10 seconds apply in the background too: a sync whose Strap went silent while Serenix was in
the background shows as failed ("stopped responding") by the time the user looks.

**Sync progress.** While a sync runs, the main screen shows a progress bar and the time left.
Progress is how far the History Records have come in time: from the first History Record of
this sync to the moment the sync started, measured by the newest History Record received so far.
It runs from 0 to 1 and never goes backwards. Before the first History Record arrives (and for
an empty sync, which has none) there is no progress yet and no progress bar shows. The
time left is the time since the first History Record arrived, scaled by the progress still to
go; it is shown once at least 2 seconds have passed since that first History Record, as "about
N min left" rounded up to whole minutes, or "less than a minute left". Gaps in the History
Records (the Strap off the wrist) make the estimate rough, not wrong for long.

**Status and debug screen.** The main screen shows the sync state (connecting / syncing with its
progress / up to date / failed with reason) and when the last sync completed, with the History
Records it received. A debug screen,
reached from settings, shows:
- the sync state and failure reason
- History Records stored: count, first and last Record Counter and time, and the number of gaps
  in Record Counters
- History Records received in the last sync
- the data range the Strap last reported (`0x22`)
- the Strap's battery level and model/firmware
- the Sync Log of the current or last sync, newest 200 Frames, each with time, direction, type
  and hex bytes
- a **Share log** button that hands every Frame of the last 5 syncs' Sync Logs to the iOS share
  sheet

The phone keeps the Sync Logs of the last 5 syncs, and they are only ever sent when the user
shares them. A sync ended outright (Serenix closed, or ended by iOS) keeps no Sync Log; its
History Records are stored as usual.

## Design decisions
- **`SerenixCore` — Frame codec.** Builds command Frames (header, sequence number, CRC32) and
  parses incoming Frames, rejecting bad CRCs. Header-check values are the known table; building
  a Frame of an unknown length is an error.
- **`SerenixCore` — History Record decoder.** Turns a per-second `0x2f` Frame into a History
  Record, using the layout in `hr-tracker/docs/protocol.md`. Behind a per-Strap-model interface
  (docs/conventions.md); v1 has the Whoop 5.0 decoder only.
- **`SerenixCore` — History Sync session.** A pure state machine: given the current time it
  yields the Frames to send; fed each incoming Frame it yields Frames to send, History Records,
  Sync Log entries, and finally completed or failed. It owns the handshake order, the
  Batch/acknowledge loop, completion, empty Batches, failure rules and their wording, the
  10-second timeout, and the sync's progress and time left (all from the times passed in). It never stores the
  Sync Cursor (the Strap owns it).
- **iOS shell — Strap connection.** CoreBluetooth: scan, connect, pair, subscribe, write and
  notify. Moves bytes between the Strap and the History Sync session, asks the session for the
  timeout on a timer, and remembers the connected Strap. Declares iOS's Bluetooth background mode (central role)
  so a running sync keeps receiving Frames in the background; no state restoration.
- **iOS shell — History Record store.** SwiftData, keyed by Record Counter and timestamp,
  storing decoded fields plus raw bytes (so improved decoders can re-read them).
- **iOS shell — screens.** Connect Strap, the sync status and progress on the main screen, and
  the debug screen. The shell only draws the progress and time left the session reports.
- Follows ADR 0001 (on-device only), 0002 (logic in `SerenixCore`), 0006 (sync starts on app
  open and finishes in the background).

## Seams under test
- **History Sync session (`SerenixCore`)** — fed the Strap's Frames from the real 27 Oct capture,
  one at a time. Catches framing, CRCs, the handshake order, the Batch/acknowledge loop,
  completion, empty Batches, de-duplication, failure rules, and progress and time left. Misses
  everything about real Bluetooth (pairing, connection drops, iOS behaviour) and SwiftData
  storage, which are checked by hand on the phone with the debug screen (CLAUDE.md rule 2,
  ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`, on Windows and in CI):
- [x] Encoding each command the captured app sent, with the same sequence number, produces its
      exact captured bytes.
- [x] Every Strap Frame in the capture parses with a valid CRC; a Frame with one byte changed is
      rejected.
- [x] Decoding the capture's per-second `0x2f` Frames yields History Records whose Record
      Counter, timestamp and HR match values listed in the fixture (taken from `hr-tracker`'s
      `history.py` output, committed as literals).
- [x] Replaying a captured sync, the session sends the captured app's commands with the same op
      codes and arguments, in the same order, except: no `0x03` or `0x3f`, and the clock
      arguments carry the time the test passes in.
- [x] Replaying the whole capture yields exactly 1,036 History Records, each Record Counter once.
- [x] Every `0x17` the session sends carries exactly the 8 Sync Cursor bytes from the preceding
      Batch end.
- [x] Replaying an empty Batch (Sync Cursor all `ff`) acknowledges it and completes with 0 new
      History Records.
- [x] Replaying a Batch twice (the re-send after an interrupted sync) produces no duplicate
      History Records.
- [x] Two per-second `0x2f` Frames in one sync with the same Record Counter but different
      timestamps (as after a Strap reboot) both yield History Records; the same Record Counter
      and timestamp a second time yields none.
- [x] A Batch containing a Frame with a bad CRC is not acknowledged, and the session fails with
      that reason.
- [x] A per-second `0x2f` Frame of an unexpected length is rejected by the decoder; a Batch
      containing one is not acknowledged, and the session fails with that reason.
- [x] An error status in a reply, or a reported timeout, ends the session as failed with the
      reason.
- [x] Every Frame sent and received appears in the Sync Log, in order, with its direction.
- [x] Replaying a captured sync, the session reports no progress before its first History
      Record; after that, progress never decreases, stays within 0–1, and after the last
      History Record equals the value worked out by hand from the fixture's timestamps and the
      start time passed in (committed as a literal).
- [x] With History Records fed at known times, the session reports no time left until 2
      seconds after the first one, then the time left worked out by hand (a literal).
- [x] Replaying an empty sync reports no progress at any point and completes.

Manual, on the iPhone with the sideloaded CI build (steps listed in the PR):
- [x] "Connect Strap" connects to the Strap, and after relaunching Serenix it reconnects
      without asking again.
- [x] Opening Serenix runs a History Sync; the debug screen then shows more than 0 History
      Records stored and the state "up to date".
- [x] Tapping "Sync now" straight after shows "Up to date" with 0 new History Records.
- [x] Closing Serenix mid-sync, then syncing again, leaves 0 gaps in Record Counters across the
      period synced.
- [x] The debug screen shows the data range, battery level and firmware, and "Share log" opens
      the iOS share sheet with the Sync Log.
- [x] Starting a sync of a backlog of at least an hour, then locking the phone straight away:
      on unlocking after it would have finished, the state reads "Up to date" and the shared
      Sync Log has Frames timestamped throughout the time the phone was locked.
- [x] Starting a sync, then switching to another app for a minute: the shared Sync Log has
      Frames from that minute, and returning to Serenix shows the same sync (no second
      handshake in the Sync Log).
- [x] Taking the Strap out of range mid-sync while the phone is locked: on unlocking, Serenix
      shows the sync failed with a reason, and the next sync leaves 0 gaps in Record Counters
      across the period synced.
- [x] A sync of at least an hour's backlog shows no progress at first, then a progress bar that
      fills and a time left that falls to "less than a minute left", and ends "Up to date"; the
      screen stays responsive throughout.

## Non-goals (explicitly out of scope)
- Pruning History Records after 30 days — its own spec.
- Sleep, Nightly Metrics, scores, Apple Health export — later specs.
- Starting a History Sync while Serenix is in the background (Strap in range, a schedule), or
  iOS relaunching Serenix to finish a sync it ended (state restoration) — a later spec.
- Staying connected between syncs, or re-syncing while the app stays open.
- A notification when a background sync ends.
- Progress for connecting or the handshake; History Record counts ("12,400 of ~29,000") on the
  main screen.
- Live heart rate.
- More than one Strap, or forgetting/replacing the Strap.
- Detecting or preventing another app syncing the same Strap. If another app acknowledges
  History Records, Serenix never receives them.
- Decoding the optical-burst `0x2f` variant, console logs or events beyond logging them.
- Whoop 4.0 and MG.

## Open questions
- **How much history the Strap holds** before it overwrites the oldest. Not a success criterion:
  the user measures it by not syncing for several days, then checking the data range and the
  first Record Counter on the debug screen.
- **What `0x61`, `0x45` and `0x22`'s first value mean**, and whether they're needed. Sent as
  captured; trimming them is a later experiment.
- **Assumption:** the 10-second "Strap stopped responding" timeout. The capture shows replies
  within milliseconds; adjust if real syncs need longer.

## Notes
- **Settled while building:** the iPhone's existing pairing works for Serenix ("Connect Strap"
  connected in about a second, no prompt); commands are written with response (the capture has
  write requests and responses, no write commands); the phone keeps the last 5 syncs' Sync Logs.
- Protocol reference: `hr-tracker/docs/protocol.md`. The sync loop (Batch start/end frames,
  where the Sync Cursor comes from, the "complete" frame, empty Batches) was worked out from
  `hr-tracker/captures/sixteen_session_2026-10-27.txt` and isn't yet in `protocol.md`.
- Fixture: a cleaned copy of that capture, with the serial and device ID replaced and the CRCs
  of changed Frames recalculated (docs/conventions.md, Testing). The raw capture is never
  committed.
- First phone sync (31 Oct 2026): after a likely Strap reboot (its log uptime puts the start at
  ~18:17), Record Counter 3,155,039 came twice with timestamps 19 s apart, on two different
  records, and nothing was recorded until the next sync set the clock. Hence identifying a
  History Record by Record Counter and timestamp. **Assumption:** the same Record Counter and
  timestamp always mean the same record re-sent.
- Sync progress and time left come from issue #7 (github.com/ellismchardy/serenix/issues/7).
  **Assumption:** the Strap's clock matches the phone's once the handshake sets it, so record
  timestamps and the sync's start time are comparable; progress is clamped to 0–1 in case not.
- `protocol.md` says header bytes 4–5 are always `00 01`; that's only true for Frames the phone
  sends. Frames from the Strap carry `01 00` and different header-check values, so incoming
  Frames are checked by CRC only.
