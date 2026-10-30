# Plan: <NNN> — <Feature name or bug summary>

**For spec:** specs/<NNN>-<name>.md   (bugs: link the issue/root cause; refactors: the architecture review)
**Type:** feature | bug | improvement | refactor
**Branch:** feat/<name> | fix/<name> | chore/<name>

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
<One short paragraph: how you'll get from current state to the spec. For bugs: the confirmed
root cause and the minimised repro that proves it.>

## Tasks (ordered; each is one vertical slice, green and committable on its own)
<!-- A behavior task is ONE red→green cycle: /execute writes its failing test, then makes it
     pass, then commits. Don't split "write test" and "implement" into separate tasks.
     Tasks run in order unless they declare "Blocked by:" — a task with an explicit
     "Blocked by:" line can run in parallel with others whose blockers are done
     (/execute-parallel). Omit the line to mean "blocked by the task before it". -->

1. [ ] **Prefactor:** <optional — reshape existing code so the change is easy; no behavior change>
   - Files: `<paths>`
   - Done when: existing suite still green.
2. [ ] **Slice:** <thinnest end-to-end path through the feature (tracer bullet)>
   - Seam: <which seam from the spec> · Files: `<paths>`
   - Done when: <the specific success criterion this slice satisfies>
3. [ ] **Slice:** <independent behavior that only needs the tracer bullet>
   - Blocked by: 2
   - Seam: <...> · Files: `<paths>`
   - Done when: <...>
4. [ ] **Slice:** <another behavior independent of 3>
   - Blocked by: 2
   - Seam: <...> · Files: `<paths>`
   - Done when: <...>
5. [ ] **Verify:** full suite + lint + typecheck green; every spec success criterion checked.
   - Blocked by: 3, 4

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
