# Plan: 002 — Today screen redesign

**For spec:** specs/002-today-screen.md (change approved 2026-11-01)
**Type:** improvement
**Branch:** feat/today-redesign

## Context
Spec 002 shipped in PR #9. From reference screenshots the owner shared, the spec was changed:
a date-picker top bar with a Today pill, a greeting by name from a local-only Profile, a sync
pop-up pill (syncing / successful / paused / failed), tiles with a status word and gauge
instead of trend lines, and a restyled profile menu. Only the unticked success criteria are
built; ticked ones already exist. The spec, GLOSSARY.md (Profile) and docs/architecture.md
edits are uncommitted on `feat/today-redesign`; `/execute`'s first run commits them.

## Approach
Same seam as before: every automated criterion is tested through `TodayView`
(`src/SerenixCore/TodayView.swift`), whose inputs gain the Profile name and the kind of sync
failure. Tests whose criteria changed (arrows, trend lines, the old pill states) are rewritten
or removed in the task that changes them — that's following the spec, not weakening tests.
Reuse: `Baseline`, `Zone` (its cut-off constants feed the gauge), `recentNights` in
`Trend.swift` (still used by the popup chart), `clockText`, `Day.text`, `missingText`. Each
slice also changes the shell it draws, checked by the CI macOS build and on the phone.

Decided with the owner in plan review: a sync the user cancels (001's Cancel) shows **no
pill**, rather than "Sync failed". The spec doesn't say this yet, so task 3 adds it to the
spec's Sync pill section and to the "which sync pill shows" criterion (unticked) as part of
its change — an approved clarification of desired behaviour, not a plan decision.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Slice:** Top bar — the title is the Day's date ("Sun 1 Nov"), the date picker's range
   (earliest Night's Day … today; today … today with no Nights) and whether the Today pill
   shows; `earlierDay`/`laterDay`/`subtitle` go. Shell: large date title with ▾ opening a
   graphical `DatePicker` limited to that range, Today pill, avatar placeholder (person icon)
   at top right opening the profile menu; arrows removed.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift` (rewrite the arrows tests),
     `src/SerenixApp/TodayScreen.swift`
   - Done when: the date picker / Today pill criterion passes.
2. [x] **Slice:** Profile and greeting — `TodayView` takes the Profile name; outputs the
   greeting (on today only, by local hour bands; trimmed name, blank = none), the avatar letter
   and the menu header's name ("Add your name"). Shell: `ProfileStore` (name in UserDefaults,
   on device only), first-launch "What should we call you?" prompt with Continue / Skip shown
   once, greeting under the top bar, avatar letter in the top bar.
   - Seam: Today view · Files: `src/SerenixCore/Profile.swift` (new), `TodayView.swift`,
     `TodayViewTests.swift`, `src/SerenixApp/ProfileStore.swift`, `NamePrompt.swift` (new),
     `SerenixApp.swift`, `TodayScreen.swift`
   - Done when: the greeting and avatar-letter criteria pass.
3. [x] **Slice:** Sync pop-up pill — `SyncStatus` becomes syncing (incl. connecting) /
   just finished / idle / failed(reason, cause: Strap unreachable or other); `SyncPill` gains a
   kind (syncing, successful, paused, failed), text and detail; no pill when idle.
   Shell: `StrapPhase.failed` carries the cause (not found, couldn't connect, Bluetooth
   off/unavailable, disconnected → unreachable; a user Cancel → idle, no pill; everything else
   → other); a pill overlay that
   slides down, auto-hides "Sync successful" after 3 s, keeps paused/failed until tapped or
   swiped (tap: reason + Retry; syncing: Cancel); pull-to-refresh starts a sync; the profile
   menu's "Retry sync" also after a paused sync. Rewrites the old pill test ("Not synced",
   "Synced 08:10").
   - Seam: Today view · Files: `specs/002-today-screen.md` (the Cancel line),
     `src/SerenixCore/SyncStatus.swift`, `TodayView.swift`, `TodayViewTests.swift`,
     `src/SerenixApp/StrapConnection.swift`, `SyncPillView.swift` (new), `TodayScreen.swift`,
     `ProfileMenu.swift`
   - Done when: the "which sync pill shows" criterion passes, including a cancelled sync → no
     pill.
4. [ ] **Slice:** Tiles — `MetricTile` gains a status word ("Normal" / "Low" / "High", SpO2's
   level words, "Calibrating", "—") and a gauge position (0.5 + d / (2 × Watch limit), clamped;
   SpO2 88–100%; nil when Calibrating or missing); the tile `trend` and Time Asleep `trend` go
   (popup chart keeps `recentNights`). Shell: tile with icon, value, ✓ status word and a
   vertical gauge in the Zone colour; no trend line.
   - Seam: Today view · Files: `src/SerenixCore/MetricTile.swift`, `Zone.swift` (expose
     Watch limits), `TimeAsleepTile.swift`, `TodayViewTests.swift` (remove trend-line tests),
     `src/SerenixApp/MetricTileView.swift`
   - Done when: the status-word, gauge-position and no-trend-line criteria pass.
5. [ ] **Slice (shell only, ADR 0002):** Profile menu restyle — ✕ to close; header with the
   large avatar and name ("Add your name"), tapping edits the name; grouped rounded rows:
   Connected · model (Not found before pairing), battery, last sync, Sync now / Retry sync;
   Debug; footer.
   - Seam: none (manual) · Files: `src/SerenixApp/ProfileMenu.swift`
   - Done when: `swift build` and the CI macOS job are green; manual steps in the PR checklist.
6. [ ] **Verify:** full suite + lint + build green, CI macOS green; every unticked automated
   criterion ticked; manual phone steps (incl. the sample-Nights walk-through and "name not in
   the shared Sync Log") listed for the PR.
   - Blocked by: 5

## Verification
- `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
  `swift build` after each task.
- CI macOS job compiles the shell at `/ship`.
- On the phone with Debug → Show sample Nights: date picker and Today pill, greeting after
  the first-launch prompt, the sync pill states (turn Bluetooth off for "paused"), tiles'
  status words and gauges, profile menu editing the name, shared Sync Log without the name.

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
