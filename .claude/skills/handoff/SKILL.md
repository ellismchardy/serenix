---
name: handoff
description: Compact the current session into a handoff document so a fresh session, another tool, or a teammate can pick up the work. Run /handoff [what the next session will focus on].
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

Write a handoff document so a fresh agent (or a colleague) can continue this work without the
conversation.

Save it to the OS temp directory (`$TMPDIR`, else `/tmp`; `%TEMP%` on Windows), **not** the
repo, and tell the user the full path. It's a bridge, not a record — the durable record is the
spec, plan, ADRs, and commits.

## Contents
- **Goal** — what we're trying to achieve, in one or two lines.
- **Where we are** — branch, the active plan and its next unchecked task, last commit.
- **What's settled** — decisions made this session that aren't written down anywhere yet.
- **What's open** — unresolved questions, blockers, things that surprised us.
- **Next steps** — the concrete next actions, in order.
- **Suggested skills** — which skills or commands the next session should use
  (e.g. `/execute plans/003-export.md`, the `diagnose` skill).

## Rules
- **Don't duplicate** what's already in a spec, plan, ADR, issue, commit, or diff — reference it
  by path or URL.
- **Redact** secrets, tokens, passwords, and personal data.
- If the user passed an argument, it describes what the next session will focus on — tailor
  the document to that.
