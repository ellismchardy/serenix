**Spec:** specs/<NNN>-<name>.md · **Plan:** plans/done/<plan>.md · Closes #<issue>

## Summary
<!-- The smallest visual that makes the change clear: call tree, file tree, pseudocode,
     a diff-style sketch, or a Mermaid diagram — plus a sentence or two. -->

## Evidence
<!-- Before/after you actually ran: the test that failed and now passes, command output,
     or screenshots for UI changes. -->
- **Before:**
- **After:**

## Merge danger
**Door:** one-way | two-way
<!-- One-way = can't be cleanly rolled back (schema migration, data deletion, public API
     change, messages sent to users). Say what makes it one-way. -->

**Blast radius:** <!-- who/what breaks if this is wrong -->

## Checklist
- [ ] Meets every success criterion in the spec (or the bug's regression test passes)
- [ ] Tests, lint, and typecheck green locally and in CI
- [ ] Spec still reads true; GLOSSARY.md / ADRs updated if terms or hard decisions changed
- [ ] No secrets, `.env` files, or debug instrumentation in the diff
