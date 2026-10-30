# Example workflows

How the skills fit together in practice. One running example throughout: a three-person team
(Sam, Priya, Jo) building **Tally**, an invoicing app for freelancers. Commands are what you
type in Claude Code; everything else is what happens as a result.

## Which flow am I in?

| Situation | Start with | Then |
|---|---|---|
| Brand-new project | `/kickoff` | `/scaffold` → `/ship` |
| A feature you can describe in a paragraph | `/write-spec` | `/plan` → `/execute` → `/ship` |
| A feature too big or foggy to spec yet | `/wayfinder` | `/write-spec` per spec it names |
| Something is broken | `/diagnose` | `/plan` → `/execute` → `/ship` |
| Issues piling up from users/teammates | `/triage` | `/write-spec #n` or `/diagnose #n` |
| You want *different* behavior than the spec says | edit the spec (`/write-spec`) | `/plan` → `/execute` → `/ship` |
| The code is getting hard to change | `/improve-architecture` | `/plan` (refactor) → `/execute` → `/ship` |
| A step only a human can do (accounts, keys) | ask Claude; it uses the `wizard` skill | run the script yourself |
| End of a session | `/handoff` (to continue elsewhere) or `/retro` (to improve the setup) | |

```
            ┌───────────── /triage ◄── GitHub issues
            │                 │
 idea ──► /write-spec ◄───────┤  (enhancement)          /wayfinder ──► (decisions) ──┐
            │   ▲             └──► /diagnose (bug)                                   │
            │   └──────────────────────────────────────────────────────────────────┘
            ▼                          │
          /plan ◄──────────────────────┘ ◄── /improve-architecture (refactor)
            │
            ▼
   /execute  (or /execute-parallel)    ← one task = failing test → green → 2 reviewers → commit
            │
            ▼
          /ship                        ← sync → checks → branch review → PR → squash-merge
```

Durable records the flows read and write: `specs/` (what it should do), `GLOSSARY.md` (what
we call things), `docs/adr/` (why we chose), `docs/research/` (what we found out),
`.out-of-scope/` (what we decided not to do). Plans are scaffolding and get archived.

---

## 1. Day zero: kickoff → scaffold → ship

**Sam:** `/kickoff A web app where freelancers create invoices, send them to clients by email, and see which are paid or overdue.`

Claude grills in rounds. Each question comes with a recommended answer, so Sam can reply
"yes to all but Q3":

> ❓ **Q1 — Who's the user?** Solo freelancers only, or small agencies with several people
> invoicing under one business?
> ➡️ Solo freelancers for v1. Agencies add permissions, which is a whole feature.
>
> ❓ **Q2 — Stack?** The team knows TypeScript. Next.js + Postgres + vitest?
> ➡️ Yes. One language end to end, and Postgres handles money with `numeric` cleanly.

Along the way, the `domain-modeling` skill pins the vocabulary. "Bill", "invoice" and "quote"
were being used loosely, so `GLOSSARY.md` gets:

```md
**Invoice**:
A request for payment for completed work, sent to one Client.
_Avoid_: bill, statement

**Quote**:
An offer of a price for future work. Becomes an Invoice only when accepted.
_Avoid_: estimate, proposal
```

When the interview is done, Claude fills in `CLAUDE.md`, `docs/architecture.md`,
`docs/conventions.md`, and writes `docs/adr/0001-postgres-numeric-for-money.md`. That decision
is hard to reverse, surprising to a future reader, and a real trade-off against storing
integer cents, so it passes the ADR test.

**Sam:** `/scaffold` → on `chore/scaffold`: Next.js skeleton, vitest with one trivial test,
lint/typecheck config, `.github/workflows/ci.yml`, a Husky pre-commit hook. Claude runs every
key command and reports each result.

**Sam:** `/ship` → checks are green, the PR opens, CI passes, Priya approves. Sam says "merge", and
Claude squash-merges.

> **Do this once in GitHub:** protect `main` (require a PR, require the CI check, require one
> review), allow squash merging only, and auto-delete head branches.

---

## 2. A feature, start to finish

### Spec
**Priya:** `/write-spec Send an invoice to a client by email`

Claude reads `GLOSSARY.md`, related specs, and the ADRs, explores the code with the
`investigator` agent, then grills: what happens on a bounced email, can a sent Invoice be
edited, is there a resend. One question can't be settled by talking ("Which email provider
lets us track opens on the free tier?"), so Claude uses the `research` skill. A background agent
reads the providers' docs and writes `docs/research/email-provider-open-tracking.md` with
citations, while the grilling carries on.

Claude proposes the **seams under test**:

> - `sendInvoice(invoiceId)` domain function: catches status changes, validation, and the
>   bounce rule; misses the HTTP layer.
> - `POST /invoices/:id/send`: catches auth and the request contract end to end; slower.

Priya agrees, and Claude writes `specs/004-send-invoice.md` with checkable success criteria
("sending a Draft Invoice sets status to Sent and records `sentAt`", "sending a Paid Invoice
returns 409"). Priya approves it and the status becomes `approved`.

### Plan
**Priya:** `/plan specs/004-send-invoice.md`

```md
1. [ ] Prefactor: extract Invoice status transitions into one module (no behavior change)
2. [ ] Slice: send a Draft Invoice → status Sent (seam: sendInvoice) — tracer bullet
3. [ ] Slice: reject sending a Paid/Void Invoice with 409 (seam: POST /invoices/:id/send)
   - Blocked by: 2
4. [ ] Slice: email body renders line items and total (seam: sendInvoice)
   - Blocked by: 2
5. [ ] Slice: bounced email marks Invoice "Delivery failed" (seam: sendInvoice)
   - Blocked by: 4
6. [ ] Verify: full suite + lint + typecheck; every success criterion checked
   - Blocked by: 3, 5
```

Each slice is a thin end-to-end path that is green on its own. There's no separate "write
the tests" task.

### Execute
**Priya:** `/execute`

- First run: Claude creates `feat/send-invoice` from `main` and commits the spec, plan, and
  research note.
- Task 1 is a prefactor, so the existing suite has to stay green and no new test is needed.
  Claude stages the change, `spec-reviewer` and `standards-reviewer` review it in parallel,
  and Claude commits it with the checkbox ticked.
- Claude stops. Priya runs `/clear`, then `/execute` again for task 2. The `test-writer`
  agent writes `sending a draft invoice marks it sent`, runs it, and shows it failing for the
  right reason. Claude implements just enough to pass, then the checks, reviewers, and commit
  follow.

After the tracer bullet (task 2) lands, tasks 3 and 4 depend only on it. Priya runs
**`/execute-parallel`**: two implementer agents work in separate git worktrees. Each merge
into `feat/send-invoice` is checked, reviewed on both axes, ticked, and committed on its own.
Task 5 waits for 4, then runs.

Want it hands-off? `/loop /execute` runs one task per iteration until the plan is done.

### Ship
When the last box is ticked, the spec is marked `built` and the plan moves to `plans/done/`.

**Priya:** `/ship`

1. Preflight: Priya is on a feature branch, the tree is clean, and the plan is done.
2. Main has moved (Jo merged something), so Claude merges `origin/main` into the branch and
   re-runs the checks.
3. Both reviewers look at the **whole branch** (`git diff origin/main...HEAD`), which catches
   cross-task problems per-task reviews miss.
4. Claude drafts the PR from `.github/pull_request_template.md`:

   ````md
   ## Summary
   ```text
   POST /invoices/:id/send
     sendInvoice(id)
       assertTransition(Draft → Sent)
       renderInvoiceEmail()
       emailClient.send()      ← mocked at the boundary in tests
       record sentAt
   ```
   ## Evidence
   - Before: `sending a draft invoice marks it sent` ✗ (status stayed Draft)
   - After: 14 new tests ✓, full suite ✓, CI ✓
   ## Merge danger
   **Door:** one-way. It sends real emails to clients once deployed.
   **Blast radius:** every Invoice send. Behind the `invoice_sending` flag.
   ````
5. Priya says "go": the branch is pushed and the PR opened. After CI and Jo's approval she
   says "merge", and Claude squash-merges, deletes the branch, and pulls `main`.

---

## 3. A bug report from a user

A client reports through the **Bug report** issue form: "Overdue badge shows on invoices
due today." The form applies `bug` + `needs-triage`.

**Jo:** `/triage` → "what needs attention?" → Claude lists unlabeled and `needs-triage` issues.
Jo says "let's look at #57".

1. Claude reads the issue and checks it isn't already fixed or rejected in `.out-of-scope/`.
2. It reproduces the bug: an Invoice due today, viewed at 09:00 in UTC+10, shows Overdue.
3. Jo agrees. Claude shows the exact comment and labels it will post, Jo approves, and #57
   becomes `ready-for-agent` with an **agent brief** (current behavior, desired behavior, key
   interfaces, acceptance criteria, out of scope).

**Jo:** `/diagnose #57`

- **Feedback loop first:** a failing vitest at the `isOverdue(invoice, now)` seam with a pinned
  clock and timezone. It runs in under a second and is red.
- **Minimise:** it fails only when the client's timezone is ahead of UTC.
- **Hypotheses (ranked):** (1) the due date is stored as a UTC midnight timestamp and
  compared to `now`; (2) the badge uses the browser's timezone and the API uses the server's;
  (3) an off-by-one in a `<` vs `<=`.
- **Instrument:** `[DEBUG-7c1e]` logs show hypothesis 1 holds. Claude removes the debug lines
  and reverts the experiment.
- Claude reports the root cause with `file:line`. The spec already says "overdue the day
  after the due date", so **the spec doesn't change**.

**Jo:** `/plan` → `plans/fix-overdue-timezone.md` on `fix/overdue-timezone`. Task 1 turns the
minimised repro into the regression test and fixes it. Then `/execute` and `/ship`, with the
confirmed hypothesis stated in the PR, and `Closes #57`.

### A request we turn down
Issue #61 asks for "a full accounting ledger". During `/triage`, Jo decides it's out of scope.
Claude writes `.out-of-scope/accounting-ledger.md` (why, and links to the issues that asked)
on a `chore/` branch, Jo `/ship`s it, and Claude closes the issue with a comment linking the PR. When #88 asks for "double-entry
bookkeeping" months later, triage spots the match and shows the earlier reasoning.

---

## 4. A huge, foggy effort: multi-currency

"Support clients in other currencies" touches money storage, tax, exchange rates, reports, and
UI. Nobody can spec that in one sitting.

**Sam:** `/wayfinder Support invoicing clients in other currencies`

- Grilling names the **destination**: *"specs for currency-aware Invoices and for reporting
  in the freelancer's home currency, ready to write."*
- Claude creates a **map** issue (`wayfinder:map`) and child **decision tickets**, with
  blocking edges:
  - *Which exchange-rate source do we trust?* — `wayfinder:research`. A background agent
    starts on it right away.
  - *Is the rate locked when an Invoice is sent, or when it's paid?* — `wayfinder:grilling`
  - *What does a mixed-currency revenue report look like?* — `wayfinder:prototype`.
    Blocked by the two above.
- Anything still too vague to ticket ("what about tax on foreign invoices?") goes under
  **Not yet specified**.

Over the next week, each `/wayfinder #<map>` session claims **one** frontier ticket, resolves
it, and records the answer. Rates lock at send time, which earns an ADR. The prototype ticket
uses the `prototype` skill. Claude builds three report layouts on the existing reports page,
switchable with `?variant=`, and keeps them on an unmerged `prototype/fx-report` branch. Sam
picks B with the totals row from C.

When the map has no open tickets and no fog, Sam runs `/write-spec` twice, pointing at the
map. Each spec then goes through the normal plan → execute → ship loop.

---

## 5. Keeping the codebase healthy

Diagnosing #57 found that `isOverdue` had no good seam: date logic was spread across three
components. Later Jo runs:

**Jo:** `/improve-architecture invoices`

Claude finds the hot spots in `git log` and opens an HTML report in the temp dir. Each
candidate card shows a before/after diagram: "Collapse Invoice date rules into one deep module
(strong)", "Merge the two email adapters (speculative)". Jo picks the first, and Claude grills
the design using the `codebase-design` vocabulary (module, interface, seam, adapter) and can
draft alternative interfaces in parallel.

The behavior doesn't change, so it's a refactor plan on `chore/invoice-date-rules`. It renames
a widely used function, so `/plan` sequences it **expand → migrate → contract**: add the new
module beside the old one, move callers over in batches (the suite stays green each time), then
delete the old one.

---

## 6. Steps only a human can do

Deploying the email feature needs a production email API key, a webhook secret, and both
stored as GitHub Actions secrets. Claude can't create accounts for you, so it reaches for the
`wizard` skill and writes `scripts/email-setup-wizard.sh`. Sam runs it **in their own terminal**
(it's interactive): it opens each dashboard page, says what to click, captures each value
(secrets hidden), writes `.env`, and calls `gh secret set`. The team decides to keep it for
onboarding, so it's committed and linked from the README.

---

## 7. Sessions, context, and the team

- **Between `/execute` runs, `/clear` freely.** The plan's checkboxes and the commits carry
  the state.
- **Keep spec writing in one session.** The grilling, the spec, and the plan build on the same
  thinking, so don't clear partway through.
- **`/handoff`** when work moves to a new session, another machine, or a teammate. It writes a
  short doc to your temp dir and points at the spec, plan, and commits instead of repeating them.
- **`/retro`** after a session that went sideways. Typical findings: "the agent imported from
  `src/internal/` twice, so add a lint rule"; "the reviewer missed an unvalidated query param,
  so add it to conventions.md"; "CLAUDE.md has grown, so move the testing detail into
  conventions.md".

**On a team:**
- Each person works one feature at a time, on their own branch, and merges it before starting
  the next. Several people can have features in flight at once; `/ship` merges `main` into the
  branch before opening the PR.
- New decisions go in new ADR files, and glossary entries are small hunks, so parallel
  branches rarely conflict.
- `/triage` is the shared front door for incoming work. Wayfinder maps live on GitHub so
  anyone can see the frontier and claim a ticket.
- Hard rules are enforced by machines: the git hook blocks destructive commands, and CI plus
  branch protection guard `main`. Review standards live in `docs/conventions.md`, and
  mechanical rules belong in the linter.
