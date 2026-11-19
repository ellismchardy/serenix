# Plan: 020 — Backup

**For spec:** specs/020-backup.md
**Type:** feature
**Branch:** feat/backup (already exists: holds the approved spec, ADR 0009 and the glossary term)

> Disposable. Once every task is merged, move this file to plans/done/ (or delete it).
> Each iteration gets a NEW plan — never re-edit an old, executed one.

## Context
Deleting a sideloaded build loses every Night and Day for good: the store goes with the app and
the Strap never resends acknowledged History Records. Spec 020 adds a Backup file holding Nights,
Days and Body data. You can export and import it by hand, or Serenix can write it on its own to
a folder you picked. Restored Nights and Days are protected from rebuilds.

## Approach
- **Wrap the Body data file, don't rewrite it.** A new `BackupFile` in `SerenixCore` holds
  Nights, Days (`DayLoad`) and `BodyData`, and delegates every Body rule to the existing
  `BodyDataFile` (`src/SerenixCore/BodyDataFile.swift`). That means `BodyDataFile.importing`,
  `.refusal`, and `.decode` for `serenix-body` version 1 and 2 files. So the existing
  `BodyDataFileTests` pass unchanged, as the spec requires. The shell stops calling
  `BodyDataFile.encode`.
- `Night` gains `Codable`. `Day`, `HeartRateTrace`, `WakeBout` and `DayLoad` already have it.
- **Protecting restored dates.** The existing rebuild-queue functions in `NightRebuild.swift` and
  `DayRebuild.swift` gain a `sparing restored: Set<Day>` parameter. It defaults to empty, so the
  existing tests and callers compile unchanged.
- **Why a queue filter isn't enough.** The investigation found that the shell snapshots its
  pending queues (`StrapConnection.rebuildNights()`, around :453 and :480) and that queues
  survive across launches. So the shell also needs:
  - Import drops restored dates from both pending queues, using a core helper.
  - `NightStore.apply` and `DayLoadStore.apply` skip a row marked restored. This is a one-line
    guard, checked by hand.
- **When a sync "added or changed" something.** This is decided in core by comparing the Nights
  and Days read before and after a rebuild pass. `rebuildNights()` already holds both reads.

## Tasks (ordered; each is one vertical slice, green and committable on its own)

1. [x] **Slice: Backup file round trip (tracer bullet).**
   - What it builds:
     - `Night: Codable`.
     - A `Backup` value: nights, days (`[DayLoad]`) and body (`BodyData`).
     - `BackupFile.encode`, which writes `format: "serenix-backup"`, `version: 3`, sorted keys,
       in the same style as `BodyDataFile.encode`.
     - `BackupFile.decode`, which reads its header first. It accepts `serenix-backup` up to
       version 3, and `serenix-body` version 1 or 2 through `BodyDataFile.decode`, which gives
       empty Nights and Days.
     - `BackupFileError` with the cases `unreadable`, `wrongFormat`, `newerVersion(Int)` and
       `invalidEntry(reason)`, each with a `message`.
   - Test data: hand-built Nights in the style of `nightWithTrace` (`NightRebuildTests.swift:173`)
     and `SleepViewTests.swift` around :54. Hand-built `DayLoad`s in the style of `storedDay`
     (`DayRebuildTests.swift:136`).
   - Seam: Backup file.
   - Files:
     - `src/SerenixCore/BackupFile.swift` (new)
     - `src/SerenixCore/Night.swift`
     - `tests/SerenixCoreTests/BackupFileTests.swift` (new)
   - Done when these spec criteria pass:
     - The round trip, including a Night with and without trace, wake bouts and each metric,
       and a Day with Load and with a missing reason.
     - The file has `serenix-backup` version 3.
     - A truncated file, another format and a version 4 file are each refused with their
       typed error.
     - Version 1 and 2 Body files import with 0 Nights and 0 Days.
     - `BodyDataFileTests` are untouched and green.

2. [x] **Slice: import preview with the phone-wins date rule.**
   - What it builds: `BackupFile.importing(_:into:now:timeZone:) -> BackupImport`, holding
     `nightsToAdd`, `daysToAdd`, `body: BodyImport` (from `BodyDataFile.importing`) and a total
     `skipped`. A file Night or Day whose date is already stored is skipped.
   - Seam: Backup file.
   - Files: `BackupFile.swift`, `BackupFileTests.swift`.
   - Done when these pass:
     - The 5 Nights / 5 Days case, with 2 Night dates and 1 Day date already here, reports 3
       Nights and 4 Days to add and 3 skipped.
     - Importing into empty data adds everything.

3. [x] **Slice: refusing invalid Nights and Days.**
   - What it builds: `BackupFile.refusal(_:now:) -> BackupFileError?`. It returns
     `invalidEntry` with a reason for each of these:
     - Final Wake before Sleep Onset.
     - Two Nights with one date.
     - Two Days with one date.
     - A Heart Rate Trace that doesn't fit its Night's Time in Bed: its start isn't the Time in
       Bed start, or its step count isn't Time in Bed ÷ 5 min rounded up, as
       `HeartRateTrace.init(from:to:of:)` builds it.
     - A Wake Bout outside Sleep Onset to Final Wake.
     - Any Body refusal, taken from `BodyDataFile.refusal`.
   - Spec fix (the user agreed this one): the same task rewrites the spec's trace criterion and
     its matching Behavior bullet to "a Heart Rate Trace that doesn't fit its Night's Time in
     Bed".
   - Seam: Backup file.
   - Files: `BackupFile.swift`, `BackupFileTests.swift`, `specs/020-backup.md` (that wording
     only).
   - Done when: every refusal case in the spec's error criterion returns its typed error,
     including a Food Entry over 5,000 kcal, and a valid file returns nil.

4. [x] **Slice: rebuild queues spare restored dates.**
   - Blocked by: none. This touches different files from 1–3.
   - What it builds:
     - A `sparing restored: Set<Day> = []` parameter on `nightRebuilds(after:)`,
       `traceRebuilds(for:)`, `dayRebuilds(after:)`, `dayRebuilds(missingValuesIn:)` and
       `dayRebuildsDue`.
     - A helper that removes restored dates from a pending `[NightRebuild]` or `[DayRebuild]`
       queue.
   - Seam: Rebuild queues.
   - Files:
     - `src/SerenixCore/NightRebuild.swift`
     - `src/SerenixCore/DayRebuild.swift`
     - `tests/SerenixCoreTests/NightRebuildTests.swift`
     - `tests/SerenixCoreTests/DayRebuildTests.swift`
   - Done when these spec criteria pass:
     - A sync touching restored D's window queues no rebuild for D but still queues the other
       date.
     - The trace rebuild never queues a restored Night.
     - The missing-values rebuild and the Profile-change rebuild never queue a restored Day.
     - The helper drops restored dates from a queue.

5. [x] **Slice: automatic Backup decisions.**
   - Blocked by: 1 (uses `Backup` and `BackupFileError`).
   - What it builds, in a new `AutomaticBackup` with pure functions:
     - `isWriteDue(after:)` over the events "turned on", "rebuild pass" (Nights and Days before
       and after) and "Body changed". A write is due when the Nights or Days differ, after a
       Body change, and after turning it on.
     - `onTurningOn(found:)`. It takes no Backup found, a decoded `Backup`, or a
       `BackupFileError`, and returns `.write`, `.offerImport(Backup)` or `.offerReplace(reason)`.
     - `status(lastWrite:lastError:)`. It returns "Last backup: <time>" or "Backup failed:
       <reason>", with the latest outcome winning.
   - Seam: Automatic Backup decisions.
   - Files:
     - `src/SerenixCore/AutomaticBackup.swift` (new)
     - `tests/SerenixCoreTests/AutomaticBackupTests.swift` (new)
   - Done when: the spec's three automatic-Backup criteria pass.

6. [x] **Shell: manual Backup, export and import, with restored Nights and Days.**
   - Blocked by: 2, 3, 4.
   - What it changes:
     - `BodyBackup` becomes a `Backup` `Transferable` named "Serenix Backup.json".
     - The Profile menu's "Body data" section becomes "Backup", with "Export backup" and "Import
       backup". The prompt reads "Add N Nights, M Days and K Body entries? J already here will be
       skipped.", and there are refusal alerts.
     - `StoredNight` and `StoredDayLoad` gain an optional `restored: Bool?`.
     - New `NightStore` and `DayLoadStore` methods insert the imported rows marked restored, and
       return the restored dates.
     - `apply` skips a row that is restored.
     - `StrapConnection` passes the restored dates into every queue call. After an import it
       drops them from both pending queues, chained on `nightsRebuild`.
     - Body is saved as today: `foodStore.add`, then `bodyStore.add`.
     - Update `docs/architecture.md` for the Data model, the Persistence row and the Backup.
   - Seam: none in core (ADR 0002). Checked by hand, with steps written into the PR.
   - Files:
     - `src/SerenixApp/BodyBackup.swift`, renamed or replaced by `Backup` Transferable
     - `src/SerenixApp/ProfileMenu.swift`
     - `src/SerenixApp/NightStore.swift`
     - `src/SerenixApp/DayLoadStore.swift`
     - `src/SerenixApp/StrapConnection.swift`
     - `docs/architecture.md`
   - Done when: `swift build` and lint are clean. The phone checks are carried to the PR
     checklist: export and import on a fresh install, and restored Nights unchanged after a
     sync.

7. [x] **Shell: automatic Backup.**
   - Blocked by: 5, 6.
   - What it adds to the Backup section:
     - A toggle with a folder picker. A security-scoped bookmark is kept in UserDefaults.
     - On turning it on, read any existing `Serenix Backup.json` through `BackupFile.decode`
       and follow `AutomaticBackup.onTurningOn`: write, offer import, or offer replace. Cancel
       turns it back off.
     - A coordinated, atomic write (`NSFileCoordinator` with `.atomic`) on a background task.
     - Hooks that ask `AutomaticBackup.isWriteDue`:
       - at the end of `StrapConnection.rebuildNights()`, with its before and after reads;
       - after a successful save in the private `change` of `BodyStore` (:214) and
         `FoodStore` (:278);
       - on turning it on.
     - The last write's outcome kept in UserDefaults as one `BackupOutcome` (task 5 built
       `AutomaticBackup.status(after:in:)` on a single outcome, so the latest always wins), and
       the status line under the toggle.
     - The rebuild-pass hook passes its before and after reads oldest first, as the stores
       return them: `isWriteDue` compares the arrays in order.
     - A failed write never blocks a sync or a save.
   - Seam: Automatic Backup decisions, via task 5. The shell itself is checked by hand.
   - Files:
     - `src/SerenixApp/ProfileMenu.swift`
     - `src/SerenixApp/AutomaticBackupWriter.swift` (new)
     - `src/SerenixApp/StrapConnection.swift`
     - `src/SerenixApp/BodyStore.swift`
     - `src/SerenixApp/FoodStore.swift`
   - Done when: `swift build` and lint are clean. The phone checks are carried to the PR
     checklist: the iCloud folder updated after a sync and a Weigh-in, the reinstall offer,
     the failed-folder status, and the bookmark surviving a relaunch (the spec's open question).

8. [x] **Verify:** full suite, lint and typecheck green, and every `SerenixCore` success
   criterion in spec 020 ticked.
   - Blocked by: 7.
   - The macOS CI build and the phone checks for tasks 6 and 7 are carried to the PR checklist.

## Verification
- `swift test`. All new tests are in `BackupFileTests`, `NightRebuildTests`, `DayRebuildTests`
  and `AutomaticBackupTests`. The existing `BodyDataFileTests` stay unchanged.
- `swift format lint --strict --recursive src tests Package.swift`
- `swift build`
- Phone (PR checklist): export, delete the app, reinstall, Onboarding, then import. Nights, Days
  and Body data come back, a sync leaves them unchanged, the automatic Backup reinstall offer
  appears, and a failed folder shows its status.

## Done when
- All tasks are checked, every success criterion in the spec is met, and the suite is green.
