---
name: scaffold
description: Stand up the runnable project skeleton (dependencies, build/test/lint config, folder layout, CI + pre-commit guardrails, a hello-world that proves the toolchain). Run once with /scaffold after /kickoff and before the first feature spec.
disable-model-invocation: true
---

# Scaffold

Turn the stack that `kickoff` already settled into an actual runnable project — the empty
shell that spec-driven, test-first feature work needs to stand on. This runs **once**, after
kickoff and before the first `/write-spec`. It writes setup/config and a hello-world only:
**no features**.

## Steps
1. Read the decided stack and structure — do NOT re-ask what kickoff already settled:
   - `CLAUDE.md` (stack, key commands, layout)
   - `docs/architecture.md` (components and their locations, data model)
   - `docs/conventions.md` (naming, test framework, patterns)
2. Confirm only what's genuinely missing or ambiguous for setup (e.g. exact build tool, package
   manager) — one small batch, and only if you can't responsibly infer it. If the stack is
   clear, skip straight to scaffolding and state your tooling choices inline.
3. Stand up the skeleton for that stack:
   - Dependency manifest + lockfile (e.g. `package.json`, `pyproject.toml`) with the chosen
     framework, test runner, linter, and typechecker.
   - Build / dev / test / lint / typecheck config wired so the **key commands in CLAUDE.md
     actually run**.
   - The folder layout from `architecture.md` (e.g. `src/main`, `src/renderer`, `src/core`),
     with empty module stubs only where they clarify the structure — no behavior.
   - A minimal hello-world: the app starts (blank window / health route / CLI prints), and
     **exactly one trivial test that passes**.
   - `.gitignore` covering deps, build output, and secrets/`.env` (extend the existing one).
   - `.env.example` listing every config key the skeleton reads, with dummy values.
4. Wire the **guardrails**, so a mistake is caught by a machine before a reviewer:
   - **CI:** `.github/workflows/ci.yml` running install → lint → typecheck → test on every pull
     request and on pushes to `main`, using the exact key commands from CLAUDE.md.
   - **Pre-commit hook** using the stack's idiomatic tool (e.g. Husky + lint-staged for Node,
     `pre-commit` for Python): format + lint the staged files, then typecheck. Keep it fast;
     the full test suite belongs in CI.
5. Verify the toolchain end-to-end by actually running the commands:
   - install succeeds
   - `test` runs and the one trivial test is green
   - `lint` and `typecheck` pass clean
   - the pre-commit hook fires on a commit
   - the dev/run command launches (or note why it can't be auto-verified in this environment)
6. Report what you created and the exact result of each command you ran.

## Rules
- **No features and no spec.** This skill only produces setup, config, structure, and a
  hello-world. Anything app-specific belongs to a spec → plan → build, not here.
- Don't re-litigate stack decisions — they live in `docs/adr/`. If setup forces a NEW real
  choice (e.g. which Electron bundler) that passes the test in `docs/adr/README.md`, make it,
  then add an ADR.
- Scaffolding is setup, not a feature: do it on a `chore/scaffold` branch and open a PR like
  any other change (`/ship` handles that).
- Match `docs/conventions.md` exactly (file naming, test location, formatting).
- Never commit secrets; ensure `.env` and key stores are git-ignored from the start.
- Keep the skeleton minimal — the goal is "toolchain proven," not "lots of code."
- If a command genuinely can't run in this environment (e.g. a GUI launch), say so explicitly
  rather than claiming success.

## Then
Report the green toolchain (which commands pass). Point the user at `/ship` to open the
scaffold PR, then `/write-spec` on their first feature — ideally the riskiest piece, since
everything else builds on it.
