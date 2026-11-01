# Plan: 002 — Today screen restyle

**For spec:** specs/002-today-screen.md (restyle change approved 2026-11-01)
**Type:** improvement
**Branch:** feat/today-restyle

## Context
PR #10's redesign is merged. The owner then preferred the look of a second reference: a light
card style with a purple accent, a greeting top bar (avatar, greeting over the name, calendar
and bell buttons) and a week strip, prototyped as variant F (`?variant=F`, branch
`prototype/homescreen`). Spec 002 was changed to match; only its unticked criteria are built:
the week strip, the new greeting, the top bar and the Look with the Appearance setting. The
spec edit is uncommitted on `feat/today-restyle`; `/execute`'s first run commits it.

## Approach
Same seam: automated criteria are tested through `TodayView` (`src/SerenixCore/TodayView.swift`).
The week strip and greeting are Core decisions; the Look and Appearance are shell only (ADR
0002), checked on the phone. Tests for the replaced title / Today pill and the old greeting are
rewritten in the task that changes them (spec change, not weakening). Reuse: `Day` (re-add a
day-stepping helper, Gregorian, like the removed `adding(days:)`), `Day.midday(in:)`,
`pickerRange` / `pickerDates` (kept for the calendar button), `Profile` (trim, avatar letter),
`DayPicker` in `TodayScreen.swift`, `Avatar.swift`, and variant F's markup/CSS as the visual
reference.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [ ] **Slice:** Week strip — `TodayView` gains a week strip: title (month and year of its last
   Day), seven Days (weekday letter, date number, shown / without a Night / out of range), and
   where ‹ and › go (a week, clamped to the earliest Night's Day and today; nil when disabled).
   `title` and `showsTodayPill` go. Shell: a `WeekStripView` card under the top bar; the large
   date title and Today pill are removed; tapping a Day or an arrow shows that Day.
   - Seam: Today view · Files: `src/SerenixCore/TodayView.swift`, `WeekStrip.swift` (new),
     `Day.swift`, `tests/SerenixCoreTests/TodayViewTests.swift` (rewrite the title / pill
     tests), `src/SerenixApp/TodayScreen.swift`, `WeekStripView.swift` (new)
   - Done when: both week-strip criteria pass (1 Nov strip, picker range, 31 Oct; ‹ › 1 Nov ↔
     25 Oct with the October strip).
2. [ ] **Slice:** Greeting and top bar — the greeting becomes "Good morning!" / "Good
   afternoon!" / "Good evening!" on every Day, with the Profile name as a separate output.
   Shell top bar: avatar (opens the menu), greeting over the name in bold, a calendar button
   (opens `DayPicker`) and a bell (shows "No notifications yet.").
   - Seam: Today view · Files: `src/SerenixCore/Profile.swift`, `TodayView.swift`,
     `TodayViewTests.swift` (rewrite the greeting tests), `src/SerenixApp/TodayScreen.swift`
   - Done when: the greeting criterion passes.
3. [ ] **Slice (shell only, ADR 0002):** Look and Appearance — a `Theme` of colours (light grey
   background, white cards, soft shadow, purple accent; dark equivalents) used by the Today
   screen, tiles, rings (Sleep Score in the accent), sync pill, week strip and menus; an
   Appearance setting (System / Light / Dark) kept in UserDefaults, applied with
   `preferredColorScheme`, chosen in a new profile-menu row.
   - Seam: none (manual) · Files: `src/SerenixApp/Theme.swift` (new), `AppearanceStore.swift`
     (new), `SerenixApp.swift`, `TodayScreen.swift`, `MetricTileView.swift`, `ScoreRing.swift`,
     `SyncPillView.swift`, `WeekStripView.swift`, `BaselineComparisonRow.swift`,
     `ProfileMenu.swift`
   - Done when: `swift build` and the CI macOS job are green; the manual steps are in the PR.
4. [ ] **Verify:** full suite + lint + build green, CI macOS green; the 3 unticked automated
   criteria ticked; manual phone steps (top bar, week strip, Look/Appearance incl. Dark and
   relaunch, plus the existing ones) listed for the PR.
   - Blocked by: 3

## Verification
- `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
  `swift build` after each task.
- CI macOS job compiles the shell at `/ship`.
- On the phone with Debug → Show sample Nights: week strip and arrows, calendar and bell,
  greeting with and without a name, light/dark via Appearance (and System following iOS),
  relaunch keeps the choice; compare against prototype variant F.

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
