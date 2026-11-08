# Plan: refactor — tidy the food code

**For spec:** none (behaviour-preserving). Source: the whole-branch standards review of PR #72
(spec 016, `plans/done/016-food-logging-and-macro-targets.md`).
**Type:** refactor
**Branch:** chore/tidy-food-code

> Disposable. Once every task is merged, move this file to plans/done/.

## Approach
Spec 016 is built and merged; nothing here changes what the user sees or what is stored. Four
review findings and a handful of nits, each its own green task:

1. The three food targets (Calorie Target, protein and fat overrides) travel as loose `Double?`s
   through `FoodView`, `FoodStore` and the targets sheet; the core already has `FoodTargets`.
2. The Food screen pairs each shown entry back to its stored row by value, an untested decision
   in the shell (ADR 0002).
3. `FoodStore` repeats `BodyStore`'s store plumbing almost line for line.
4. `FoodViewTests.swift` (650 lines) also tests `FoodEntry` and `MacroTargets`, against the
   convention that tests mirror `src/`.

Existing tests stay green throughout. Where a task changes a core API the tests call, the task
updates those calls and keeps every `#expect` (checked in the diff). Task 2 adds one small core
API and tests it first. The shell can't build on Windows, so CI's macOS job is the shell's check.

## Tasks (ordered; each green and committed on its own)

1. [x] **Prefactor:** one `FoodTargets` value. Move `FoodTargets` into
   `src/SerenixCore/FoodTargets.swift`. `FoodView.init` takes `foodTargets: FoodTargets` in place
   of `calorieTarget`, `proteinOverride` and `fatOverride`; `FoodStore` publishes one
   `targets: FoodTargets` and `setTargets(_:suggested:)` takes one; the targets sheet saves a
   `FoodTargets`. The test helpers build a `FoodTargets`; every `#expect` stays.
   - Files: `FoodTargets.swift` (new), `BodyDataFile.swift`, `FoodView.swift`,
     `FoodViewTests.swift`, `src/SerenixApp/FoodStore.swift`, `FoodScreen.swift`,
     `FoodTargetsSheet.swift`, `ProfileMenu.swift`
   - Built: `ProfileMenu.swift` needed no change (it reads `storedFoodData()`); the stored row has a
     computed `targets`, and the store helper is `storedTargets(in:)`. Later, if wanted: the
     sheet's three typed values as one `FoodTargets`, and one `FoodTargets.refusal(suggested:)`
     for the store and the backup check.
   - Done when: suite green, lint clean; no three-value targets parameter left.
2. [x] **Slice:** the core says which stored entry each shown one is. `FoodView` gains
   `entryIndices: [Int]`, the positions in its `foodEntries` input of the shown Day's entries,
   newest first (so identical entries keep their own positions). The Food screen maps them to
   `store.rows` and drops `rows(for:in:)`.
   - Seam: Food view · Files: `FoodView.swift`, `FoodViewTests.swift`, `FoodScreen.swift`
   - Built: entries at the same time now keep their input order (the old sort didn't promise
     one), so the list's order is fixed. The screen builds the view and the list from one
     snapshot of `store.rows`; `FoodStore.entries`, now unused, is gone.
   - Done when: a test shows two identical entries get two different indices, in newest-first
     order; the screen has no value-matching left.
3. [x] **Prefactor:** one store helper. A small shell type (`OnDeviceStore`, new file) opens a
   named store file with a schema, runs a change with save-or-rollback, and carries the
   user-facing error type; `BodyStore` and `FoodStore` use it. Messages stay as they are.
   - Files: `src/SerenixApp/OnDeviceStore.swift` (new), `BodyStore.swift`, `FoodStore.swift`
   - Built: `OnDeviceStore` opens `<name>.store` with its models and makes save-or-rollback
     changes, with the same messages; the shared error is `OnDeviceStoreError`. Each store keeps
     a four-line `change` that applies its own `failure` and `reload()`. Only the macOS CI job
     can confirm it compiles.
   - Done when: suite green, lint clean, the macOS CI job builds; no duplicated container,
     change or error code left in the two stores.
4. [x] **Prefactor:** tests mirror `src/`. Move the Food Entry limit tests into
   `FoodEntryTests.swift` and the Macro Targets, override and override-check tests into
   `MacroTargetsTests.swift`; `FoodViewTests.swift` keeps Intake, Complete Days and left/over.
   Shared private helpers are copied as each file needs them. No test changes beyond moving.
   - Files: `tests/SerenixCoreTests/FoodViewTests.swift`, `FoodEntryTests.swift` (new),
     `MacroTargetsTests.swift` (new)
   - Built: 53 tests and 106 `#expect` before and after (17/35, 7/17, 29/54); each new file
     copies only the helpers it uses, with the section comments folded into the file headers.
     Left for task 5: the `foodView` helpers' unused parameters in each file, and making
     `LimitedMacro` private.
   - Done when: the same 1,050 tests pass; the moved `#expect` count matches.
5. [x] **Prefactor:** nits. `limitText` gets its own file; `MacroTargets`' two
   `overrideRefusal` extensions merge; the food sheets share one number parse and format helper;
   `FoodStore.storedFoodData` wraps read errors in the "couldn't be read" message as
   `BodyStore.allData` does; the food test files' `foodView` helpers lose unused parameters and
   `LimitedMacro` becomes private (from task 4's review).
   - Files: `src/SerenixCore/LimitText.swift` (new), `FoodEntry.swift`, `MacroTargets.swift`,
     `src/SerenixApp/NumberText.swift` (new), `FoodEntrySheet.swift`, `FoodTargetsSheet.swift`,
     `FoodStore.swift`
   - Built: the shared helper is `NumberText` (named for what it holds); the three food test
     files changed too (helpers trimmed, `LimitedMacro` private). Read errors from
     `storedFoodData` now say "Your Food Entries couldn't be read: …", as `BodyStore` does.
   - Done when: suite green, lint clean.
6. [x] **Verify:** `swift test` green, `swift format lint --strict --recursive src tests
   Package.swift` clean, `swift build` clean. Carried to the PR checklist (need the PR): the
   macOS CI build, and a short by-hand pass on the phone: log, edit and delete a Food Entry, set
   targets and overrides, export and import.
   - Done: `swift test` 1,053 passing (1,050 plus task 2's three), lint and `swift build` clean.
     Carried to the PR: the macOS build (tasks 1–3 and 5 change shell code only it can compile)
     and the phone pass above.
   - Blocked by: 1, 2, 3, 4, 5

## Done when
- All tasks checked, no behaviour changed, suite green, the macOS build green.
