---
name: grilling
description: Interview the user in structured rounds until every branch of a plan, feature, or design is resolved — numbered questions, each with a recommended answer. Use when an idea needs stress-testing before a spec or plan, when requirements are fuzzy, or when the user says "grill me" or asks to be interviewed.
---

# Grilling

Interview the user until you reach a shared understanding. Map the topic as a **design tree**:
every decision branches into the decisions that hang off it.

## Rounds
Work the tree in **rounds**. The **frontier** is every open decision whose prerequisites are
already settled — the questions you can ask *now* without guessing at answers you haven't heard.
Ask the whole frontier in one round, then wait for answers before the next.

```
❓ **Q1 — <question title>**: <question body; may include options>

➡️ <your recommended answer, with a one-line reason>

---

❓ **Q2 — <question title>**: ...

➡️ ...
```

- Number every question and give a recommendation for each. Word it so "yes" accepts the
  recommendation — the user can then answer a whole round with "yes to all but Q3".
- A question whose answer depends on another question still open this round belongs to a
  *later* round.
- Each round's answers reshape the tree: recompute the frontier and ask the next round.

## Facts are yours, decisions are theirs
Never ask the user for something you can look up. When a question needs a fact from the
codebase or environment, find it yourself (the `investigator` agent is good for this) — and
don't block the rest of the round on it; only the questions downstream of that fact wait.
Put every *decision* to the user.

## Done
The session is done when the frontier is empty: every branch visited, nothing silently assumed.
Summarize what was decided and get the user's confirmation before acting on it.
