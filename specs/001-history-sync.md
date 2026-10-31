# 001 — History Sync

**Status:** approved
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

## Behavior
**Connecting the Strap.** On first run there is a "Connect Strap" step. Serenix scans for a Strap
and connects. If the iPhone is already paired with the Strap (pairings belong to the phone, not
to an app), it works straight away. Otherwise the step tells the user to put the Strap in pairing
mode (it times out after 1–2 minutes) and iOS shows its pairing prompt. Serenix then remembers
that Strap and reconnects to it automatically. One Strap only.

**When a History Sync runs.** Each time Serenix comes to the foreground, and when the user taps
"Sync now". A sync already running is not started twice.

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
stored together with its raw bytes. A History Record whose Record Counter is already stored is
ignored, so a Batch the Strap re-sends is never stored twice. Other Frames that arrive during a
sync (console logs, events, optical bursts, live HR) are logged and otherwise ignored.

**Empty sync.** When the Strap has nothing new, it sends an empty Batch whose Sync Cursor is all
`ff`. Serenix acknowledges it, the sync completes, and the status says "Up to date".

**Failures.** The sync stops and reports a reason, keeping every History Record already stored,
when: the Strap can't be found or connected, pairing is refused, a Frame fails its CRC check,
a per-second `0x2f` Frame can't be decoded as a History Record (for example, a firmware update
changed its length), the Strap replies with an error status, or the Strap sends nothing for
**10 seconds**. A Batch containing a Frame that failed its CRC check or couldn't be decoded is
**not** acknowledged, so the Strap keeps it and re-sends it next time. Disconnecting mid-sync is the same: the unacknowledged Batch comes again.

**Status and debug screen.** The main screen shows the sync state (connecting / syncing / up to
date / failed with reason) and when the last sync finished. A debug screen, reached from
settings, shows:
- the sync state and failure reason
- History Records stored: count, first and last Record Counter and time, and the number of gaps
  in Record Counters
- History Records received in the last sync
- the data range the Strap last reported (`0x22`)
- the Strap's battery level and model/firmware
- the Sync Log: every Frame in order, with time, direction, type and hex bytes
- a **Share log** button that hands the Sync Log to the iOS share sheet

The Sync Log keeps the most recent syncs on the phone and is only ever sent when the user shares
it.

## Design decisions
- **`SerenixCore` — Frame codec.** Builds command Frames (header, sequence number, CRC32) and
  parses incoming Frames, rejecting bad CRCs. Header-check values are the known table; building
  a Frame of an unknown length is an error.
- **`SerenixCore` — History Record decoder.** Turns a per-second `0x2f` Frame into a History
  Record, using the layout in `hr-tracker/docs/protocol.md`. Behind a per-Strap-model interface
  (docs/conventions.md); v1 has the Whoop 5.0 decoder only.
- **`SerenixCore` — History Sync session.** A pure state machine: given the current time it
  yields the Frames to send; fed each incoming Frame it yields Frames to send, History Records,
  Sync Log entries, and finally completed or failed. Timeouts are reported to it by the caller.
  It owns the handshake order, the Batch/acknowledge loop, completion, empty Batches and failure
  rules. It never stores the Sync Cursor (the Strap owns it).
- **iOS shell — Strap connection.** CoreBluetooth: scan, connect, pair, subscribe, write and
  notify. Moves bytes between the Strap and the History Sync session, runs the 10-second timer,
  and remembers the connected Strap.
- **iOS shell — History Record store.** SwiftData, keyed by Record Counter, storing decoded
  fields plus raw bytes (so improved decoders can re-read them).
- **iOS shell — screens.** Connect Strap, the sync status on the main screen, and the debug
  screen.
- Follows ADR 0001 (on-device only), 0002 (logic in `SerenixCore`), 0004 (sync on app open).

## Seams under test
- **History Sync session (`SerenixCore`)** — fed the Strap's Frames from the real 27 Oct capture,
  one at a time. Catches framing, CRCs, the handshake order, the Batch/acknowledge loop,
  completion, empty Batches, de-duplication and failure rules. Misses everything about real
  Bluetooth (pairing, connection drops, iOS behaviour) and SwiftData storage, which are checked
  by hand on the phone with the debug screen (CLAUDE.md rule 2, ADR 0002).

## Success criteria (must be checkable)
Automated (`swift test`, on Windows and in CI):
- [ ] Encoding each command the captured app sent, with the same sequence number, produces its
      exact captured bytes.
- [ ] Every Strap Frame in the capture parses with a valid CRC; a Frame with one byte changed is
      rejected.
- [ ] Decoding the capture's per-second `0x2f` Frames yields History Records whose Record
      Counter, timestamp and HR match values listed in the fixture (taken from `hr-tracker`'s
      `history.py` output, committed as literals).
- [ ] Replaying a captured sync, the session sends the captured app's commands with the same op
      codes and arguments, in the same order, except: no `0x03` or `0x3f`, and the clock
      arguments carry the time the test passes in.
- [ ] Replaying the whole capture yields exactly 1,036 History Records, each Record Counter once.
- [ ] Every `0x17` the session sends carries exactly the 8 Sync Cursor bytes from the preceding
      Batch end.
- [ ] Replaying an empty Batch (Sync Cursor all `ff`) acknowledges it and completes with 0 new
      History Records.
- [ ] Replaying a Batch twice (the re-send after an interrupted sync) produces no duplicate
      History Records.
- [ ] A Batch containing a Frame with a bad CRC is not acknowledged, and the session fails with
      that reason.
- [ ] A per-second `0x2f` Frame of an unexpected length is rejected by the decoder; a Batch
      containing one is not acknowledged, and the session fails with that reason.
- [ ] An error status in a reply, or a reported timeout, ends the session as failed with the
      reason.
- [ ] Every Frame sent and received appears in the Sync Log, in order, with its direction.

Manual, on the iPhone with the sideloaded CI build (steps listed in the PR):
- [ ] "Connect Strap" connects to the Strap, and after relaunching Serenix it reconnects
      without asking again.
- [ ] Opening Serenix runs a History Sync; the debug screen then shows more than 0 History
      Records stored and the state "up to date".
- [ ] Tapping "Sync now" straight after shows "Up to date" with 0 new History Records.
- [ ] Closing Serenix mid-sync, then syncing again, leaves 0 gaps in Record Counters across the
      period synced.
- [ ] The debug screen shows the data range, battery level and firmware, and "Share log" opens
      the iOS share sheet with the Sync Log.

## Non-goals (explicitly out of scope)
- Pruning History Records after 30 days — its own spec.
- Sleep, Nightly Metrics, scores, Apple Health export — later specs.
- Background sync, or staying connected and re-syncing while the app is open (ADR 0004).
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
- **Whether the iPhone's existing pairing works** for Serenix, or the Strap must go into pairing
  mode. Found out the first time "Connect Strap" runs.
- **What `0x61`, `0x45` and `0x22`'s first value mean**, and whether they're needed. Sent as
  captured; trimming them is a later experiment.
- **Assumption:** the 10-second "Strap stopped responding" timeout. The capture shows replies
  within milliseconds; adjust if real syncs need longer.
- **For `/plan`:** whether commands are written with or without response (read it from the
  capture), and how many syncs the Sync Log keeps.

## Notes
- Protocol reference: `hr-tracker/docs/protocol.md`. The sync loop (Batch start/end frames,
  where the Sync Cursor comes from, the "complete" frame, empty Batches) was worked out from
  `hr-tracker/captures/sixteen_session_2026-10-27.txt` and isn't yet in `protocol.md`.
- Fixture: a cleaned copy of that capture, with the serial and device ID replaced and the CRCs
  of changed Frames recalculated (docs/conventions.md, Testing). The raw capture is never
  committed.
- `protocol.md` says header bytes 4–5 are always `00 01`; that's only true for Frames the phone
  sends. Frames from the Strap carry `01 00` and different header-check values, so incoming
  Frames are checked by CRC only.
