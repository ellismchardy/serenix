---
name: plan
description: Break an approved spec (or a diagnosed bug) into a small, ordered list of vertical-slice tasks, each green and committable on its own. Use after a spec is approved or a bug is diagnosed, or run /plan <spec file or bug>.
---

# Plan

Turn an approved spec — or a diagnosed bug — into a disposable execution plan.

## Steps
1. Read the target spec in `specs/` (check its `Status` is `approved`), or for a bug the root
   cause report from `/diagnose`. Read `plans/_TEMPLATE.md` and follow its structure.
   **Spec changes:** if some success criteria are already ticked `[x]`, or a plan for this
   spec is already in `plans/done/`, the spec was built before and has since changed
   (`/write-spec` unticks what changed). Plan only the unticked criteria — the ticked ones
   already exist. The spec edit is uncommitted until `/execute`, so `git diff specs/<file>`
   shows exactly what changed. Where a criterion changed or was removed, the existing tests
   for the old behavior are now wrong: the task for that criterion rewrites or removes them as
   part of its red→green cycle, and lists them under **Files**. That's following the spec, not
   weakening a test to get green.
2. Explore the code the work touches if you haven't (use the `investigator` agent). Look for a
   **prefactor**: "make the change easy, then make the easy change". If reshaping existing code
   (with no behavior change) would make the feature simple, that's task 1.
3. Break the work into **vertical slices** (tracer bullets):
   - Each behavior task cuts a narrow but *complete* path through every layer it needs (schema,
     logic, API, UI) — never "all the models", then "all the routes".
   - Each is one red→green cycle at one of the spec's **Seams under test**: `/execute` writes its
     failing test, makes it pass, and commits. Don't split "write test" and "implement" into
     separate tasks — a task must be green when it's committed.
   - Each is small enough to finish in one fresh context window, and verifiable on its own.
   - Order so the first slice is the thinnest end-to-end path; later slices build on it.
4. **Bugs:** the first behavior task turns the minimised repro into a failing regression test
   and makes it pass with the root-cause fix. Then any cleanup task (remove `[DEBUG-…]`
   instrumentation, throwaway harnesses).
5. **Wide refactors** (one mechanical change that breaks many call sites at once, e.g. renaming
   a column or retyping a shared symbol) can't be a single green slice. Sequence them
   **expand → migrate → contract**: add the new form beside the old, migrate call sites in
   batches (one task each, suite green throughout), then delete the old form.
6. For each task note the **seam**, the **files** it's expected to touch (so review can catch
   scope creep), and a **Done when** tied to a spec success criterion.
7. **Blocking edges.** Tasks run in order by default. Where a task genuinely depends only on
   specific earlier tasks (not the one right before it), give it an explicit `Blocked by:`
   line so `/execute-parallel` can run independent slices concurrently. Only declare
   independence you're sure of: two tasks that touch the same files are not independent.
   A task's blockers must always have **lower numbers** than the task itself, so working the
   list top to bottom (`/execute`) is always a valid order.
8. End with a verify task (full suite + lint + typecheck; every success criterion checked).
   Its `Blocked by:` lists every task nothing else depends on — the ends of the graph — which
   makes it wait for everything.
9. Save as `plans/<NNN>-<kebab-name>.md` (features), `plans/fix-<kebab-name>.md` (bugs), or
   `plans/refactor-<kebab-name>.md` (behavior-preserving refactors from
   `/improve-architecture`), and fill in the **Branch:** field (`feat/`, `fix/`, or `chore/`).
   That name is the source of truth `/execute` uses to create and switch to the branch — set
   it deliberately. A spec change is **Type:** `improvement` (that Type means a change to a
   built spec, nothing else), on a `feat/` branch like a feature. Keep the spec's number but
   name it after the change, not the original feature — `plans/004-resend-invoice.md` on
   `feat/resend-invoice` for `specs/004-send-invoice.md` — so it never collides with the
   original plan in `plans/done/`.

## Rules
- Do NOT edit the spec here. Planning never changes desired behavior.
- If the work turns out to reshape the feature's core design, stop and treat it as a spec
  change (`/write-spec`), not a plan.
- Every task must name the spec seam it tests at. If it needs a seam the spec doesn't list,
  raise it with the user before saving the plan.

## Then
Present the plan for review before any implementation. The feature branch is **not** created
here — planning stays on your current branch (usually `main`), and `/execute` creates the
branch from the plan's `**Branch:**` field on its first run. Ask the user if they would like to
run `/execute <plan file>` to start working through the tasks (or `/execute-parallel` if the
plan declares independent tasks).
