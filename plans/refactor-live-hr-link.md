# Plan: refactor — Live HR decisions move from StrapConnection into a SerenixCore Live HR link

**For spec:** none (refactor). Source: the task-13 reviews of spec 006
(`plans/done/006-load-popup.md`, task 13 and its "Known limit" note); behaviour stays as spec 006
and ADR 0007 describe it.
**Type:** refactor
**Branch:** chore/live-hr-coordinator

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
`StrapConnection` decides Live HR with seven interacting flags (`liveHRShown`,
`isInForeground`, `liveSession`, `liveHROnInSync`, `connectingForLiveHR`, `phaseBeforeLiveHR`,
`startLiveHRWhenReady`) plus a retry timer, and none of it can be tested off the phone. Every one
of those decisions can be made without CoreBluetooth, so they move behind one deep module in
`SerenixCore`: **`LiveHRLink`**, a pure value-type state machine (as `HistorySync` and
`LiveHRSession` are). The shell feeds it events — popup shown or hidden, foreground or
background, a sync starting or ending, Bluetooth on or off, the link connected, ready, failed or
disconnected, a retry falling due, bytes from the Strap, readings from a sync — each with a
`StrapLinkFacts` snapshot of what only the shell knows (its `StrapPhase`, whether a sync is
running or wanted, Bluetooth on, a Strap remembered, the link ready or still closing). It returns
an ordered list of `LiveHRAction`s for the shell to carry out (connect, write Frames, turn Live HR
on or off in the sync, stop scanning, cancel the attempt, disconnect, show a phase again, schedule
or cancel a retry, keep the "Live HR" Sync Log, log skipped Frames). It owns the
`LiveHRSession`, the pill's state (`LiveHRConnection`, last reading, arrival time), and the phase
a connection only for Live HR stands in for. `StrapPhase` moves to `SerenixCore` (a prefactor) so
the link can hold it, along with the sync pill's reading of it, so the "wiped sync pill"
scenarios are tested in Core.

Expand → migrate → contract: tasks 2–5 build and test `LiveHRLink` beside today's shell code
(behaviour ported line by line from `StrapConnection`, each review scenario pinned by a test);
task 6 points `StrapConnection` at it and deletes the flags, `liveHRRetryDelay` and the helpers
(`startLiveHR`, `stopLiveHR`, `beginLiveSession`, `handleLive`, `noteLiveHR`,
`endLiveHRConnection`, `scheduleLiveHRRetry`, `dropLiveSession`,
`resetLiveHRConnectionState`) — deletion test: the complexity lands in one tested place, the
shell keeps only CoreBluetooth calls. `TodayPopups.swift` keeps reading the same three published
values, so the UI doesn't change.

One behaviour fix rides along (the brief's "Known limit"): after a sync ends and closes its link,
a Live HR attempt can start before iOS reports that old link's disconnect; the stale
`didDisconnect` was taken as the new attempt ending, wiping the saved "Sync paused/failed" pill.
The link learns the `didConnect` step (`linkConnected`): a disconnect that arrives while its own
attempt hasn't connected yet and wasn't cancelled is stale and ignored. No spec change: spec 006
already says the sync pill keeps what it showed.

The shell only compiles in CI (ADR 0003); `/ship` opens the PR that runs the macOS job, and the
phone checks from spec 006's PR are repeated by hand.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Prefactor:** `StrapPhase` and the sync pill's reading of it move to `SerenixCore`
   - Files: `src/SerenixCore/StrapPhase.swift` (new), `tests/SerenixCoreTests/StrapPhaseTests.swift`
     (new), `src/SerenixApp/StrapConnection.swift`
   - Moves `StrapPhase` (`isBusy`, `displayText`) as is, and the `switch` in
     `StrapConnection.syncStatus` as `StrapPhase.syncStatus(connectionWanted:)` (Bluetooth off
     reads as unreachable only when a sync or connection was wanted).
   - Done when: tests pin each phase's `isBusy`, `displayText` and sync status to today's
     values; the shell's `syncStatus` calls it; suite, lint and build green.
2. [x] **Slice:** Live HR on its own connection, with no sync
   - Seam: `LiveHRLink` (new, agreed in this plan; not a spec seam — refactor) · Files:
     `src/SerenixCore/LiveHRLink.swift` (new), `tests/SerenixCoreTests/LiveHRLinkTests.swift` (new)
   - Done when tests show:
     - Shown in the foreground, with a remembered Strap and Bluetooth on, it connects; the pill
       reads "…"; when ready it writes hello and Live HR on; bytes from the Strap give
       readings and the pill reads the bpm; hiding it writes Live HR off, keeps the
       "Live HR" Sync Log and disconnects.
     - Hidden or in the background it doesn't connect; leaving the foreground stops it like hiding.
     - Already ready (a paired link): it starts the session without connecting.
     - **Wiped sync pill:** with the phase "failed" (or "synced") it holds that phase while its
       connection is up, `phaseForSyncPill` gives it, and ending the connection shows it again.
     - Closing while still searching stops scanning and ends at once; closing while connecting
       cancels the attempt, which then resolves quietly (ready → disconnect, restoring the phase).
     - No remembered Strap, or Bluetooth off: the pill reads "—" and nothing connects.
3. [ ] **Slice:** Live HR during a History Sync
   - Seam: `LiveHRLink` · Files: `src/SerenixCore/LiveHRLink.swift`,
     `tests/SerenixCoreTests/LiveHRLinkTests.swift`
   - Done when tests show:
     - Shown during a running sync: Live HR on in the sync (once), off on hiding; the sync
       carries on (no disconnect).
     - Readings from the sync update the pill.
     - A sync starting while Live HR streams on its own connection takes the stream over: the
       session's log is kept, held phase and attempt state are forgotten, and Live HR is on in
       the sync.
     - **Sync ending with the popup open:** no reading yet → "—"; a retry is scheduled; when it
       falls due Live HR connects on its own again, holding the sync's result phase.
     - Another connection in progress (pairing): Live HR waits and starts when that one is
       ready; a sync on its way turns it on itself.
     - **"Sync now" during a cancelled attempt:** popup closed mid-connect, then "Sync now";
       the attempt's disconnect forgets the held phase, shows "idle" and connects for the sync.
4. [ ] **Slice:** quiet failures and retries
   - Seam: `LiveHRLink` · Files: `src/SerenixCore/LiveHRLink.swift`,
     `tests/SerenixCoreTests/LiveHRLinkTests.swift`
   - Done when tests show:
     - A failure of Live HR's own attempt is quiet (stop scanning, disconnect, show the held
       phase, "—", retry in 1 s); a failure while a sync is running or wanted is not Live HR's
       (`wasLiveHRConnection` false).
     - **Stuck "…" / retry flips:** a retry keeps "—" until a reading arrives (never back to
       "…"); a reading then shows the bpm.
     - Retries are scheduled once at a time, only while wanted, and cancelled on hide.
     - **Quick close/reopen:** reopened while the cancelled attempt is still resolving, it waits
       for it: ready → the session starts; disconnect → the phase is shown again and a retry
       starts it.
     - A link still closing: retry instead of connecting.
     - Bluetooth off drops the session (log kept), forgets the attempt, "—"; Bluetooth on while
       wanted starts it again.
5. [ ] **Slice:** late callbacks (and the known-limit fix)
   - Seam: `LiveHRLink` · Files: `src/SerenixCore/LiveHRLink.swift`,
     `tests/SerenixCoreTests/LiveHRLinkTests.swift`
   - Done when tests show:
     - **Stale disconnect:** a sync fails ("Sync paused"), Live HR starts connecting, then the
       old link's disconnect arrives before `linkConnected`: it's ignored, the attempt carries
       on, and when ready Live HR starts with "Sync paused" still held (red before the fix).
     - A disconnect while streaming drops the session (log kept), "—", and retries.
     - A disconnect after the attempt connected ends it: phase shown again, retry.
     - A failure or disconnect arriving after the popup closed mid-connect still resolves
       quietly, never as a sync failing, and schedules no retry.
     - Bytes or readings after Live HR stopped change nothing.
6. [ ] **Migrate + contract (shell):** `StrapConnection` delegates every Live HR decision to
   `LiveHRLink`
   - Files: `src/SerenixApp/StrapConnection.swift`
   - Done when: the seven flags, `liveHRLog`, `liveHRRetryDelay` and the Live HR helpers are
     gone; one `apply(_ actions:)` carries out `LiveHRAction`s with CoreBluetooth and timers;
     each delegate callback and scene/popup hook passes its event and `StrapLinkFacts`; the
     three published pill values and `syncStatus` come from the link; `swift build`/lint green
     locally; the macOS CI job builds (on the PR).
7. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; CI green (both jobs); on the phone (by hand, sideloaded), spec 006
   PR checks 3–6 behave as before, and the known-limit case (fail a sync by taking the Strap
   out of range, open today's Load popup) keeps "Sync paused" while Live HR reconnects.

## Done when
- All tasks checked, suite green, CI builds the app, Live HR on the phone behaves as spec 006
  says, and `StrapConnection` holds no Live HR decision.
