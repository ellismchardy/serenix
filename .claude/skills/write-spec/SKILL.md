---
name: write-spec
description: Turn a feature idea (or an issue) into a structured spec with agreed test seams and checkable success criteria. Use when the user wants to start a new feature or change desired behavior, says "write a spec", or runs /write-spec <feature>.
---

# Write Spec

Produce a feature spec from the feature the user named (the description or issue link follows
the command; ask for it if missing).

**New spec or change?** Before anything else, check `specs/` for a spec that already covers
this behavior. If one does, this is a **change**: edit that spec in place (see "Changing an
existing spec" below) — never write a second spec that contradicts it. If the overlap is
partial or unclear (a new feature next to an existing one), ask the user which it is rather
than guessing. Bugs are not changes; if the spec already describes the right behavior, point
the user to `/diagnose` instead.

## Steps
1. **Gather context.** Read `specs/_TEMPLATE.md`, `GLOSSARY.md`, related specs (so this one is
   consistent and doesn't overlap), and ADRs in `docs/adr/` for the area. If an issue link was
   given, read it with `gh issue view`. Explore the code the feature will touch (the
   `investigator` agent keeps that out of the main context).
2. **Grill until it's clear.** Unless the conversation has already settled the feature, call the
   Skill tool twice, for "grilling" and "domain-modeling", and interview the user in rounds —
   behavior, edge cases and unhappy paths, non-goals, and which modules/interfaces change.
   New or sharpened domain terms go into `GLOSSARY.md` as they're resolved.
   If a question can't be settled in conversation, don't guess: call the Skill tool with
   "research" for external facts, or "prototype" for "does this logic feel right / what should
   this look like", and fold the answer back in. If the feature turns out too big and foggy
   for one spec, suggest `/wayfinder` instead.
3. **Agree the seams.** (Call the Skill tool with "codebase-design" if the module shape or seam
   placement is itself in question.) Propose the seams the tests will exercise — prefer
   existing ones, the highest that still gives a fast, deterministic signal, and as few as
   possible (one is ideal).
   Give each a line on what it catches and misses, and confirm them with the user.
4. **Draft the spec** following the template exactly, using glossary terms throughout:
   - **Success criteria** — every item MUST be checkable (a test, a status code, an observable
     outcome). Reject vague criteria like "clean code" or "works well".
   - **Design decisions** — modules and interfaces, not file paths or code.
   - **Non-goals** — be explicit, to stop scope creep.
   - **Open questions** — surface them instead of guessing; state any assumption inline.
5. If a decision passes the three-part test in `docs/adr/README.md`, offer to write an ADR.
6. Save as `specs/<NNN>-<kebab-name>.md`, using the next free number.

## Changing an existing spec
Follow steps 1–5 above (skip step 6 — the spec keeps its file and number) with these
differences:
- **Check it isn't in flight.** Work on this spec may be unmerged: a plan for it in `plans/`
  (not `plans/done/`), a branch that touches it (`git log --all --oneline main.. --
  specs/<file>`), or an open PR (`gh pr list --search <spec name>`). If so, stop and ask:
  usually finish and `/ship` it first, then change the spec — editing it mid-flight leaves
  that work out of date. (A spec with no plan yet is just a draft: edit it normally.)
- **Scope the grilling to the delta.** Read the whole spec, then interview only on what's
  changing and what it touches (edge cases, success criteria, non-goals that no longer hold).
- **Keep the seams** unless the change needs a new one; confirm any addition with the user.
- **Edit in place.** Rewrite the affected sections so the spec reads as the new desired state,
  not a changelog. Replace or remove success criteria that no longer hold — don't leave both.
- **Uncheck what changed.** New and changed success criteria are `[ ]`; criteria the change
  doesn't touch keep their `[x]`. The unchecked boxes are how `/plan` (often in a fresh
  session) knows what to build, so get them right. Removing behavior needs a box too — state
  the new behavior as a checkable criterion (e.g. "sending a void invoice sends no email")
  rather than just deleting the old line, or `/plan` will find nothing to do.
- **Mark it unapproved.** Set `Status` to `draft` and update **Last updated**, even if it was
  `built`: the code no longer matches the spec until the change ships.
- **Show the diff** (`git diff specs/<file>`) when presenting it, and list which success
  criteria are new or changed.

## Then
Present the spec for review. Do NOT start planning or coding — wait for approval. Once the
user approves, set the spec's `Status` to `approved` (and update **Last updated**); then the
user can run `/plan` on this spec.
