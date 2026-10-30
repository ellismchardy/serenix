# Plan: 001 — History Sync

**For spec:** specs/001-history-sync.md
**Type:** feature
**Branch:** feat/history-sync

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
Build the protocol test-first in `SerenixCore` against a cleaned copy of the real 27 Oct capture,
then get a real sync onto the phone as early as possible (task 4), because Bluetooth on iOS is
the biggest unknown and each phone round-trip costs a CI build plus a sideload. Core logic
grows in thin slices (codec → decoder → happy-path session → full replay → empty Batch →
failures); the shell grows in two later slices (storage and triggers, then the full debug
screen). Settled for the spec's `/plan` questions: commands are written **with response**
(the capture has 233 write requests and 223 write responses, no write commands), and the Sync
Log keeps the **last 5 syncs**.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice:** test fixture + Frame codec
   - Build the fixture once from `hr-tracker/captures/sixteen_session_2026-10-27.txt` with a
     small script in `scripts/`: keep each Frame's direction, characteristic and hex; replace
     the serial (Device Info read and hello reply) and device ID with fake values; recompute
     the CRCs of changed Frames. Never commit the raw capture.
   - `SerenixCore` Frame codec: build command Frames (header from the known table, sequence
     number, CRC32) and parse incoming Frames, rejecting bad CRCs.
   - Seam: Frame codec (public `Frame`/`Command`), under the History Sync session · Files:
     `scripts/make-sync-fixture.py`, `tests/SerenixCoreTests/Fixtures/`,
     `tests/SerenixCoreTests/SyncCapture.swift` (fixture reader), `src/SerenixCore/Frame*.swift`,
     `tests/SerenixCoreTests/FrameTests.swift`, `Package.swift` (test resources)
   - Done when: encoding each captured command with its sequence number gives its exact bytes;
     every Strap Frame parses with a valid CRC; a one-byte change is rejected.
2. [ ] **Slice:** History Record decoder
   - Decode per-second `0x2f` Frames (Record Counter, timestamp, HR, RR, motion, skin
     temperature, steps, SpO2, raw bytes) behind a per-Strap-model interface. Ignore the
     optical-burst variant. Expected values come from `hr-tracker/tools/history.py` run once
     over the fixture Frames, committed as literals (it reads `.pklg`, so feed it the hex).
   - Seam: History Sync session (decoder underneath it) · Files: `src/SerenixCore/HistoryRecord*.swift`,
     `tests/SerenixCoreTests/HistoryRecordTests.swift`
   - Done when: decoded Record Counter, timestamp and HR match the committed literals.
3. [ ] **Slice:** History Sync session, happy path for one sync
   - Pure state machine: handshake in the captured order (no `0x03`, no `0x3f`, clock from the
     time passed in) → `0x22` → `0x16` → per Batch keep History Records and echo the Sync
     Cursor in `0x17` → complete on the Strap's "complete" Frame. Every Frame in or out becomes
     a Sync Log entry.
   - Seam: History Sync session · Files: `src/SerenixCore/HistorySync*.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when: replaying one captured sync sends the captured op codes and arguments in order
     (minus `0x03`/`0x3f`, clock from the test); each `0x17` carries the preceding Batch end's
     8 Sync Cursor bytes; every Frame appears in the Sync Log with its direction.
4. [ ] **Slice:** first real sync on the phone (tracer through the shell)
   - Blocked by: 3
   - CoreBluetooth Strap connection (scan, connect, pair, subscribe to the four notify
     channels, write with response), a minimal "Connect Strap" screen, a "Sync now" button, and
     a bare debug screen listing the Sync Log and the count of History Records received (in
     memory only for now). Also `NSBluetoothAlwaysUsageDescription` in `project.yml`.
   - Seam: manual on the iPhone (CLAUDE.md rule 2) · Files: `src/SerenixApp/`, `project.yml`
   - Done when: on the phone, Connect Strap + Sync now completes a sync and the debug screen
     shows History Records received > 0 and the Sync Log. Records the answer to the spec's
     pairing open question in the PR.
5. [ ] **Slice:** full-capture replay and de-duplication
   - Blocked by: 3
   - The session ignores a Record Counter it has already yielded in this sync. Across syncs,
     de-duplication is the store's unique Record Counter key (task 8), checked by hand.
   - Seam: History Sync session · Files: `src/SerenixCore/HistorySync*.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when: replaying the whole capture yields exactly 1,036 History Records, each Record
     Counter once; replaying a Batch twice yields no duplicates.
6. [ ] **Slice:** empty Batch
   - Seam: History Sync session · Files: same as 5
   - Done when: an all-`ff` Sync Cursor is acknowledged and the sync completes with 0 new
     History Records.
7. [ ] **Slice:** failure rules
   - Seam: History Sync session · Files: same as 5
   - Done when: a Batch with a bad-CRC Frame is not acknowledged and the session fails with that
     reason; an error status in a reply, or a reported timeout, fails the session with the
     reason.
8. [ ] **Slice:** store, triggers and remembered Strap
   - Blocked by: 4, 7 (needs the session's timeout report from 7)
   - SwiftData History Record store keyed by Record Counter (decoded fields + raw bytes);
     sync on foreground (not started twice); remember the Strap and reconnect on relaunch; the
     10-second timer reported to the session; sync status on the main screen.
   - Seam: manual on the iPhone · Files: `src/SerenixApp/`
   - Done when: on the phone, relaunching reconnects without asking; opening Serenix syncs and
     the state reads "up to date"; Sync now straight after shows 0 new; closing mid-sync then
     syncing again leaves 0 Record Counter gaps.
9. [ ] **Slice:** full debug screen and Share log
   - Blocked by: 7, 8
   - Session reports the `0x22` data range and `0x1a` battery level (test-first, at the
     session seam); the shell reads model/firmware from Device Info. Debug screen shows the
     store stats (count, first/last Record Counter and time, gaps), last-sync count, data
     range, battery, firmware, the last 5 syncs' Sync Log, and Share log via the share sheet.
   - Seam: History Sync session (range, battery) + manual on the iPhone · Files:
     `src/SerenixCore/HistorySync*.swift`, `tests/SerenixCoreTests/HistorySyncTests.swift`,
     `src/SerenixApp/`
   - Done when: the session tests for range and battery pass; on the phone the debug screen
     shows range, battery and firmware, and Share log opens the share sheet.
10. [ ] **Verify:** full suite + lint + build green locally and in CI; every spec success
    criterion checked, with the manual steps and their results written in the PR.
    - Blocked by: 9

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
