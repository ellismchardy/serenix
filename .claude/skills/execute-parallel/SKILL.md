---
name: execute-parallel
description: Work an approved plan's independent tasks concurrently — implementer agents in separate git worktrees take every task whose blockers are done, and each result is merged, checked, two-axis reviewed, and ticked on the feature branch. Run /execute-parallel [plan] when a plan has tasks with explicit "Blocked by" edges that allow parallel work; /execute stays the default.
disable-model-invocation: true
---

# Execute (parallel)

`/execute` does one task per run, by hand. This skill is for a plan whose tasks form a **task
graph** rather than a straight line: it runs every task on the **frontier** (unchecked tasks
whose blockers are all checked) at once, in isolated worktrees, and merges them onto the plan's
feature branch one at a time. Each task still gets the full treatment — red → green, checks,
both review axes, its own commit — so CLAUDE.md's "one task at a time" holds **per agent**.

## Preconditions
- The plan is approved and at least two unchecked tasks are unblocked at the same time. Task
  dependencies come from each task's `Blocked by:` line; a task with **no** `Blocked by:` line
  is treated as blocked by the task before it (plans are sequential unless they say otherwise).
  If the frontier is a single task, say so and recommend `/execute`.
- The working tree is clean, apart from the new or edited spec/plan (and notes) that step 1
  commits on the first run.

## Steps
1. **Select the plan and get on its branch** exactly as `/execute` steps 1–2 do (create the
   branch from `main` on first run; commit the spec + plan as its first commit).
2. **Compute the frontier.** List it to the user with each task's files. If two frontier tasks
   list overlapping files, run them in sequence instead — they'll conflict.
3. **Dispatch implementers** — up to 3 at once, each a `general-purpose` agent with
   `isolation: "worktree"`, run in the background. Keep the brief short and point at files
   rather than pasting them:
   - Plan path + the one task number, the spec path, and the feature branch's current tip SHA.
   - "First run `git checkout -B <feature branch>--task-<N> <tip SHA>` so your work starts from
     the feature branch tip on its own branch."
   - "Read `.claude/skills/tdd/` and `docs/conventions.md`. Write the failing test at the task's
     seam, run it and confirm it fails for the right reason, and **commit the test alone**.
     Then implement only enough to make it green, run the Key commands from CLAUDE.md, and
     commit the implementation. Never weaken a test."
   - "Touch only the files the task lists; if you need others, stop and report why. Do NOT edit
     the plan or spec. Report your worktree path, branch name, the test-only commit SHA, the
     final commit SHA, the test's name, and its red-then-green output."
4. **As each implementer reports, integrate it** (one at a time, in the main session, so each
   task gets the same guarantees as `/execute`):
   - **Verify red yourself** — don't trust the report. In the implementer's worktree, check out
     the test-only commit (`git -C <worktree> checkout <test SHA>`), run that test, confirm it
     fails for the right reason, then `git -C <worktree> checkout <task branch>` and confirm it
     passes. A test that was never red goes back to a fresh implementer.
   - **Review before merging.** Dispatch `spec-reviewer` and `standards-reviewer` in parallel
     with the diff command `git diff HEAD...<task branch>`, the spec, the plan path, and the
     task. Fix **Blocking** findings on the task branch (in its worktree) before going on.
   - **Merge without committing:** `git merge --no-ff --no-commit <task branch>`. On a conflict,
     stop and walk the user through it — never resolve it by dropping either side.
   - Run all checks on the merged result. Red → fix the root cause before going on.
   - Tick the task's box in the plan, stage it, and commit the merge and the tick together
     (`Merge task <N>: <task title>`).
5. **Recompute the frontier** after each integration and dispatch implementers for newly
   unblocked tasks.
6. **Clean up** each merged task: `git worktree remove <worktree path>` and
   `git branch -d <task branch>`.
   Leave any unmerged worktree in place and tell the user.
7. When every box is ticked, finish as `/execute` does (spec `Status: built`, plan to
   `plans/done/`, commit) and point the user at `/ship`.

## Rules
- Same rules as `/execute`: no spec edits, no scope expansion, never mask a failure, stop and
  surface anything the plan didn't anticipate.
- Only the main session merges, ticks boxes, or touches the plan.
- Report progress as each task lands: which merged, check/review results, what's running now.
