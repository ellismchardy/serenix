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
Spec change (31 Oct, ADR 0006): a sync that has started finishes in the background. It needs
task 8's 10-second timer and "not started twice", so it is a shell-only slice (task 9) between
the store and the full debug screen; the session doesn't change.
Spec change (31 Oct, issue #7): sync progress and time left. The session works them out from
the times passed in (test-first), and the main screen draws them; task 10, ahead of the
background checks, so they can be watched during those.

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
2. [x] **Slice:** History Record decoder
   - Decode per-second `0x2f` Frames (Record Counter, timestamp, HR, RR, motion, skin
     temperature, steps, SpO2, raw bytes) behind a per-Strap-model interface. Ignore the
     optical-burst variant. Expected values come from `hr-tracker/tools/history.py` run once
     over the fixture Frames, committed as literals (it reads `.pklg`, so feed it the hex).
   - Seam: History Sync session (decoder underneath it) · Files: `src/SerenixCore/HistoryRecord*.swift`,
     `tests/SerenixCoreTests/HistoryRecordTests.swift`
   - Done when: decoded Record Counter, timestamp and HR match the committed literals.
3. [x] **Slice:** History Sync session, happy path for one sync
   - Pure state machine: handshake in the captured order (no `0x03`, no `0x3f`, clock from the
     time passed in) → `0x22` → `0x16` → per Batch keep History Records and echo the Sync
     Cursor in `0x17` → complete on the Strap's "complete" Frame. Every Frame in or out becomes
     a Sync Log entry.
   - Seam: History Sync session · Files: `src/SerenixCore/HistorySync*.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when: replaying one captured sync sends the captured op codes and arguments in order
     (minus `0x03`/`0x3f`, clock from the test); each `0x17` carries the preceding Batch end's
     8 Sync Cursor bytes; every Frame appears in the Sync Log with its direction.
4. [x] **Slice:** first real sync on the phone (tracer through the shell)
   - Blocked by: 3
   - CoreBluetooth Strap connection (scan, connect, pair, subscribe to the four notify
     channels, write with response), a minimal "Connect Strap" screen, a "Sync now" button, and
     a bare debug screen listing the Sync Log and the count of History Records received (in
     memory only for now). Also `NSBluetoothAlwaysUsageDescription` in `project.yml`.
   - Seam: manual on the iPhone (CLAUDE.md rule 2) · Files: `src/SerenixApp/`, `project.yml`
   - Done when: on the phone, Connect Strap + Sync now completes a sync and the debug screen
     shows History Records received > 0 and the Sync Log. Records the answer to the spec's
     pairing open question in the PR.
   - **Result on the phone (31 Oct 2026), for the PR:**
     - **Pairing:** the iPhone's existing pairing works. "Connect Strap" connected in about a
       second with no pairing prompt. It doesn't connect on launch yet (task 8).
     - **Sync:** 101,424 Frames in 6 min 28 s (~232 History Records/s), 1,579 Batches all
       acknowledged and answered OK, then "complete": 90,044 History Records from 30 Oct
       13:29 to 31 Oct 18:17 UTC. No bad CRCs or failures.
     - **First attempt stalled** when the phone locked mid-sync (Serenix suspended). The Strap
       had taken the last acknowledgement, so the next sync carried on with no gap. This led
       to ADR 0006 (finish in the background).
     - **Found:** redrawing on every Frame made a big sync crawl, and the Sync Log couldn't
       leave the phone. Fixed by redrawing twice a second and a basic Share log.
     - **For task 8:** the Strap likely rebooted at ~18:17 (its uptime in the logs). Right
       after, Record Counter 3,155,039 was used for two different records, so keying the store
       on Record Counter alone would drop one, and nothing was recorded 18:17–19:00. Also a
       hole of 875 Record Counters on 30 Oct 15:06–15:21 that the Strap never sent.
5. [x] **Slice:** full-capture replay and de-duplication
   - Blocked by: 3
   - The session ignores a Record Counter it has already yielded in this sync. Across syncs,
     de-duplication is the store's unique Record Counter key (task 8), checked by hand.
   - Seam: History Sync session · Files: `src/SerenixCore/HistorySync*.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when: replaying the whole capture yields exactly 1,036 History Records, each Record
     Counter once; replaying a Batch twice yields no duplicates.
6. [x] **Slice:** empty Batch
   - Seam: History Sync session · Files: same as 5
   - Done when: an all-`ff` Sync Cursor is acknowledged and the sync completes with 0 new
     History Records.
7. [x] **Slice:** failure rules
   - Seam: History Sync session · Files: same as 5
   - Done when: a Batch with a bad-CRC Frame, or with a per-second `0x2f` Frame the decoder
     rejects (`HistoryRecordError`), is not acknowledged and the session fails with that
     reason; an error status in a reply, or a reported timeout, fails the session with the
     reason.
8. [x] **Slice:** identify History Records by Record Counter and timestamp
   - Blocked by: 5 (changes its in-sync de-duplication)
   - The session skips a History Record only when it has already yielded one with the same
     Record Counter *and* timestamp in this sync; one that only shares a Record Counter is
     yielded. Test with an edited fixture Frame: a per-second record of connection 2 with only
     its timestamp changed, CRC recomputed (docs/conventions.md, Testing), fed after the
     original, as after a Strap reboot; and that Frame fed twice.
   - Seam: History Sync session · Files: `src/SerenixCore/HistorySync.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`
   - Done when: the spec criterion passes (same Record Counter, different timestamps: both
     yielded; same Record Counter and timestamp again: none), and the full-replay and
     Batch-twice tests still pass.
9. [x] **Slice:** store, triggers and remembered Strap
   - Blocked by: 4, 7, 8 (needs the session's timeout report from 7 and its key from 8)
   - SwiftData History Record store keyed by Record Counter and timestamp (decoded fields +
     raw bytes);
     sync on foreground (not started twice); remember the Strap and reconnect on relaunch; the
     10-second timer reported to the session; sync status on the main screen.
   - Seam: manual on the iPhone · Files: `src/SerenixApp/`
   - Done when: on the phone, relaunching reconnects without asking; opening Serenix syncs and
     the state reads "up to date"; Sync now straight after shows 0 History Records received.
     (The 0-gaps check after closing mid-sync moved to task 11, which adds the gap count.)
   - **Result on the phone (31 Oct 2026), for the PR:** after one "Connect Strap", relaunching
     reconnected and synced by itself and read "Up to date"; 84 History Records received and 84
     stored. "Sync now" straight after received ~8 while the Strap was worn (new seconds, not
     re-sends) and 0 with it off the wrist, stored unchanged. The Strap seems to record only
     while worn: a sync after it was mostly off the wrist received 0.
10. [x] **Slice:** sync progress and time left
   - Blocked by: 9 (draws on its main-screen sync status)
   - The session reports its progress (none before the first History Record; then from the
     first History Record's timestamp to the start time passed in, measured by the newest one
     so far, never decreasing, clamped to 0–1) and its time left (none until 2 seconds after
     the first History Record arrived; then the time since it arrived × (1 − progress) ÷
     progress). Test with connection 2 of the capture replayed at known times, expected values
     worked out by hand from the fixture's timestamps and committed as literals; and the empty
     sync of connection 1. The main screen shows "Starting…", then a progress bar and "about N
     min left" (rounded up) or "less than a minute left".
   - Seam: History Sync session + manual on the iPhone · Files:
     `src/SerenixCore/HistorySync*.swift`, `tests/SerenixCoreTests/HistorySyncTests.swift`,
     `src/SerenixApp/`
   - Done when: the spec's three progress criteria pass (progress over a replay, time left at
     known times, an empty sync with no progress); on the phone, a sync of at least an hour's
     backlog shows "Starting…", a filling bar and a falling time left, and ends "Up to date".
   - **Result on the phone (1 Nov 2026), for the PR:** a night's backlog (27,793 History
     Records, 2 min 23 s) showed "Starting…", then the bar and "about 5 min left" falling to
     "less than a minute left" as it filled, and ended "Up to date"; the screen stayed
     responsive. The first estimate was high (the start of a sync is slower)
     and settled as it ran.
11. [x] **Slice:** finish a started sync in the background
   - Blocked by: 9 (needs its 10-second timer and the "not started twice" rule)
   - Built and committed (104ea06); waiting only on its phone checks, which need a real
     backlog (a night's wear), so it's ticked after them.
   - **Lock and switch apps passed (1 Nov 2026):** the same sync, with the phone locked and
     then another app in front, kept receiving Frames throughout (longest gap 0.2 s, ~194
     History Records/s, one handshake, 0 Record Counter gaps) and ended "Up to date".
   - **Out of range passed (1 Nov 2026):** a sync started with the phone locked, then carried
     away, stopped mid-Batch (45 Batches acknowledged, last acknowledged Record Counter
     3,185,603) and showed "The Strap disconnected mid-sync". The next sync near the Strap
     started at Record Counter 3,185,604, re-received the unacknowledged Batch without storing
     it twice, completed, and left 0 Record Counter gaps across both.
   - Declare iOS's Bluetooth background mode (central role, `UIBackgroundModes:
     bluetooth-central`) in `project.yml`; no state restoration. Timers don't run while iOS
     keeps Serenix suspended between Bluetooth events, so the shell measures the 10 seconds
     from the last Frame and also checks it when the next Frame arrives and when Serenix
     returns to the foreground, reporting the timeout to the session if it has passed.
     Returning to Serenix during a running sync shows that sync and starts no other.
   - Seam: manual on the iPhone · Files: `project.yml`, `src/SerenixApp/`
   - Done when: on the phone, the spec's three background checks pass: a backlog sync with the
     phone locked straight away reads "Up to date" on unlock, with Frames logged throughout
     the lock; switching apps for a minute mid-sync logs Frames from that minute with no
     second handshake; taking the Strap out of range mid-sync while locked shows the failure
     with a reason, and the next sync leaves 0 Record Counter gaps.
12. [x] **Slice:** full debug screen and Share log
   - Blocked by: 7, 9
   - Session reports the `0x22` data range and `0x1a` battery level (test-first, at the
     session seam); the shell reads model/firmware from Device Info. Debug screen shows the
     store stats (count, first/last Record Counter and time, gaps), last-sync count, data
     range, battery, firmware, the last 5 syncs' Sync Log, and Share log via the share sheet.
   - Already there from task 4 (pulled forward to diagnose the first phone sync): a basic
     Share log of the current sync, as text from `src/SerenixCore/SyncLogText.swift`, and a
     debug list of the newest 200 entries. Extend these to the last 5 syncs.
   - Seam: History Sync session (range, battery) + manual on the iPhone · Files:
     `src/SerenixCore/HistorySync*.swift`, `tests/SerenixCoreTests/HistorySyncTests.swift`,
     `src/SerenixApp/`; also `src/SerenixCore/HistoryRecord.swift` and
     `tests/SerenixCoreTests/HistoryRecordTests.swift` for the Record Counter gap count (pure,
     so in `SerenixCore` and test-first)
   - Done when: the session tests for range and battery pass; on the phone the debug screen
     shows range, battery and firmware, and Share log opens the share sheet; closing Serenix
     mid-sync then syncing again leaves 0 gaps between the first and last Record Counter of the
     interrupted and resumed syncs (moved from task 9).
   - **Result on the phone (1 Nov 2026), for the PR:** Settings → Debug shows the Strap's
     name, model, firmware, battery and 0x22 data range, and the stored History Records' count,
     first and last Record Counter and time, and gaps. Share log opened the share sheet with
     both syncs since the new build, each headed `# sync …`. The 0-gaps check across an
     interrupted and resumed sync passed with task 11's out-of-range test.
13. [x] **Verify:** full suite + lint + build green locally and in CI; every spec success
    criterion checked, with the manual steps and their results written in the PR.
    - Blocked by: 10, 11, 12
    - **Result (1 Nov 2026):** lint, build and 53 tests green locally and in CI (run
      41276335861). All 16 automated spec criteria have named passing tests. All 9 manual
      criteria passed on the phone (results under tasks 4 and 9–12). Closing Serenix mid-sync:
      the closed sync acknowledged Record Counters up to 3,186,723, the next sync started at
      3,186,724, and the store shows 0 gaps. Found while checking: the debug Sync Log lacked
      each Frame's type, which the spec lists; added. **For the PR, known limit:** a sync iOS
      or the user ends outright never saves its Sync Log (its History Records are stored).

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
