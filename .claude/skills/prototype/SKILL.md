---
name: prototype
description: Build a throwaway prototype to answer one design question that's hard to settle on paper — a single shareable HTML file for "does this state model / logic feel right?", or several radically different UI variants on one route for "what should this look like?". Use when a spec or grilling session stalls on a question that needs something runnable to react to.
---

# Prototype

A prototype is **throwaway code that answers one question**. The question decides the shape.
It feeds a spec — it never replaces one, and it never merges to `main` as-is.

## Pick a branch
- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md): one self-contained
  HTML file with free-play buttons and guided scenario walkthroughs, driveable by a
  non-developer.
- **"What should this look like?"** → [UI.md](UI.md): several structurally different variants
  on one route, switched by a `?variant=` param and a floating bottom bar.

If it's genuinely ambiguous and the user isn't around, pick whichever matches the surrounding
code (backend module → logic; page or component → UI) and state the assumption at the top.

## Rules for both
1. **On its own branch.** Work on `prototype/<name>`, branched from `main`. It is never merged:
   it's kept as a primary source, not shipped. If you're mid-`/write-spec`, the uncommitted spec
   draft (new or edited) follows you onto this branch — don't commit it there; commit only
   prototype files.
2. **Clearly throwaway.** Put it next to the code it's prototyping for, with "prototype" in the
   file or route name. Obey the project's existing routing/layout conventions.
3. **Trivial to run.** One command (`npm run <name>`, `python <path>`), or a file you
   double-click. Say exactly how.
4. **No persistence** unless persistence is the question; then use a scratch DB/file named
   "PROTOTYPE — wipe me".
5. **Skip the polish.** No tests, no error handling beyond "it runs", no abstractions. This is
   the one place the TDD rule doesn't apply — prototype code never reaches `main`.
6. **Surface the state.** After every action (logic) or variant switch (UI), show the full
   relevant state.

## Capture it when done
- **The answer** goes into the spec being written (Design decisions / Notes), with a pointer to
  the `prototype/<name>` branch. A decision that's hard to reverse also gets an ADR.
- **The prototype** gets committed and pushed on `prototype/<name>` (push only with the user's
  OK) so it stays re-runnable. Don't open a PR for it.
- **Code worth keeping** (e.g. a validated reducer or state machine) is rebuilt properly,
  test-first, through the normal spec → plan → execute loop. A short snippet that encodes the
  decision more precisely than prose may be quoted in the spec, noted as from the prototype.
