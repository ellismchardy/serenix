# Architecture Decision Records

The **why**. Specs say what the system does now; plans say how we built it (then get deleted).
Neither preserves *why we chose X over Y* — ADRs do.

One decision per file, so parallel branches never conflict: `NNNN-kebab-title.md`, numbered by
taking the highest existing number + 1. ADRs are never rewritten — to change a decision, write a
new ADR and set the old one's status to `superseded by NNNN`.

## When to write one
Only when **all three** are true:
1. **Hard to reverse** — changing your mind later has a meaningful cost.
2. **Surprising without context** — a future reader would ask "why on earth did they do this?"
3. **A real trade-off** — there were genuine alternatives and you picked one for specific reasons.

If any is missing, skip it. Typical qualifiers: architectural shape, tech choices with lock-in
(database, auth provider, deploy target — not every library), boundary/ownership decisions,
deliberate deviations from the obvious path, constraints invisible in the code ("must respond
in <200ms per the partner contract"), and non-obvious rejected alternatives.

## Format
```md
# NNNN — <Short title>

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | deprecated | superseded by NNNN

<1–3 sentences: the context, what we decided, and why.>
```
That's usually enough. Add **Considered options** or **Consequences** sections only when the
rejected alternatives or downstream effects are worth remembering.
