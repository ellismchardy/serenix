# <PROJECT NAME>

> The project constitution. Loaded into context every session, so keep it **short** —
> shorter files get followed more reliably. Push detail into docs/ and reference it.

## What this is
<One or two sentences: what the app does and who it's for.>

## Stack
- Language / runtime: <e.g. TypeScript, Node 20 / Python 3.12>
- Framework: <e.g. Next.js / FastAPI>
- Database: <e.g. Postgres / SQLite>
- Test runner: <e.g. vitest / pytest>

## Key commands
- Install: `<e.g. npm install>`
- Run (dev): `<e.g. npm run dev>`
- Test: `<e.g. npm test>`
- Lint: `<e.g. npm run lint>`
- Typecheck: `<e.g. npm run typecheck>`

## Layout
- `src/` — application code
- `tests/` — tests (mirror the src/ structure)
- `specs/` — feature specs (the source of truth)
- `plans/` — disposable execution plans
- `docs/` — deeper reference (see below); `docs/adr/` — one file per decision (the *why*)

## Deeper reference
@GLOSSARY.md
@docs/architecture.md
@docs/conventions.md

Before changing an area, read the ADRs in `docs/adr/` that touch it — don't "fix" a deliberate
choice. Use GLOSSARY.md terms in code, tests, specs, and conversation.

## Workflow
Feature: `/write-spec` → `/plan` → `/execute` (one task per run) or `/execute-parallel` → `/ship`.
Bug: `/diagnose` → `/plan` → `/execute` → `/ship`. Incoming issues: `/triage`. Too big to spec:
`/wayfinder`. Upkeep: `/improve-architecture`, `/retro`. Session: `/handoff`.
Not sure which flow fits? See `docs/workflows.md`.

## Core working rules
1. **Spec-driven.** Don't write code for a feature until a spec exists in `specs/`. Don't
   start coding until there's an approved plan.
2. **TDD.** Write a failing test first, confirm it fails, then implement until green.
   Never weaken or delete a test to make it pass. (Only exception: throwaway prototypes on
   never-merged `prototype/` branches.)
3. **Fix root causes, not symptoms.** When something fails, diagnose and fix the underlying
   cause. Never mask a bug to make the suite look green — no swallowing errors, special-casing
   inputs, hardcoding expected results, or loosening assertions. Green must mean correct.
4. **One task at a time.** Work the plan in order. Commit after each green task. The only
   exception: tasks the plan explicitly marks independent (`Blocked by:`) may run in parallel
   via `/execute-parallel` — still one task per agent, each reviewed and committed on its own.
5. **Spec is durable, plan is disposable.** Update the spec only when the *desired behavior*
   changes (improvements/new requirements). Bugs do NOT change the spec — fix via a plan.
6. **Ask before scope creep.** If a change starts touching files outside the plan, stop and
   confirm rather than "improving" things that weren't requested.
7. **Checkable success criteria.** Every spec requirement must be testable
   ("test passes", "returns 200"), never vague ("clean code").
8. **Branch per feature; merge before the next.** Start every feature/fix on its own branch
   off `main` (`feat/<name>` / `fix/<name>`, or `chore/<name>` for setup/tooling/docs with no
   spec) — never commit feature work to `main` or stack new work on another feature's branch.
   Open the PR when you first push the branch (`/ship`), **squash-merge** it (one commit per
   feature on `main`), and merge before starting the next feature, then branch the next one
   from freshly-updated `main`.

## Hard nevers
- Never commit secrets or `.env` files.
- Never run destructive commands (drop db, force push, reset --hard) without explicit
  confirmation. `.claude/hooks/block-dangerous-git.sh` enforces the git ones — never work around it.
- Never skip hooks or CI (`--no-verify`, disabling checks) to get a change through.
