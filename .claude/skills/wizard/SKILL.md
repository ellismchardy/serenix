---
name: wizard
description: Generate an interactive bash wizard that walks a human, stage by stage, through steps only they can perform — provisioning infrastructure, creating API keys or CI secrets, clicking through a third-party dashboard, or running a one-off migration or cutover — capturing each value into .env and GitHub secrets. Use when the work hits a wall only a human can pass; never for steps the agent can do itself.
---

# Wizard

A **wizard** is a bash script that walks a human through a manual procedure: it opens each
URL, says exactly what to click and copy, captures values (hidden for secrets), writes them to
`.env` and GitHub secrets/variables, confirms before anything irreversible, and shows progress.
The UX lives in [template.sh](template.sh) — everything above its `STAGES` marker is a shared
library you **never hand-edit**. Your job is to scope the procedure and author the stages.

A wizard is ephemeral by default (save it under `scripts/`, delete it when done). Commit it only
when the user wants a repeatable setup path — e.g. "new teammate onboarding" — and then link it
from the README.

## Process
1. **Scope the procedure.** Read the repo first: `.env.example`, README, docker-compose, framework
   config, and `.github/workflows/*` (every `secrets.*` / `vars.*` reference is a value the
   wizard must produce). For a migration: current state, target state, and the irreversible
   steps between. Show the user the ordered stages and the values each produces, and confirm.
   *Done when* each value has: where the human gets it, where it's written (`.env`, a GitHub
   secret, both, or nowhere), and whether it's secret.
2. **Map each stage's journey** — the precise path a stranger could follow ("Dashboard →
   Developers → API keys → Reveal test key → copy"). If you don't know the current UI, check
   the provider's docs (the `research` skill) or ask — never invent steps.
3. **Author it.** Copy `template.sh` to `scripts/<name>-wizard.sh`, replace the example stage
   with one `stage` per step in dependency order, and set `TOTAL_STAGES`. Use the helpers:
   `stage`, `say`/`step`/`note`/`warn`, `open_url`, `ask`/`ask_secret`, `write_env`,
   `set_secret`/`set_var`, `pause`/`confirm`. Open the URL before asking for its value;
   `ask_secret` for anything secret; `set_secret` only what CI actually needs; `confirm` before
   anything irreversible; one focused task per stage.
4. **Verify statically.** `bash -n <script>`, `shellcheck` if available, `chmod +x`. Don't run
   it yourself — it opens browsers and blocks on input. Trace that every value from step 1 lands
   where step 1 said, and every `set_secret` name matches a `secrets.*` reference in CI.
5. **Hand off.** Tell the user to run `bash scripts/<name>-wizard.sh` in their own terminal (it
   needs an interactive TTY, so not via the `!` prefix), then tell you when it's done.

## Rules
- `.env` stays git-ignored; only `.env.example` (dummy values) is committed — update it with any
  new keys.
- If the wizard sets GitHub secrets or variables, its first stage shows the target repo
  (`gh repo view --json nameWithOwner -q .nameWithOwner`) and `confirm`s it before any
  `set_secret` / `set_var`, so secrets can't land in an upstream fork parent.
- Never echo, log, or commit a captured secret.
