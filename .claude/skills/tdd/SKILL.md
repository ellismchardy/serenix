---
name: tdd
description: Test-driven development reference — what a good test is, where tests go (seams), anti-patterns, and the red→green rules. Use whenever writing or reviewing tests, building a feature or fixing a bug test-first, or when the user mentions TDD, "red-green", or integration tests.
---

# Test-Driven Development

TDD is the red → green loop. This is the reference that makes the loop produce tests worth
keeping. Consult it before and during the loop, not after.

Read `GLOSSARY.md` so test names use the project's domain language, and respect ADRs in
`docs/adr/` for the area you're touching. The test framework and naming style live in
`docs/conventions.md`.

## What a good test is
Tests verify **behavior through public interfaces**, not implementation details. The code can
change entirely; the tests shouldn't. A good test reads like a specification ("user can check
out with a valid cart") and survives refactors because it doesn't care about internal structure.
Examples: [tests.md](tests.md). Mocking rules: [mocking.md](mocking.md).

## Seams: where tests go
A **seam** is the public boundary you test at — where you observe behavior without reaching
inside. Tests live at seams, never against internals.

**Test only at agreed seams.** The spec's *Seams under test* section lists them. If you need a
seam the spec doesn't list, stop and confirm it with the user first, giving a one-line note on
what it catches and what it misses. Prefer existing seams to new ones, and the highest seam that
still gives a fast, deterministic signal — the fewer seams, the better.

## Anti-patterns
- **Implementation-coupled** — mocks internal collaborators, tests private methods, asserts on
  call counts/order, or verifies through a side channel (querying the DB instead of using the
  interface). The tell: it breaks on a refactor that didn't change behavior.
- **Tautological** — the expected value is recomputed the way the code computes it
  (`expect(add(a, b)).toBe(a + b)`), so it passes by construction. Expected values must come from
  an independent source: a known literal, a worked example, the spec.
- **Horizontal slicing** — writing all the tests first, then all the implementation. Bulk tests
  verify *imagined* behavior and lock in structure before you understand the problem. Work in
  **vertical slices**: one test → one minimal implementation → repeat, each a tracer bullet that
  responds to what the last cycle taught you.
- **Weakened to pass** — loosening an assertion, skipping a case, or special-casing an input so
  the suite goes green. Never. A red test means the code is wrong (or the test is wrong for a
  reason you can state — then fix the test and say why).

## Rules of the loop
- **Red before green.** Write the failing test, run it, and confirm it fails *for the right
  reason* (the asserted behavior is missing — not a typo, import error, or setup failure).
- **Then only enough code to pass.** No anticipating future tests, no speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to review, once the suite is green.
