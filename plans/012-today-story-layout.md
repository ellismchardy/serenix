# Plan: 012 — Today Story layout

**For spec:** specs/012-today-story-layout.md
**Type:** feature
**Branch:** feat/today-story-layout (already created from main; spec 012 sits there uncommitted)

## Context
You picked prototype variant C (Story timeline, `prototype/homescreen-v2`) and want a setting to
switch the Today screen between Rings (spec 002) and Story. Spec 012 is approved. On approval,
this plan is saved to `plans/012-today-story-layout.md` and committed with the spec as the
first commit; then `/execute` works it one task at a time.

## Approach
Add a `TodayStory` value to the existing `TodayView` (SerenixCore), built from values TodayView
already works out (`noNightMessage`, `timeAsleepTile`, `tiles` with `zone`, `readinessBand`,
`readinessAdvice`, `loadText`, `restingHRTile`, Night's Sleep Onset / Final Wake). Each step
says which popup a tap opens via a new core enum `StoryTap` (`.sleep`, `.metric(NightlyMetric)`,
`.readiness`, `.load`), which the shell maps onto its existing `TodayPopup`
(`src/SerenixApp/TodayPopups.swift`). The shell gets a `TodayLayout` setting stored like
`AppearanceStore` and a `StoryBodyView` swapped in under the week strip in `TodayScreen`.

## Tasks
1. [x] **Slice (tracer):** `TodayView.story` with the four steps in order and the Sleep step's
   time label ("23:18 → 06:51", local) and title ("You slept 7h 12m").
   - Seam: Today view · Files: `src/SerenixCore/TodayStory.swift` (new), `TodayView.swift`,
     `tests/SerenixCoreTests/TodayStoryTests.swift`
   - Done when: spec criteria 1–2 pass.
2. [x] **Slice:** Overnight step lists only the Night's Nightly Metrics, each with its Zone.
   - Seam: Today view · Done when: criterion 3.
3. [x] **Slice:** This morning title ("Readiness 72 — Ready"), advice; Calibrating
   ("Readiness calibrating — 2/4", no advice).
   - Seam: Today view · Done when: criterion 4.
4. [x] **Slice:** No Night → 002's message + Load step; Load label "Today so far" / "That Day".
   - Seam: Today view · Done when: criterion 5.
5. [x] **Slice:** every step and Overnight row carries its `StoryTap`.
   - Seam: Today view · Done when: criterion 6.
6. [x] **Shell:** `TodayLayout` (Rings/Story) + store in UserDefaults beside Appearance; "Today
   layout" picker in `ProfileMenu`; `StoryBodyView` drawn in `TodayScreen` under the week strip,
   taps → `openPopup`. Reuse `Theme`, `ScoreRing`, `themeCard()`, Zone colours.
   - Files: `src/SerenixApp/TodayLayoutStore.swift` (new), `StoryBodyView.swift` (new),
     `TodayScreen.swift`, `ProfileMenu.swift`
   - Done when: macOS CI builds; phone check steps written for the PR.
7. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
   `swift build` green; phone criteria 8–11 checked by hand on the sideloaded build.

## Verification
- `swift test` covers criteria 1–6 through `TodayView`.
- Lint and build locally; CI macOS job builds the `.ipa`.
- On the phone: fresh install shows Rings; switch to Story applies at once and survives
  relaunch; week strip / calendar / sync pill / pull-to-sync work; each step opens its popup;
  Light and Dark both look right.
