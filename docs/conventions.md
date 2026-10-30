# Conventions

The "how we do things here" rules. Claude reads this to match existing patterns instead of
inventing new ones.

## Naming
- Files: <e.g. kebab-case>
- Variables/functions: <e.g. camelCase>
- Components/classes: <e.g. PascalCase>
- Tests: `<e.g. *.test.ts next to source>`

## Code patterns
- <e.g. Prefer pure functions in core; side effects at the edges.>
- <e.g. No business logic in route handlers.>
- <e.g. Validate input at the boundary.>

## Testing
- Framework: <e.g. vitest>
- Every feature ships with tests; every bug fix ships with a regression test.
- Test behavior through public interfaces, at the seams the spec agrees — never internals.
- Test naming: describe the behavior, not the implementation.
- Expected values are known literals or come from the spec — never recomputed like the code.
- Mock only at system boundaries (external APIs, time, randomness); don't mock what you don't
  own without a wrapper. Full rules: `.claude/skills/tdd/`.

## Code review
- Every task and every PR is reviewed on two separate axes: **spec** (`spec-reviewer`) and
  **standards** (`standards-reviewer`). Blocking findings are fixed before commit/merge.
- This file *is* the standards the reviewer enforces. Mechanical rules (banned APIs, import
  shapes, file locations) belong in the linter or a hook instead; keep this file for judgement
  calls.

## Git
- Branch per change: `feat/<name>`, `fix/<name>`, `chore/<name>`. `prototype/<name>` branches
  hold throwaway prototypes and are never merged.
- Commit after each completed (green) plan task.
- Commit messages: imperative mood, present tense ("add login validation").
- One PR per branch, body from `.github/pull_request_template.md`, squash-merged to `main`
  with green CI.

## Definition of done
- [ ] Meets the spec's success criteria
- [ ] Tests pass (new + existing), locally and in CI
- [ ] Lint + typecheck clean
- [ ] Both review axes clear of blocking findings
- [ ] Spec still reads true; GLOSSARY.md updated for new terms; an ADR in `docs/adr/` if a
      hard-to-reverse choice was made
