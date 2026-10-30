# <NNN> — <Feature name>

**Status:** draft | approved | built
**Last updated:** YYYY-MM-DD
**Issue:** <tracker link, if this came from one — otherwise omit>

## Problem
<The problem, from the user's perspective. Why this matters now.>

## Goal
<One or two sentences: what this feature lets a user do.>

## User stories
1. As a <role>, I want <capability> so that <benefit>.
2. <Cover the edge cases and the unhappy paths, not just the headline story.>

## Behavior
<What the feature does, in plain language, using GLOSSARY.md terms. The desired state. Be
specific about inputs, outputs, errors, and empty/limit cases.>

## Design decisions
<Modules built or changed, their interfaces, schema/API contracts, notable interactions. Name
modules and interfaces, NOT file paths or code — those go stale. Link any ADR in docs/adr/.>

## Seams under test
<The public interfaces tests will exercise — prefer existing seams, and as few as possible.
One line each on what it catches and what it misses.>
- <e.g. HTTP API (`POST /login`) — catches auth + validation end to end; misses UI wiring>

## Success criteria (must be checkable)
- [ ] <e.g. POST /login with valid creds returns 200 + a session token>
- [ ] <e.g. Passwords under 8 chars are rejected with a 422>
- [ ] <e.g. `npm test auth` passes>

## Non-goals (explicitly out of scope)
- <e.g. Password reset flow — separate feature>
- <e.g. OAuth / social login>

## Open questions
- <Anything undecided. Resolve before approval, or note the assumption made.>

## Notes
<Links to related specs, designs, prototypes, or ADRs.>
