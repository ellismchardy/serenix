# Plan: 002/013 — Resting HR on a Day with no Night

**For spec:** specs/002-today-screen.md (No Night for the Day) and specs/013-today-story-layout.md
(step 4) — both changed and approved
**Type:** improvement
**Branch:** feat/resting-hr-without-night (made from main; the two spec edits sit there uncommitted)

## Context
Resting HR belongs to the Day (spec 007), but `TodayView` only makes the Resting HR tile and
popup when the Day has a Night (`src/SerenixCore/TodayView.swift:166`, `night.map`). So on a Day
with no Night neither layout shows it. The specs now say: show it whenever the Day has a Resting
HR, and show nothing when it has neither. On approval this plan is saved as
`plans/002-resting-hr-without-night.md` and committed with the spec edits; `/execute` works it.

## Tasks
1. [x] **Slice:** `TodayView` gives `restingHRTile` and `restingHRPopup` when the Day has a Night
   (as now, "—" if no value) or, with no Night, when its Day Load has a Resting HR; neither
   with no Night and no Resting HR. `gridTiles` is unchanged (it's built from Nightly Metric
   tiles, so stays empty without a Night).
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/TodayViewTests.swift`
   - Done when: spec 002's new test criterion — no-Night Day with Resting HR 58 → tile "58 bpm",
     "So far today" on today / nil status earlier, and a popup; no Resting HR → neither.
2. [ ] **Shell (Rings):** in `tiles(_:)` (`src/SerenixApp/TodayScreen.swift:190`), when
   `noNightMessage != nil` and `restingHRTile` exists, draw it alone (half width, like a grid
   cell) as a button opening `.restingHR` — reuse `RestingHRTileView`. Story needs no change:
   `StoryBodyView`'s Load card already reads `today.restingHRTile`.
   - Files: `src/SerenixApp/TodayScreen.swift`
   - Done when: lint clean; phone steps listed for the PR.
3. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
   `swift build`; mark both specs built and tick the test criterion; move plan to done.

## Verification
- `swift test` covers the Today view criterion.
- macOS CI builds the app; on the phone, a Day with no Night but a Resting HR shows the tile in
  Rings (tap → Resting HR popup) and the Resting HR line on the Story's Load card.
