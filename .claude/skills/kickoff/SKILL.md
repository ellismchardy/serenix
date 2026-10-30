---
name: kickoff
description: Interview the user about a new app idea, then fill in CLAUDE.md, docs/, GLOSSARY.md and the first ADRs before any code is written. Run once on a fresh copy of this template with /kickoff <one-paragraph idea>.
disable-model-invocation: true
---

# Kickoff

Stand up a new project from this template by **interviewing the user**, then filling in the
project constitution (`CLAUDE.md`), reference docs (`docs/`), the domain language
(`GLOSSARY.md`), and the first decision records (`docs/adr/`). This runs once, before any spec,
plan, or code exists.

## Steps
1. Read the user's one-paragraph idea (it follows the command, or ask for it if missing).
2. Read the files you'll be filling in, so questions map to real blanks and you follow each
   file's structure exactly: `CLAUDE.md`, `docs/architecture.md`, `docs/conventions.md`,
   `GLOSSARY.md`, and `docs/adr/README.md`.
3. **Interview the user.** Call the Skill tool twice, for "grilling" and "domain-modeling".
   Grill in rounds covering: the product (what it does, who it's for), users and their core
   jobs, scope and non-goals, tech stack, hosting/deploy target, team (size, who reviews,
   which issue tracker), and constraints (compliance, budget, performance). Ask only what you
   can't responsibly infer, and give a recommended answer for every question.
4. **Write nothing but `GLOSSARY.md` until the interview is done.** Domain terms get captured
   inline as they're resolved (that's the domain-modeling discipline); everything else waits.
5. **Confirm your own additions.** When the frontier is empty, before writing, list every statement you plan to put in the
   files that the interview did not settle (error policy, logging, fallback behaviour,
   defaults you'd pick) and have the user confirm, change, or drop each. Anything unconfirmed
   becomes a placeholder.
6. Then fill in the files, keeping each to its template's structure:
   - `CLAUDE.md` — keep it **short** (it loads every session): what it is, stack, key commands,
     layout. Push detail into `docs/` and reference it.
   - `docs/architecture.md` — components, data model, external deps, cross-cutting concerns.
   - `docs/conventions.md` — naming, code patterns, testing, git rules.
   - `GLOSSARY.md` — the domain terms settled in the interview.
   - `docs/adr/` — one ADR per real choice the interview settled (stack, database, deploy
     target…) that passes the three-part test in `docs/adr/README.md`. Delete the worked
     example `0001-example-sqlite-for-v1.md` and number yours from `0001`.

## Rules
- Don't guess the stack, scope, or constraints — ask. If you must assume something to keep
  moving, state the assumption and put it to the user in the next round.
- Surface tensions you notice (e.g. a constraint that conflicts with the stated scope) rather
  than silently resolving them.
- Leave a placeholder (not an invention) for anything genuinely undecided, and list it as an
  open question in your summary.
- This skill fills in CLAUDE.md, docs/, and GLOSSARY.md only. No spec, no feature code.

## Then
Show the filled-in files for review. Once the user is happy, land the kickoff **before** any
other work, so nothing gets stacked on an unmerged branch:
1. Commit on a `chore/kickoff` branch (never on `main`).
2. If there's no GitHub remote yet, the user creates it and makes the first push of `main`
   themselves (`.claude/hooks/block-dangerous-git.sh` blocks Claude from pushing `main`).
   Say so when you first show the files, and give them the commands.
3. Say "**ready to ship: `chore/kickoff`**" with a one-line summary, and stop. The user runs
   `/ship`, which opens the PR and merges it.

In the same message, say what comes after the merge: `/scaffold`, branched from the updated
`main`, to stand up the runnable
skeleton for the chosen stack (before any feature work), then `/write-spec` on their first
feature. If the first milestone is still too big or foggy to spec in one go,
suggest `/wayfinder` to chart it first. If setup needs steps only a human can do (accounts,
API keys, CI secrets), the `wizard` skill can script them.
