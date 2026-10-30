---
name: improve-architecture
description: Survey the codebase for deepening opportunities (shallow modules, leaky seams, hard-to-test code), present them as a visual HTML report, then grill through the one you pick. Run /improve-architecture [area] every few days, or when a bug had no good seam to test at.
disable-model-invocation: true
---

# Improve Architecture

Find architectural friction and propose **deepening opportunities**: refactors that turn shallow
modules into deep ones, for testability and agent-navigability. It's a survey that hands you
candidates; the one you pick becomes normal work through the loop.

Call the Skill tool with "codebase-design" for the vocabulary (**module, interface, depth,
seam, adapter, leverage, locality**) and principles (deletion test, the interface is the test
surface, one adapter = hypothetical seam). Use those terms exactly; don't drift into
"component", "service", "API", or "boundary". Domain names come from `GLOSSARY.md`; ADRs in
`docs/adr/` record decisions not to re-litigate.

## 1. Explore
**Scope first (YAGNI).** Deepening pays off where code keeps changing.
- If the user named an area or pain point, start there.
- Otherwise use `git log --oneline` (and `git log --stat`) over a good stretch of history to
  find hot spots — files and areas that keep changing — and weight those. Widen the net only if
  changes are scattered.

Then have the `investigator` agent walk that area and report friction:
- Understanding one concept means bouncing between many small modules.
- **Shallow** modules — interface nearly as complex as the implementation.
- Pure functions extracted just for testability, while the bugs hide in how they're called.
- Tightly coupled modules leaking across their seams.
- Code that's untested, or hard to test through its current interface.
- Places `/diagnose` reported "no correct seam for a regression test".

Apply the **deletion test** to every suspect: would deleting it concentrate complexity
(good candidate) or just move it?

## 2. Present the report
Write one self-contained HTML file to the OS temp dir (`$TMPDIR`, else `/tmp`; `%TEMP%` on
Windows) as `architecture-review-<timestamp>.html` — nothing lands in the repo. Open it
(`start` / `open` / `xdg-open`) and give the absolute path. Format, diagram patterns, and tone:
[HTML-REPORT.md](HTML-REPORT.md).

Each candidate card: **files**, **problem** (one sentence), **solution** (one sentence),
**wins** in locality/leverage/test terms, a **before/after diagram**, the dependency category,
and a strength badge (`Strong` / `Worth exploring` / `Speculative`). If a candidate contradicts
an ADR, include it only when the friction justifies reopening it, and say so on the card. End
with a **top recommendation**.

Don't propose interfaces yet. Ask: "Which of these would you like to explore?"

## 3. Grill the chosen candidate
Call the Skill tool with "grilling" and walk the design tree with the user: constraints,
dependencies and their category, the shape of the deepened module, what sits behind the seam,
which tests survive (replace, don't layer). Call the Skill tool with "domain-modeling" too:
- A deepened module named after a concept not in `GLOSSARY.md` → add the term.
- The user rejects a candidate for a load-bearing reason → offer an ADR, so future surveys
  don't re-suggest it.
- Want to compare alternative interfaces → use the design-it-twice pattern from the
  `codebase-design` skill.

## Then
The chosen refactor is real work: if it preserves behavior, it's a `chore/` plan built as
prefactor + expand–contract tasks (`/plan`); if it changes behavior, it needs `/write-spec`
first.
