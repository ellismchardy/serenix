---
name: execute
description: Execute exactly ONE unchecked task from an approved plan — test-first, reviewed, committed — then stop. Use after a plan is approved, to work the plan one task at a time. Invoke manually with /execute (optionally name the plan).
---

# Execute

Do **one** task from a plan, well, then stop. The plan's checkboxes are the memory between
runs: each invocation picks up the next unchecked box, so context stays lean and you stay in
control. This is the opposite of "approve the plan and watch it run the whole list."

## Steps
1. **Select the plan.** If a plan was named (`/execute <plan>`), use it. Otherwise scan
   `plans/` (ignore `plans/done/`) and pick the active one: the plan whose `**Branch:**` line
   matches your current branch, or — if none matches and exactly one in-flight plan exists —
   that one. If it's still ambiguous, ask which. Read the plan and its linked spec in `specs/`.
2. **Get on the plan's branch — create it if it doesn't exist.** Read the plan's `**Branch:**`
   field and reconcile (idempotent across runs — this is what guarantees feature work never
   lands on `main`, instead of relying on remembering to branch by hand):
   - Already on that branch → continue.
   - Branch exists but you're elsewhere → switch to it.
   - Branch doesn't exist (first `/execute`) → create it off `main`: from up-to-date `main`
     (pull first if you track a remote), `git checkout -b <branch>`. New or edited
     spec/plan files (a spec change edits a tracked spec), and any `docs/research/` notes,
     `GLOSSARY.md` or ADR updates made while specifying, follow you across, so nothing is
     lost. Then commit them as the branch's first commit so it has a clean base.
   - If the working tree has changes beyond those, **stop and ask** before
     switching — never risk clobbering uncommitted work.
   Never execute feature work on `main` or stack it on another feature's branch.
3. Find the **first unchecked `[ ]` task**. If there are none, skip to **Finishing the plan**.
4. State which single task you're about to do, its seam, and the files it should touch (from
   the plan).
5. Execute that one task, test-first. Call the Skill tool with "tdd" for the rules of the loop.
   - **Behavior task:** dispatch the `test-writer` agent with the task, its seam, and the spec
     path; it writes the failing test and confirms it's red for the right reason. Then
     implement in the main thread — only enough to make it green. Never weaken a test to pass it.
   - **Prefactor task:** no new test; the existing suite must stay green before and after.
   - **Docs / config / dependency task:** just do it (no test).
6. Run the checks from CLAUDE.md's **Key commands** (test, lint, typecheck). All green, or fix
   the root cause — never mask a failure.
7. **Review.** Stage the task's changes (`git add` the files, so new untracked files show up in
   the diff), then dispatch the `spec-reviewer` and `standards-reviewer` agents **in parallel**,
   giving each the diff command `git diff --staged`, the spec path, the plan path, and the
   plan task. Report their findings under separate headings. Fix anything **Blocking** (re-run
   checks), and mention **Should fix** items to the user rather than silently expanding scope.
8. **Tick that task's box** in the plan file, stage it, then commit the task and the tick
   together (imperative mood, per `docs/conventions.md`).
9. **Stop.** Report: what you did, the check/review results, and the next unchecked task — but
   do NOT start it. The next `/execute` handles it.

## Rules
- **Exactly one task per invocation.** Never roll on to the next task without a fresh `/execute`.
  This is the whole point of the skill.
- Delegate test-writing and review to the agents — keeping their transcripts out of the main
  thread is what keeps context clean across a long plan.
- Don't edit the spec; planning/desired-behavior changes don't belong here (see CLAUDE.md).
- If a task can't be done as written — it reveals a design problem or needs files outside the
  plan — **stop and surface it** rather than improvising or expanding scope.

## Finishing the plan
When the last box is ticked:
- If the plan has a spec, update its `Status` to `built` and check off the success criteria
  now met. (Bug and refactor plans have no spec — skip this.)
- Move the plan to `plans/done/` (it's disposable; the spec is the durable record), and commit.
- Report the plan complete and point the user at `/ship` to review the whole branch and open
  the PR. Don't push or open it from here.

## Then
Want it to run unattended through the whole plan? Chain it: `/loop /execute` runs one task per
iteration until the plan is done. Default is one-at-a-time, by hand. Between tasks, `/clear` is
safe: the plan's checkboxes and the commits carry everything the next task needs.
