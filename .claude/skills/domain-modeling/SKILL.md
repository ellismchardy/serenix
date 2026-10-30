---
name: domain-modeling
description: Build and sharpen the project's domain language — challenge fuzzy or conflicting terms, stress-test them with edge-case scenarios, and update GLOSSARY.md and docs/adr/ inline. Use when discussing domain terminology, editing GLOSSARY.md, or recording an architecture decision.
---

# Domain Modeling

The *active* discipline of shaping the domain model while you design. (Merely reading
`GLOSSARY.md` for vocabulary is not this skill — every skill does that.)

## During the session
- **Challenge against the glossary.** When the user uses a term that conflicts with
  `GLOSSARY.md`, say so immediately: "The glossary defines *cancellation* as X, but you seem to
  mean Y. Which is it?"
- **Sharpen fuzzy language.** For vague or overloaded words, propose one precise canonical term:
  "By *account* do you mean the Customer or the User? Those are different things."
- **Stress-test with scenarios.** Invent concrete edge cases that force precision about where
  one concept ends and another begins.
- **Cross-check the code.** When the user says how something works, check the code agrees, and
  surface contradictions: "The code cancels whole Orders, but you said partial cancellation is
  possible. Which is right?"

## Update GLOSSARY.md inline
When a term is resolved, write it into `GLOSSARY.md` right then — don't batch. Format:

```md
**Order**:
A customer's confirmed request to buy one or more products.
_Avoid_: purchase, transaction
```

- **Be opinionated.** Pick one word per concept; list the rejected synonyms under `_Avoid_`.
- **Tight definitions.** One or two sentences: what it IS, not what it does.
- **Project-specific terms only.** General programming concepts (timeouts, retries, DTOs) don't
  belong. Group terms under subheadings when natural clusters appear.
- **No implementation details.** The glossary is not a spec, a scratch pad, or a decision log.

If the project grows several bounded contexts, keep one `GLOSSARY.md` per context (next to its
code) and list them in a root `GLOSSARY-MAP.md` with how the contexts relate.

## Offer ADRs sparingly
Offer an ADR only when the decision is hard to reverse, surprising without context, **and** the
result of a real trade-off. Format, numbering, and examples: `docs/adr/README.md`.
