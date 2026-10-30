# Serenix

> The project constitution. Loaded into context every session, so keep it **short** —
> shorter files get followed more reliably. Push detail into docs/ and reference it.

## What this is
An iOS wellness tracker that reads a Whoop 5.0 Strap directly over Bluetooth, so owners without
a WHOOP membership get sleep, Nightly Metrics, Sleep Score, Readiness and Load. Everything runs
on the phone. Public, MIT-licensed, not affiliated with WHOOP, Inc. Protocol research and the Python reference
implementation live in the separate `hr-tracker` repo.

## Stack
- Language / runtime: Swift 6 (toolchain 6.4.1, pinned in CI), iOS 17+
- Framework: SwiftUI, CoreBluetooth, HealthKit (write-only)
- Database: SwiftData, on device only (no backend)
- Test runner: Swift Testing
- **No Mac.** `SerenixCore` builds and tests on Windows/Linux. The iOS app builds only on
  GitHub Actions macOS and is sideloaded with Sideloadly (see ADR 0003).

## Key commands
- Install: see `docs/dev-setup.md` (Windows toolchain, pre-commit hook, sideloading)
- Run (dev): CI builds the app from `project.yml` (XcodeGen); sideload it per
  `docs/dev-setup.md`
- Test: `swift test`
- Lint: `swift format lint --strict --recursive src tests Package.swift`
- Typecheck: `swift build`

## Layout
- `src/` — application code: `src/SerenixCore` (pure logic) and `src/SerenixApp` (iOS shell)
- `tests/` — tests (mirror the src/ structure); fixture rules in `docs/conventions.md`
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
   Never weaken or delete a test to make it pass. (Exceptions: throwaway prototypes on
   never-merged `prototype/` branches, and the thin iOS shell, which can't run on Windows and
   is checked by hand on a phone per ADR 0002. Logic in `SerenixCore` is always test-first.)
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
   Only `/ship` pushes a branch, opens its PR and **squash-merges** it (one commit per feature
   on `main`), and the user runs it: when a branch is finished, say "**ready to ship:
   `<branch>`**" with a one-line summary, and stop. Merge before starting the next feature,
   then branch the next one from freshly-updated `main`.

## Hard nevers
- Never commit secrets or `.env` files.
- Never run destructive commands (drop db, force push, reset --hard) without explicit
  confirmation. `.claude/hooks/block-dangerous-git.sh` enforces the git ones — never work around it.
- Never skip hooks or CI (`--no-verify`, disabling checks) to get a change through.
