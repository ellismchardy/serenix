# Plan: refactor — StrapConnection follow-ups from PR #6

**For spec:** none (refactor). Source: the whole-branch standards review of PR #6 (History
Sync, `plans/done/001-history-sync.md`), whose three Should-fix items were deferred.
**Type:** refactor
**Branch:** chore/strap-connection-isolation

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
No behavior change. Two decisions still live in the shell and can't be tested on Windows: how a
`HistorySyncFailure` reads, and the 10-second "Strap stopped responding" rule. Both move behind
`HistorySync`'s interface, test-first, so `StrapConnection` only reports times and draws text
(deletion test: the shell's `reason(for:)`, `lastHeardFromStrap` and `strapSilenceTimeout`
disappear; `reportTimeout()` is replaced, not layered on). Then the shell's two background
jobs (store-stats refresh, Sync Log save) are chained so each waits for the one before, and
`StrapConnection` becomes a `@MainActor` class with `@preconcurrency` delegate conformances
(SE-0423: CoreBluetooth's main-queue callbacks are checked at run time) instead of
`@unchecked Sendable`. Shell tasks only compile in CI (ADR 0003), so each is a small commit.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [ ] **Slice:** a `HistorySyncFailure` gives its own failure reason
   - Seam: `HistorySyncFailure.reason` (public, `SerenixCore`) · Files:
     `src/SerenixCore/HistorySync.swift`, `tests/SerenixCoreTests/HistorySyncTests.swift`,
     `src/SerenixApp/StrapConnection.swift`
   - Done when: a test pins each case's text to today's wording; the shell's `reason(for:)` is
     gone and it shows `failure.reason`.
2. [ ] **Slice:** a History Sync times itself out after 10 s without hearing from the Strap
   - Seam: `HistorySync.timeOutIfSilent(at:)` · Files: `src/SerenixCore/HistorySync.swift`,
     `tests/SerenixCoreTests/HistorySyncTests.swift`, `src/SerenixApp/StrapConnection.swift`
   - Done when: tests show silence of 10 s since `start` or the last `receive` fails the sync
     as `.timedOut`, just under 10 s doesn't, and a completed sync stays completed;
     `reportTimeout()`, the shell's `lastHeardFromStrap` and `strapSilenceTimeout` are gone.
3. [ ] **Prefactor (shell):** serialise store-stats refreshes and Sync Log saves
   - Files: `src/SerenixApp/StrapConnection.swift`
   - Done when: each refresh and each save awaits the previous one's task, so stats can't land
     out of order and two saves never prune together; CI builds the app.
4. [ ] **Prefactor (shell):** `StrapConnection` is `@MainActor`, not `@unchecked Sendable`
   - Files: `src/SerenixApp/StrapConnection.swift` (and its callers only if CI demands it)
   - Done when: no `@unchecked Sendable` or `MainActor.run` hops on its own state remain;
     the delegate conformances are `@preconcurrency`; timers hop with
     `MainActor.assumeIsolated`; CI builds the app under Swift 6 strict concurrency.
5. [ ] **Verify:** `swift test`, lint and `swift build` green; CI green; the phone steps in
   `plans/done/001-history-sync.md` behave as before (by hand, sideloaded).

## Done when
- All tasks checked, suite green, CI builds the app, a sync on the phone behaves as before.
