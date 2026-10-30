---
name: diagnose
description: Disciplined diagnosis for bugs and performance regressions — build a feedback loop that goes red on this exact bug, minimise it, test ranked hypotheses, and prove the root cause before any fix is planned. Use when the user reports something broken, throwing, failing, flaky, or slow, says "debug"/"diagnose", or runs /diagnose <bug>.
---

# Diagnose

Find and **prove** the root cause of a bug, then hand a fix to `/plan`. This skill does not
ship the fix — bugs are fixed through a plan whose first task is the regression test (see
CLAUDE.md). The spec doesn't change: a bug means the code is wrong, not the spec.

Read `GLOSSARY.md` and the relevant spec in `specs/` so you know the *intended* behavior, and
check ADRs in `docs/adr/` for the area. Use the `investigator` agent for read-only code tracing.

**Redact secrets** in every command, output, and artifact you show: write `<REDACTED>`. Build
loops against env vars so credentials stay in the environment.

## Phase 1 — Build a feedback loop (this is the skill)
With a tight pass/fail signal that goes red on *this* bug, you will find the cause. Without
one, staring at code won't save you. Spend disproportionate effort here. Options, roughly in
order: a failing test at the seam that reaches the bug · a curl/HTTP script against the dev
server · a CLI run with a fixture input diffed against known-good output · a headless browser
script · replaying a captured request/payload/log · a throwaway harness around one code path ·
a property/fuzz loop for "sometimes wrong" · a `git bisect run` script between a good and bad
commit · a differential run (old vs new version, two configs).

Then **tighten** it: faster (narrow scope, skip unrelated setup), sharper (assert the exact
symptom, not "didn't crash"), deterministic (pin time, seed randomness, isolate fs/network).
For flaky bugs, the goal is a higher reproduction rate — loop it, parallelise, add stress.

**Exit criterion:** you can name **one command**, already run (show it and its output), that
drives the real code path, asserts the user's exact symptom, gives the same verdict every run,
and finishes in seconds. If you catch yourself theorising before this exists, stop.

If you truly can't build a loop, say so, list what you tried, and ask the user for access to a
reproducing environment, a redacted captured artifact (logs, HAR, recording), or permission to
add temporary instrumentation. Don't hypothesise without a loop.

## Phase 2 — Reproduce, then minimise
Confirm the loop shows the failure the **user** described (not a nearby different one), and
that it reproduces reliably. Then cut inputs, config, data, and steps **one at a time**,
re-running after each cut, until every remaining element is load-bearing. The minimal repro
becomes the regression test.

## Phase 3 — Hypothesise
Write **3–5 ranked, falsifiable hypotheses** before testing any: "If X is the cause, then
changing Y makes it disappear / changing Z makes it worse." Show the list to the user — they
often know something that re-ranks it instantly. Don't block if they're away.

## Phase 4 — Instrument
Each probe tests one prediction; change one variable at a time. Prefer a debugger/REPL, then
targeted logs at the boundaries that separate hypotheses — never "log everything and grep".
Tag every debug line with a unique prefix (e.g. `[DEBUG-a4f2]`) so cleanup is one grep.
Performance: measure a baseline first (timer, profiler, query plan), then bisect.

## Phase 5 — Confirm the root cause
The cause is confirmed when a change targeting it flips the loop from red to green **and** you
can explain why from the code. Then revert that experimental change and remove all
`[DEBUG-…]` lines (grep the prefix) — the real fix goes through the plan.

Check the seam: can the minimised repro become a test at a seam where the *real* bug pattern
occurs? If the only available seam is too shallow to reproduce it, say so — that's an
architecture finding: suggest `/improve-architecture` on that area after the fix.

## Then
Report: the symptom, the loop command, the minimised repro, the hypotheses and which one held
(with `file:line`), the seam for the regression test, and the blast radius of a fix. Ask if the
user would like to run `/plan` on it — the plan's first task turns the repro into a failing
regression test and fixes it on a `fix/<name>` branch.
