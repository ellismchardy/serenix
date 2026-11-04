# Plan: 014 — Onboarding

**For spec:** specs/014-onboarding.md
**Type:** feature
**Branch:** feat/onboarding

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Approach
Build an `Onboarding` value type in `SerenixCore`: state in, events in, and out come bubbles,
answer controls and the Profile change to save. The current year and the pairing/sync state are
passed in as values. The tracer bullet replaces the NamePrompt end to end: Hello, then Name, then
the pair step offering only Set up later, gated on a "finished" rule that also covers existing
installs. Later slices add the Profile questions, pairing, the sync and resume, each through the
same type. The shell gets one `OnboardingScreen` that draws whatever the type returns, saves
through `ProfileStore`, and maps `StrapConnection`'s `StrapPhase` and sync progress to events. No
prefactor: `ProfileStore` already holds birth year, sex and Max HR (spec 005), and
`StrapConnection` already exposes `connect()`, `phase` and the sync's progress. The tasks are
strictly ordered, because each one extends the same `Onboarding` type and screen.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice (tracer):** Hello, then Name, then the pair step with Set up later. Onboarding replaces the NamePrompt.
   - Seam: Onboarding conversation (`SerenixCore`) · Files: `src/SerenixCore/Onboarding.swift`,
     `tests/SerenixCoreTests/OnboardingTests.swift`, `src/SerenixApp/OnboardingScreen.swift`
     (new), `src/SerenixApp/SerenixApp.swift`, `src/SerenixApp/ProfileStore.swift`,
     `src/SerenixApp/NamePrompt.swift` (deleted)
   - Covers: the Hello bubbles. The name is trimmed, and a blank name counts as Skip. "Nice to
     meet you[, name]." is said for now just before the pair step. Set up later finishes
     Onboarding. The finished rule is: an explicit finish, or the legacy NamePrompt answered, or
     a History Sync completed. The shell stores the finished flag and shows Onboarding until it
     is set.
   - Done when: the fresh-conversation, name, "Show me Today/Set up later finish" (Set up later
     half) and "counts as finished for existing users" criteria pass as tests.
2. [x] **Slice:** questions for birth year, sex and Max HR, with validation.
   - Seam: Onboarding conversation · Files: `src/SerenixCore/Onboarding.swift`,
     `tests/SerenixCoreTests/OnboardingTests.swift`, `src/SerenixApp/OnboardingScreen.swift`
   - Covers: the birth year range checked against the current year passed in, the out-of-range
     bubbles that keep the question open, the Rather not, Don't know and sex chips, and a
     Profile change emitted for each answer (the shell saves it, which queues Load per spec 005).
   - Done when: the birth year, sex and Max HR criteria pass.
3. [x] **Slice:** pairing (Find my Strap, Looking, not found, refused, Try again, Connected).
   - Seam: Onboarding conversation · Files: `src/SerenixCore/Onboarding.swift`,
     `tests/SerenixCoreTests/OnboardingTests.swift`, `src/SerenixApp/OnboardingScreen.swift`
   - Covers: pairing events (found, not found, refused, connected with model) and their bubbles
     and chips. The shell calls `StrapConnection.connect()` and maps its phase and failure kind
     to these events.
   - Done when: the pair-step criterion passes, and Connected shows "Found it — <model>."
4. [x] **Slice:** syncing, then Show me Today.
   - Seam: Onboarding conversation · Files: `src/SerenixCore/Onboarding.swift`,
     `tests/SerenixCoreTests/OnboardingTests.swift`, `src/SerenixApp/OnboardingScreen.swift`
   - Covers: the Syncing bubble with the Calibrating note, progress shown as a percentage, "✓
     Synced", the failed message, and Show me Today offered at once and finishing Onboarding.
   - Done when: the Connected/sync criterion and the Show me Today half of the finish criterion
     pass.
5. [x] **Slice:** resume from saved answers after a relaunch.
   - Seam: Onboarding conversation · Files: `src/SerenixCore/Onboarding.swift`,
     `tests/SerenixCoreTests/OnboardingTests.swift`, `src/SerenixApp/OnboardingScreen.swift`
   - Covers: building the conversation from the saved Profile plus a stored set of the steps
     already answered, so a skipped question also counts as answered. The answers are replayed
     as the user's bubbles, and the conversation opens at the first unanswered step.
   - Done when: the resume criterion passes.
6. [ ] **Verify:** `swift test`, `swift format lint --strict --recursive src tests
   Package.swift` and `swift build` are all green, and every spec criterion except the phone
   checks is ticked. Carried to the PR checklist: the macOS CI build, and the by-hand phone
   checks listed in the spec's last criterion.

## Done when
- All tasks checked, every success criterion in the spec met, suite green.
