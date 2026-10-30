---
name: retro
description: Retrospective on a coding session — suggests improvements to the agent's environment (navigation, automated checks, review standards, steering files, tooling), most severe first. Run /retro at the end of a session, especially one that went sideways.
disable-model-invocation: true
---

# Retro

Look back at a session and suggest changes to the **environment** — not the code — so the next
session goes better. Default to the current session; if the user names another, read its log.

## Where things belong here
- `CLAUDE.md` — loaded every session, so use it sparingly: core rules and **navigation
  pointers** to other files. Anything else here costs context in every session.
- `docs/conventions.md` — the standards `standards-reviewer` enforces. Review is where
  standards get applied, because the reviewer has the least context pressure.
- `GLOSSARY.md` / `docs/adr/` — domain terms and the why behind hard-to-reverse choices.
- Skills and agents in `.claude/` — repeatable procedures and focused workers.
- Lint rules, the pre-commit hook, CI, and `.claude/hooks/` — **deterministic checks**.

## Look for
- **Navigation** — did it take long to find the right file or fact? A pointer in CLAUDE.md or
  a doc would fix it.
- **Automated checks** — did the agent make a mistake a lint rule, type, test, or hook could
  catch? Check first whether a check exists but isn't wired into the pre-commit hook or CI —
  that's the finding. A repo with no pre-commit hook or no CI is itself a finding.
- **Review standards** — did a reviewer miss something? Classify it: a **mechanical** pattern
  (banned API, import shape, file location) gets a deterministic check, not prose. Only
  genuine **judgement calls** go into `docs/conventions.md`.
- **Steering bloat** — instructions in CLAUDE.md that belong in conventions or a check, or that
  don't change behavior at all (no-ops). Smaller steering files get followed better.
- **Domain language** — terms that caused confusion and should be in `GLOSSARY.md`.
- **Tool economy** — expensive or repeated tool calls a script or command could replace.
- **Information access** — something the agent needed and couldn't see (logs, a dev server,
  read-only access to a service).
- **Process** — a step in the spec → plan → execute → ship loop that was skipped, unclear, or
  needed a workaround: name the skill and the change.

## Then
Present the candidates **most severe first**, each with: what happened (with evidence from the
session), the proposed change, and the exact file it goes in. Don't apply any of them until the
user picks — each one is a small `chore/` change of its own.
