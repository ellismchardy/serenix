# Plan: 004 — Baseline and Zones

**For spec:** specs/004-baseline-and-zones.md
**Type:** feature
**Branch:** feat/baseline-and-zones

> Disposable. Once every task is merged, move this file to plans/done/.

## Context
Spec 002 shipped Zones with the prototype's fixed cut-offs (HRV −5%/−15% low only, Resting HR
+1/+4). Issue #14 settled evidence-based rules, which spec 004 (approved) now owns: a Spread on
each Baseline (scaled MAD, ln for HRV, floors, a typical value under 7 earlier Nights), HRV and
respiratory rate scaled by it, Resting HR +3/+5 up only, skin temperature and SpO2 unchanged.

**Spec amendment (done in planning):** Resting HR and skin temperature Spreads aren't
observable through the Today view seam, so spec 004 now gives a Spread only to HRV and
respiratory rate; Resting HR's comes with the Readiness spec.

## Approach
One seam, as the spec says: `TodayView` (public), driving tiles (`zone`, `statusText`, `gauge`)
and `metricPopup` (`inRangeLow/High`). Core changes sit in:
- `src/SerenixCore/Baseline.swift` — gains `spread: Double?` (nil while Calibrating; nil for
  metrics without a Spread). Reuses its `median(of:)` for the MAD.
- `src/SerenixCore/Zone.swift` — `init?`, `gaugePosition`, `inRangeLimits` take a `Baseline`
  (median + Spread) instead of `Double?`. Keeps `atLeast` / `atMost` and `boundaryTolerance`.
- `src/SerenixCore/MetricTile.swift` — keeps the `Baseline` it builds (public `baseline: Double?`
  stays the median), passes it to Zone. `Popups.swift` passes it to `inRangeLimits`.
No shell changes. Existing tests whose expected values the spec replaced are rewritten in the
task that changes them (following the spec, not weakening): in
`tests/SerenixCoreTests/TodayViewTests.swift`, `hrvZoneAgainstABaselineOf60`,
`restingHRZoneAgainstABaselineOf52`, `respiratoryRateZoneAgainstABaselineOf14`,
`tileStatusWordAgainstExactBaselines`, the gauge-position test (~l.826) and
`metricPopupShowsTheBaselineAndItsInRangeLimits`. `exactBaselinesBeforeNov1` (3 earlier Nights)
gives the typical Spread the spec's examples assume.

## Tasks (ordered; each one red→green cycle, committed on its own)

1. [x] **Prefactor:** Zone takes the Baseline — `Zone.init?`, `gaugePosition`, `inRangeLimits`
   accept `Baseline?` (reading its median); `MetricTile` keeps its `Baseline`; `Popups` passes it.
   No behavior change.
   - Files: `Zone.swift`, `MetricTile.swift`, `Popups.swift`, `Baseline.swift` (if an init for
     the no-Baseline SpO2 case is needed)
   - Done when: existing suite green, unchanged.
2. [x] **Slice (tracer):** HRV Spread-scaled Zone — `Baseline.spread` = typical value (HRV 0.15
   ln) once not Calibrating; HRV Zone on z = (ln value − ln median) / Spread, In range −1.5…+2.5,
   Watch down to −2.5 and anything above +2.5, never Out of range high.
   - Seam: Today view · Files: `Baseline.swift`, `Zone.swift`, `TodayViewTests.swift` (rewrite
     `hrvZoneAgainstABaselineOf60`)
   - Done when: criterion "HRV against Baseline 60 with the typical Spread: 48 … 200 is Watch".
3. [x] **Slice:** Respiratory rate Spread-scaled Zone — typical Spread 0.5 br/min; |z| ≤ 1.5 In
   range, ≤ 2.5 Watch.
   - Seam: Today view · Files: `Baseline.swift`, `Zone.swift`, `TodayViewTests.swift` (rewrite
     `respiratoryRateZoneAgainstABaselineOf14`)
   - Done when: criterion "Respiratory rate against Baseline 14.0 with the typical Spread …".
4. [ ] **Slice:** Resting HR fixed gap, up only — d < 3 In range, 3 ≤ d < 5 Watch, d ≥ 5 Out.
   - Seam: Today view · Files: `Zone.swift`, `TodayViewTests.swift` (rewrite
     `restingHRZoneAgainstABaselineOf52`)
   - Done when: criterion "Resting HR against Baseline 52: 54.9 … 40 is In range"; skin
     temperature and SpO2 Zone tests still pass unchanged.
5. [ ] **Slice:** Scaled MAD Spread — with ≥ 7 earlier Nights (all with a value, not only the 14
   used), Spread = 1.4826 × median |x − median| over the same up-to-14 Nights, HRV on ln, floored
   (HRV 0.10, respiratory rate 0.3); 3–6 Nights keep the typical value.
   - Seam: Today view · Files: `Baseline.swift`, `TodayViewTests.swift` (new tests)
   - Done when: the Spread criteria pass: typical→floored switch (14.8 Watch with 6, Out with 7),
     scaled MAD 0.59304 Zones (14.88/13.12 In, 14.9/13.11/15.48 Watch, 15.49/12.5 Out), HRV floor
     (50 vs seven 60s Watch, vs three In; 54 In), HRV ln Spread Zones (40.1 In, 39.9 Watch), and
     the 14-Night window (6 oldest wild values change nothing).
6. [ ] **Slice:** Gauge positions and status words — HRV and respiratory rate 0.5 + z / 5;
   Resting HR 0.5 + d / 10; skin temperature and SpO2 unchanged. Status words follow the new
   Zones (HRV can be "High").
   - Seam: Today view · Files: `Zone.swift`, `MetricTile.swift` (only if `statusWord` needs a
     change), `TodayViewTests.swift` (rewrite `tileStatusWordAgainstExactBaselines` and the gauge
     test)
   - Done when: the status-word and gauge-position criteria pass.
7. [ ] **Slice:** Popup In range band — HRV exp(ln B − 1.5S)…exp(ln B + 2.5S); respiratory rate
   B ± 1.5S; Resting HR none…B + 3; skin temperature B ± 0.3; SpO2 none.
   - Seam: Today view · Files: `Zone.swift`, `TodayViewTests.swift` (rewrite
     `metricPopupShowsTheBaselineAndItsInRangeLimits`; add the MAD band 13.11–14.89 and the HRV
     ln band 40.00–117.93 checks)
   - Done when: the band criterion and the band parts of the MAD and ln-Spread criteria pass.
8. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests Package.swift`,
   `swift build` green, and the CI macOS job builds; every automated criterion in 004 ticked;
   the manual phone step (tile Zone, status word and gauge match the Today view on real Nights)
   listed for the PR.

Tasks touch the same files (`Zone.swift`, `Baseline.swift`, `TodayViewTests.swift`), so all run
in order: no `Blocked by:` parallelism.

## Verification
- Each task: its new/rewritten tests red first, then green; full `swift test` green before
  commit.
- Constants: every floor, typical value, cut-off, the 7-Night switch and 1.4826 are named
  constants with unit and source ("issue #14; docs/research/nightly-metric-deviation.md;
  assumption: tune with real Nights").
- End: lint + build + CI macOS; spec-reviewer and standards-reviewer clear.

## Done when
- All tasks checked, every automated success criterion in spec 004 met, suite green.
