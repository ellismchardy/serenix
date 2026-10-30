---
name: ship
description: Take a finished branch to a squash-merged PR — sync with main, run all checks, review the whole branch on both axes, write the PR body (summary, evidence, merge danger), push and open the PR, then squash-merge when you say so. Run /ship on a feature/fix branch once its plan is done.
disable-model-invocation: true
---

# Ship

Get the current branch from "plan done" to "merged on `main`" safely. Pushing, opening a PR, and
merging are outward-facing: **confirm with the user before each**, unless they already said
to go ahead in this session.

## Steps
1. **Preflight.** Stop and report if any of these fail:
   - On a `feat/…`, `fix/…`, or `chore/…` branch — never `main`.
   - Working tree clean (`git status --short`); uncommitted work gets committed via `/execute`
     or explicitly by the user, not swept in here.
   - The branch's plan has no unchecked tasks (it should be in `plans/done/`), and — if the plan
     has a spec — the spec's `Status` is `built`. Bug and refactor plans have no spec; pure
     chores have neither — skip what doesn't exist.
   - `gh auth status` succeeds and `origin` exists. If not, tell the user to run
     `gh auth login` in their own terminal (it's interactive), or add the remote, and stop.
2. **Sync with main.** `git fetch origin`. If `origin/main` has moved past the merge-base,
   `git merge origin/main` into the branch (a merge, so no force-push is ever needed). On
   conflicts, stop and walk the user through them — never resolve a conflict by discarding
   either side's intent.
3. **Run every check** from CLAUDE.md's Key commands (install, lint, typecheck, full test
   suite). All must be green; fix root causes, never mask. Before `/scaffold` there is nothing
   to run (placeholder commands, no CI) — say so, and the branch merges on review alone.
4. **Review the whole branch.** Dispatch `spec-reviewer` and `standards-reviewer` **in
   parallel** with the diff command `git diff origin/main...HEAD`, the commit list
   (`git log origin/main..HEAD --oneline`), the spec path, and the archived plan path (in
   `plans/done/`) — for a spec change, the plan is what says which criteria this branch
   covers. Per-task reviews miss cross-task problems; this pass is for those. Show both
   reports under separate headings. Fix **Blocking** findings as small commits (re-run
   checks); if a fix is more than a few lines or changes design, stop and ask — it may need a
   plan task.
5. **Write the PR.** Title: imperative, under 70 chars (it becomes the squash commit on
   `main`). Body: fill in `.github/pull_request_template.md` —
   - **Summary** — the *smallest visual* that makes the change clear: a call tree, file tree,
     pseudocode, a `diff`-style sketch, or a Mermaid diagram. A sentence or two, not an essay.
   - **Evidence** — before/after: the test that failed and now passes, command output, or a
     screenshot for UI. Real output you ran, not claims.
   - **Merge danger** — *one-way or two-way door* (can it be cleanly rolled back? schema
     migrations, data deletion, public API changes, and sent emails are one-way) and the
     *blast radius* (who/what breaks if it's wrong).
   - Link the spec, the archived plan, any ADRs, and `Closes #<issue>` if there is one.
   Use `GLOSSARY.md` terms. Show the title and body to the user.
6. **Push and open** (after confirmation): `git push -u origin <branch>`. If the branch
   already has an open PR (`gh pr list --head <branch> --state open` — `gh pr view` also finds
   closed ones), update it: `gh pr edit <n> --base main
   --title "<title>" --body-file <tmp file>`. Otherwise `gh pr create --base main --title
   "<title>" --body-file <tmp file>`. Report the PR URL.
7. **Merge** — only when the user says to. First confirm `gh pr checks` is green (or, before
   `/scaffold`, that there are no checks) and required reviews are in. Then check for PRs
   stacked on this branch (`gh pr list --base <branch>`) and retarget each to `main` (`gh pr
   edit <n> --base main`): `--delete-branch` deletes their base, and GitHub then **closes**
   them for good instead of retargeting. Then `gh pr merge --squash --delete-branch`, `git
   checkout main`, `git pull --ff-only`. Report the squash commit on `main`, and tell the user
   any retargeted PR now needs `main` merged in (its next `/ship` step 2 does that).

## Rules
- Never force-push, never push directly to `main`, never `--no-verify`, never merge with red
  checks. If a rule blocks progress, stop and tell the user why.
- One PR per feature/fix. If the branch contains unrelated work, stop and say so.

## Then
After merging, point the user at the next spec (or `/write-spec`), and suggest `/retro` if the
build hit friction worth fixing in the environment.
