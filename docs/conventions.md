# Conventions

The "how we do things here" rules. Claude reads this to match existing patterns instead of
inventing new ones.

## Naming
- Files: UpperCamelCase, named after the main type they hold (`HistoryRecord.swift`)
- Variables/functions: lowerCamelCase
- Components/classes: UpperCamelCase types (Swift API Design Guidelines)
- Tests: `<Subject>Tests.swift` under `tests/`, mirroring `src/`
- Use GLOSSARY.md terms in type names: `HistorySync`, `SleepPeriod`, `Readiness`. Never use
  WHOOP's score names (recovery, strain, sleep performance) in code or UI.

## Code patterns
- **Logic in `SerenixCore`, I/O in the shell.** If it can be decided without CoreBluetooth,
  SwiftData, HealthKit or SwiftUI, it belongs in `SerenixCore`, which imports Foundation only.
  The shell stays thin enough that testing it by hand on the phone is enough.
- Prefer value types (`struct`, `enum`) and pure functions in `SerenixCore`. Pass time in (no
  `Date()` inside logic) so it can be tested.
- Parse at the boundary: raw Strap bytes become typed History Records in one place. Nothing
  downstream sees `Data` or byte offsets.
- Decoders are per Strap model, behind one protocol, so a new model means adding a decoder.
- Algorithm constants (thresholds, windows) are named constants with a comment on the unit and
  where the value came from, as in `hr-tracker`.
- Times are stored in UTC. Convert to local time only to assign a Night or a
  Day, and for display.

## Testing
- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`)
- Every feature ships with tests; every bug fix ships with a regression test.
- Test behavior through public interfaces, at the seams the spec agrees — never internals.
- Test naming: describe the behavior, not the implementation.
- Expected values are known literals or come from the spec — never recomputed like the code.
  For algorithms ported from `hr-tracker`, the expected values are that tool's output on the
  same fixture night, committed as literals.
- Fixtures are trimmed real History Records from the project owner's own nights, published in
  this public repo with their agreement. Serial and device ID are removed. They live under
  `tests/`. Never commit raw `.pklg` captures or sysdiagnoses.
- When no real capture has a case (e.g. an SpO2 Window), a test may edit a real fixture Frame:
  its comment names the bytes changed and their values, and the CRC is recomputed.
- Mock only at system boundaries (external APIs, time, randomness); don't mock what you don't
  own without a wrapper. Full rules: `.claude/skills/tdd/`.
- The shell (BLE, SwiftData, HealthKit, UI) is checked by hand on a real phone, with the steps
  listed in the PR.

## Code review
- Every task and every PR is reviewed on two separate axes: **spec** (`spec-reviewer`) and
  **standards** (`standards-reviewer`). Blocking findings are fixed before commit/merge.
- This file *is* the standards the reviewer enforces. Mechanical rules (banned APIs, import
  shapes, file locations) belong in the linter or a hook instead; keep this file for judgement
  calls.
- Solo project: the author merges their own PRs once both review axes and CI are green.

## Git
- Branch per change: `feat/<name>`, `fix/<name>`, `chore/<name>`. `prototype/<name>` branches
  hold throwaway prototypes and are never merged.
- Commit after each completed (green) plan task.
- Commit messages: imperative mood, present tense ("add login validation").
- One PR per branch, body from `.github/pull_request_template.md`, squash-merged to `main`
  with green CI.
- Issues are tracked in GitHub Issues.

## Definition of done
- [ ] Meets the spec's success criteria
- [ ] Tests pass (new + existing), locally and in CI
- [ ] Lint (`swift format lint`) + build clean, and the macOS CI job builds the app
- [ ] Both review axes clear of blocking findings
- [ ] Spec still reads true; GLOSSARY.md updated for new terms; an ADR in `docs/adr/` if a
      hard-to-reverse choice was made
