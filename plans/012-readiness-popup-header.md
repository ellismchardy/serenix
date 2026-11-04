# Plan: 012 — Readiness popup header as a band scale

**For spec:** specs/012-readiness-popup.md
**Type:** improvement
**Branch:** feat/readiness-popup

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
Spec 012 was built (plans/done/012-readiness-popup.md) and its header has since changed from a
ring to header prototype variant B. Only the three unticked "Band scale" criteria and the by-hand
check are new; `git diff specs/012-readiness-popup.md` shows the change. This goes onto the same,
still-open branch (PR #44) by the user's choice, so the phone check covers the final design.
`ReadinessBand` already holds the cut-offs (67, 34) as private constants: it gains each band's
stretch of 0 to 1 from them, and the popup gains the scale (segments, marker, usual tick) next to
its band. No existing test pins the ring, so none need rewriting; the shell's ring card and its
`fill` argument go in the redraw.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice:** band scale in the popup content: `ReadinessBand` gives each band's from–to
   stretch of 0 to 1 from its cut-offs; `ReadinessPopup` gains the scale's three segments
   (always), and its marker (Readiness / 100) and usual-Night tick (0.70, from the usual
   Night's Readiness) — none of either while Calibrating or missing.
   - Seam: Today view · Files: `src/SerenixCore/ReadinessBand.swift`,
     `src/SerenixCore/Popups.swift`, `src/SerenixCore/TodayView.swift`,
     `tests/SerenixCoreTests/ReadinessPopupTests.swift`, `specs/012-readiness-popup.md` (the
     approved edit, committed with this task)
   - Done when: the three "Band scale" criteria pass (segments 0–0.34, 0.34–0.67, 0.67–1 on
     every Night; markers 0.70 / 0.38 Steady / 0.07 Take it easy with the tick at 0.70; no
     marker or tick while Calibrating or with no HRV).
2. [ ] **Shell:** redraw the popup's top card in variant B's layout: large number in the band's
   colour with the band word, the verdict, and the band scale (Night's band full colour, others
   faded, marker, "usual 70" tick, band words under their segments); greyed number and an
   all-faded scale with no marker while Calibrating or missing. Drop the ring card and the
   view's `fill` argument.
   - Files: `src/SerenixApp/TodayPopups.swift`
   - Done when: the shell uses only the popup content's scale fields (no maths on display
     text); suite still green; the shell compiles on CI.
3. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`
   and `swift build` green; spec 012's Band scale criteria ticked, status back to `built`.
   Carried to the PR checklist (#44): the macOS CI build, and the by-hand phone check with the
   band scale (number and band word, verdict, scale and marker, Why list, Your week, Sleep
   Score, Light and Dark, closes on a tap outside or a swipe down).

## Done when
- All tasks checked, every success criterion in spec 012 met, suite green.
