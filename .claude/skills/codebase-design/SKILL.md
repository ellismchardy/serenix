---
name: codebase-design
description: Shared vocabulary and principles for designing deep modules — a lot of behavior behind a small interface, at a clean seam, testable through that interface. Use when designing or reshaping a module's interface, deciding where a seam goes, making code more testable or easier for agents to navigate, or when another skill (spec, plan, review, architecture survey) needs this vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behavior behind a small interface, placed at a clean seam,
testable through that interface. The aim is leverage for callers, locality for maintainers,
and testability for everyone.

## Vocabulary
When discussing module design, use these terms exactly — consistent language is the point.
(The _Avoid_ lists apply to design discussion; "system boundary" for where external
dependencies sit, and section names in existing docs, are fine.)

- **Module** — anything with an interface and an implementation, at any scale: a function,
  class, package, or a slice spanning tiers. _Avoid_: unit, component, service.
- **Interface** — everything a caller must know to use the module correctly: the type
  signature, plus invariants, ordering constraints, error modes, required config, and
  performance characteristics. _Avoid_: API, signature (too narrow).
- **Implementation** — the code inside a module.
- **Depth** — leverage at the interface: how much behavior a caller (or test) gets per unit of
  interface they must learn. **Deep** = lots of behavior, small interface. **Shallow** = the
  interface is nearly as complex as the implementation.
- **Seam** _(Michael Feathers)_ — a place where behavior can be altered without editing in that
  place; where a module's interface lives. _Avoid_: boundary.
- **Adapter** — a concrete thing that satisfies an interface at a seam (a Postgres repo, an
  in-memory fake). Names a role, not a size.
- **Leverage** — what callers get from depth: one implementation pays back across N call sites
  and M tests.
- **Locality** — what maintainers get from depth: change, bugs, and knowledge concentrate in
  one place. Fix once, fixed everywhere.

## Principles
- **Depth is a property of the interface.** A deep module can be built from small internal
  parts with their own **internal seams**; they just aren't part of the interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a
  pass-through. If complexity reappears across its callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. Needing to test
  *past* the interface means the module is the wrong shape.
- **One adapter means a hypothetical seam; two means a real one.** Don't add a seam (a port,
  an injected dependency) unless something actually varies across it — typically production
  and test.

When designing an interface, ask: can I reduce the number of entry points? Simplify the
parameters? Hide more inside?

## Designing for testability
1. **Accept dependencies, don't create them** — pass the payment gateway in; don't `new` it
   inside.
2. **Return results, don't produce side effects** — `calculateDiscount(cart): Discount` beats
   `applyDiscount(cart): void`.
3. **Small surface area** — fewer entry points, fewer tests; fewer params, simpler setup.

## Going deeper
- Deepening a cluster of shallow modules given its dependencies (in-process,
  local-substitutable, owned-remote, true-external) and how to test across each:
  [DEEPENING.md](DEEPENING.md).
- Exploring radically different interfaces in parallel before committing to one:
  [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md).
