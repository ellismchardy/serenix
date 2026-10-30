# Spec-Driven Dev Template

A boilerplate for building apps with Claude Code using an agile, **spec-driven** workflow:
ship one feature at a time, break each into small reviewable vertical slices, keep a single
durable source of truth, and let machines (hooks, CI) enforce the rules that matter most.

## The one idea that makes this work

Specs and plans have **opposite lifespans**:

- **`specs/` are durable.** They describe what each feature *should be*. Kept accurate forever.
- **`plans/` are disposable.** They're the steps to get from "now" to what the spec says. Archived once executed.

Two more durable records sit beside the specs:

- **`GLOSSARY.md`** — the project's shared language. One precise word per concept, used in
  code, tests, specs, and conversation, so nobody (human or agent) needs a paragraph to say it.
- **`docs/adr/`** — the *why*: one short file per hard-to-reverse decision, so nobody "fixes"
  a deliberate choice six months later.

## Structure

```
.
├── CLAUDE.md               # project "constitution" — loaded every session, kept lean
├── GLOSSARY.md             # shared domain language (loaded every session)
├── docs/
│   ├── architecture.md     # system design, deep reference
│   ├── conventions.md      # naming, patterns, testing, review standards
│   └── adr/                # one file per decision — the "why"
├── specs/                  # one spec per feature — THE TRUTH (kept current forever)
│   └── _TEMPLATE.md
├── plans/                  # one plan per iteration — scaffolding
│   ├── _TEMPLATE.md
│   └── done/               # archived finished plans
├── .claude/
│   ├── settings.json       # wires the git guardrail hook
│   ├── hooks/              # block-dangerous-git.sh
│   ├── agents/             # focused workers with their own context windows
│   │   ├── investigator.md       # read-only code tracing
│   │   ├── test-writer.md        # writes the failing test for one slice
│   │   ├── spec-reviewer.md      # review axis 1: does it do what the spec asked?
│   │   └── standards-reviewer.md # review axis 2: is it well-made by our standards?
│   └── skills/             # see "Skills" below
├── .github/                # PR template, bug/feature issue forms (+ CI from /scaffold)
├── src/
└── tests/
```

## First-time setup

1. Use this repo as a GitHub **template** (or clone it) for your new project.
2. `/kickoff <one-paragraph idea>` → Claude grills you in rounds (each question comes with a
   recommended answer), then fills in `CLAUDE.md`, `docs/`, `GLOSSARY.md`, and the first ADRs.
3. `/scaffold` → Claude stands up the runnable skeleton for the chosen stack (deps,
   build/test/lint config, CI workflow, pre-commit hook, a hello-world that proves the
   toolchain) and verifies every command passes. No features yet.
4. `/ship` the scaffold as your first PR, then `/write-spec` your first feature — ideally the
   riskiest piece.

## The loops

> For a worked, end-to-end example of every loop (one team building one app), see
> [docs/workflows.md](docs/workflows.md).

### New feature
1. `/write-spec <feature or issue link>` → grilling, agreed test seams, checkable success
   criteria → approve.
2. `/plan <spec file>` → ordered **vertical slices**, each green and committable on its own.
3. `/execute` → does **one** task: failing test (`test-writer`) → make it green → both
   reviewers in parallel → commit. Repeat (or `/loop /execute`). If the plan marks tasks
   independent (`Blocked by:`), `/execute-parallel` runs them concurrently in git worktrees and
   merges, checks, reviews, and commits each one.
4. `/ship` → sync with main, full checks, whole-branch review, PR with evidence and a
   merge-danger call → squash-merge when you say so.

### Bug fix (spec is already right — don't touch it)
1. `/diagnose <bug>` → builds a feedback loop that goes red on *this* bug, minimises it, tests
   ranked hypotheses, and proves the root cause.
2. `/plan` → first task turns the minimised repro into a failing regression test, then fixes it.
3. `/execute` → `/ship`.

### Improvement / changed requirement (you want *different* behavior)
1. Update the **spec** first to the new desired state.
2. Then write a fresh plan and implement as above.

> Rule of thumb: **the spec changes only when what you *want* changes.** Bugs don't change
> what you want, so they live in a plan, never the spec.

### Incoming issues (bug reports, feature requests)
1. `/triage` → "what needs attention?" → for each issue: check it isn't already built or
   previously rejected (`.out-of-scope/`), reproduce bugs, grill fuzzy requests, and label it.
2. `ready-for-agent` issues get an agent brief, then go to `/write-spec #<n>` (enhancement) or
   `/diagnose #<n>` (bug). Rejected requests are recorded in `.out-of-scope/` so they aren't
   re-litigated.

### Too big or foggy to spec (a new product area, a major migration)
1. `/wayfinder <idea>` → names the destination and charts a **map** issue on GitHub with
   **decision tickets** (grilling, research, prototype, task) and blocking edges.
2. `/wayfinder #<map>` → resolves the next unblocked decision, one per session, until no fog is left.
3. Then `/write-spec` each spec the destination names.

### Codebase upkeep
- `/improve-architecture [area]` → surveys recent hot spots for shallow modules and leaky seams,
  shows a visual HTML report, and grills through the one you pick. The result becomes a
  `chore/` refactor plan (or a spec, if behavior changes).

### Between and after sessions
- `/handoff` → compacts the session into a doc in your temp dir for a fresh session or a teammate.
- `/retro` → after a session (especially a bumpy one), suggests environment fixes: missing
  lint rules or checks, review standards, navigation pointers, steering-file bloat.

## Skills

**You run these** (they never fire on their own):

| Skill | What it does |
|---|---|
| `/kickoff` | Interview → fill in CLAUDE.md, docs/, GLOSSARY.md, first ADRs |
| `/scaffold` | Runnable skeleton + CI + pre-commit for the chosen stack |
| `/execute-parallel` | Run a plan's independent tasks concurrently in worktrees |
| `/ship` | Sync, check, whole-branch review, PR, squash-merge |
| `/triage` | Move GitHub issues through labels; write agent briefs |
| `/wayfinder` | Chart and resolve a map of decisions for a huge, foggy effort |
| `/improve-architecture` | Survey for deepening opportunities; visual report; grill one |
| `/handoff` | Compact the session into a doc for a fresh session or a teammate |
| `/retro` | Suggest environment fixes after a session |

**You or Claude can run these**: `/write-spec`, `/plan`, `/execute`, `/diagnose`.

**Skills Claude pulls in when relevant** (you can ask for them directly too):

| Skill | Use it for |
|---|---|
| `tdd` | What a good test is, seams, anti-patterns, red→green rules |
| `grilling` | Round-based interviews with a recommended answer per question |
| `domain-modeling` | Keeping `GLOSSARY.md` and ADRs sharp |
| `codebase-design` | Deep-module vocabulary: module, interface, depth, seam, adapter |
| `prototype` | Throwaway HTML logic demo or UI variants to settle a design question |
| `research` | Background agent → cited note in `docs/research/` from primary sources |
| `wizard` | Interactive script for steps only a human can do (accounts, keys, CI secrets) |

## Guardrails

Rules that matter are enforced by machines, not memory:

- **Git hook** (`.claude/hooks/block-dangerous-git.sh`) — Claude can't force-push, push to
  `main`, `reset --hard`, `clean -f`, `branch -D`, `checkout .`/`restore .`, or `--no-verify`.
  You can still run anything yourself with the `!` prefix.
- **Pre-commit + CI** (added by `/scaffold`) — lint, typecheck, and tests on every commit / PR.
- **Two-axis review** — every task and every PR is reviewed separately for spec fidelity and
  for standards, so passing one can't mask failing the other.

Recommended GitHub settings for a team: protect `main` (require a PR, require the CI check to
pass, require one approving review), allow squash merging only, and auto-delete head branches.

## What's intentionally NOT here

No PM / UX / architect / scrum-master agents. Specs, plans, and decisions live in the repo;
GitHub Issues is the intake (`/triage`) and the place huge efforts get mapped (`/wayfinder`),
never a second source of truth. Add more only when you hit a wall the current loops can't handle.

## Credits

Several skills, the review agents, and the guardrail hook are adapted from
[mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
