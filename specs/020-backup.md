# 020 — Backup

**Status:** built
**Last updated:** 2026-11-19 (built; phone checks in the PR)

## Problem
Deleting a sideloaded build loses every Night and Day it held, for good. Free-signed builds expire
every 7 days (ADR 0003), so deleting one is routine, and the owner has already lost their Nights
this way. Three things combine:
- The SwiftData store goes with the app.
- The Strap never resends History Records once their Batch is acknowledged (Sync Cursor).
- There is no Apple Health export yet. Health is write-only in any case, so it could never
  restore anything into Serenix.

Body data already has a JSON export (spec 015), but only by hand, and nothing else is backed up.

## Goal
The user's Nights, Days and Body data survive deleting the app. A Backup file lives outside
Serenix, and Serenix can keep it up to date on its own, and a fresh install gets everything back
from it.

## User stories
1. As a user, I want to export a Backup by hand and import it on a fresh install, so that
   deleting a build loses nothing.
2. As a user, I want Serenix to keep a Backup in a folder I chose, up to date after every sync
   and every Body data change, so that I'm covered even when I forget.
3. As a user who has just reinstalled, I want turning the automatic Backup back on to offer my
   old Backup for import first, never overwrite it with an empty one.
4. As a user, I want restored Nights and Days to stay exactly as they were, even though the
   phone no longer holds the History Records behind them.
5. As a user importing into a phone that already has some Nights, I want the phone's own copy
   kept and the file's copy of that date skipped, and to be told how many were added and skipped.
6. As a user, I want my older Body data backup files (version 1 and 2) to still import.
7. As a user, I want a broken or foreign file to import nothing and tell me why.
8. As a user whose automatic Backup can't be written, I want to see that it failed and why,
   without my syncs or Body saves being blocked.

## Behavior

### What a Backup holds
- **Every stored Night**, with all it holds: Sleep Onset, Final Wake, Time in Bed, Time Asleep,
  the five Nightly Metrics (each may be missing), its Heart Rate Trace and its Wake Bouts (each
  may be missing).
- **Every stored Day**: its Resting HR, its Load, or the reason Load is missing, its HR Zones
  hour by hour, Highest HR and the Max HR used.
- **All Body data**, exactly as the Body data file holds it today (specs 015–017): Weigh-ins,
  Weight Goals, Food Entries, Complete Days and food targets.
- **Not** History Records (about 86,400 a Day, far too large, and the Strap never resends them
  anyway), **not** the Sync Log, **not** the Profile (Onboarding asks for it again on a fresh
  install).
- Sleep Score, Readiness, Baseline, Sleep Need and Sleep Debt aren't stored, so they aren't in
  the Backup either. They are worked out again from the restored Nights and Days.

### Format
- One JSON file with the format `serenix-backup` and version 3. It replaces the Body data file
  (`serenix-body`, versions 1 and 2), which Serenix still imports but no longer writes.

### Export and import by hand
- The Profile menu's "Body data" section becomes **"Backup"**. "Export backup" shares a Backup
  through the share sheet, and "Import backup" picks one with the file picker.
- Import asks first, with counts: "Add N Nights, M Days and K Body entries? J already here will
  be skipped." Body entries are counted and matched as spec 015–017 count and match them.
- **Date clash.** A Night or Day in the file whose date already has a Night or Day on the phone
  is skipped: the phone's copy wins.
- **All or nothing.** If the file can't be read or has the wrong format, or if any Night or Day
  in it is invalid, nothing is imported and Serenix says why. Invalid means any of:
  - Final Wake before Sleep Onset.
  - Two Nights, or two Days, with the same date.
  - A Heart Rate Trace that doesn't fit its Night's Time in Bed (5-minute steps from Time in
    Bed start to Time in Bed end).
  - A Wake Bout outside its Night's Sleep Period.
  - A Body entry that spec 015–017 refuses.
  A file from a newer version is refused with "made by a newer Serenix".
- A version 1 or 2 Body data file imports its Body data as before, with no Nights or Days.

### Restored Nights and Days
- A Night or Day added by an import is **restored**. The phone remembers this.
- No rebuild ever replaces or deletes a restored Night or Day. This covers the rebuild after a
  sync, the rebuild of Nights missing a Heart Rate Trace, the rebuild of Days missing their
  values, and the rebuild of every Day after a Profile change. A restored Day keeps the Load
  worked out with the Max HR in force when it was first built.
- Restored Nights and Days count like any other in every score, Baseline and screen.
- A restored Night or Day exported again goes into the Backup like any other.

### Automatic Backup
- Off until the user turns it on in the Backup section and picks a folder (for example in
  iCloud Drive or On My iPhone). Serenix keeps access to that folder across launches.
- It writes one file, `Serenix Backup.json`, in that folder, replacing it each time. Each write
  goes to a temporary file first and is then swapped in, so an interrupted write leaves the
  previous Backup whole.
- **When it writes:**
  - Right after it is turned on.
  - After each History Sync that adds or changes a Night or Day.
  - After each save, edit or delete of Body data.
  There is no timer and no background work beyond the sync already running (ADR 0006).
- **A folder that already holds a Backup.** When turned on, if the chosen folder already holds
  `Serenix Backup.json`, Serenix reads it and offers the import prompt above. It writes only
  after the user imports, or after they choose "Replace it". Cancelling leaves the automatic
  Backup off and the file untouched. If that file can't be read, Serenix says why and offers
  only "Replace it" or Cancel.
- **Status.** Under the toggle the menu shows "Last backup: <date and time>". After a failed
  write it shows "Backup failed: <reason>" instead, for example when the folder is gone, access
  is lost or iCloud is unavailable. The setting stays on and the next trigger tries again. A
  failed write never blocks or fails a History Sync or a Body save, and shows no pop-up.
- The user can turn it off. The file stays where it is.

### Privacy
- A Backup holds health data. It goes only where the user puts it: the share sheet or the folder
  they picked. Serenix never sends it anywhere (ADR 0001).
- Backup contents are never written to the Sync Log, `os.Logger` or bug reports.

## Design decisions
- **`SerenixCore`: Backup file (new, replaces the Body data file).**
  - Encodes Nights, Days and Body data as versioned JSON (`format: serenix-backup`,
    `version: 3`) and decodes it.
  - Decodes `serenix-body` versions 1 and 2 as Body data only.
  - Given the phone's current Nights, Days and Body data and a decoded file, returns what an
    import would add and skip.
  - Errors are typed (unreadable, wrong format, newer version, invalid entry with its reason).
    Nothing partial is returned.
  - The Body rules move over unchanged from the Body data file.
- **`SerenixCore`: Night** becomes encodable for the Backup, with its Heart Rate Trace and Wake
  Bouts. A Day's Resting HR and Load (`DayLoad`) already are.
- **`SerenixCore`: rebuild queues.** The functions that choose which Nights and Days to rebuild
  (after a sync, for Nights missing a Heart Rate Trace, for Days missing values, for every Day
  after a Profile change) take the set of restored dates and never queue one of them.
- **`SerenixCore`: automatic Backup decisions.** Pure functions:
  - Whether an event should trigger a write: a sync that changed Nights or Days, a Body change,
    turning it on.
  - What turning it on with a given folder should do: write, or offer import/replace when the
    folder holds a readable or unreadable Backup.
  - The status line to show from the last write's time or error.
- **Shell.**
  - The Profile menu's Backup section, with Export, Import, the automatic Backup toggle, the
    folder picker and the status line.
  - A security-scoped bookmark for the chosen folder.
  - The temporary-file-and-swap write.
  - A `restored` mark on stored Nights and Days. It is optional, so existing stores open
    unchanged.
  - Saving imported Nights and Days into the main store, and Body data into the Body and Food
    stores as today.
  - The shell moves bytes and decides nothing.
- Follows ADR 0001 (no server: the file is the user's), ADR 0002 (logic in `SerenixCore`) and
  ADR 0008 (Body data stays in its own store). ADR 0009 records the Backup and why restored
  Nights and Days are never rebuilt.

## Seams under test
- **Backup file (`SerenixCore`)**, fed hand-built Nights, Days and Body data. It catches:
  - A lossless round trip.
  - Add and skip counts with the phone-wins date rule.
  - The invalid-entry and unreadable cases.
  - Newer-version refusal.
  - Reading version 1 and 2 Body files.
  It misses the share sheet, the file picker and the stores.
- **Rebuild queues (`SerenixCore`)**, the existing public functions, given restored dates. It
  catches that no rebuild path queues a restored Night or Day while others are still queued. It
  misses the store's apply step, which is checked by hand.
- **Automatic Backup decisions (`SerenixCore`)**. It catches when a write is due, the
  existing-Backup offer, and the status text. It misses bookmarks, iCloud and the file write,
  which are checked by hand on the phone (ADR 0002).

## Success criteria (must be checkable)
Backup file
- [x] Encoding then decoding Nights (with and without a Heart Rate Trace, Wake Bouts and each
      Nightly Metric), Days (with Load, and with a missing reason) and Body data gives back equal
      values.
- [x] The encoded file has `format` `serenix-backup` and `version` 3.
- [x] Importing a file of 5 Nights and 5 Days into a phone holding 2 of those Night dates and 1
      of those Day dates reports 3 Nights and 4 Days to add, 3 skipped, and adds only those.
      The phone's copies are unchanged.
- [x] Importing into empty data adds every Night, Day and Body entry in the file.
- [x] Each of these imports nothing and returns its typed error:
  - A truncated file.
  - A file of another format.
  - A version 4 file.
  - A Night whose Final Wake is before its Sleep Onset.
  - Two Nights with one date.
  - Two Days with one date.
  - A Heart Rate Trace that doesn't fit its Night's Time in Bed.
  - A Wake Bout outside its Sleep Period.
  - A Food Entry over 5,000 kcal.
- [x] A `serenix-body` version 1 file and a version 2 file each import their Body data with
      0 Nights and 0 Days.
- [x] The existing Body data file tests pass unchanged against the Backup file.

Restored Nights and Days
- [x] With a restored Night dated D, a sync whose History Records touch D's Night window queues
      no rebuild for D but still queues the other date of that window.
- [x] A restored Night without a Heart Rate Trace is never queued by the trace rebuild.
- [x] A restored Day is never queued by the missing-values rebuild or by the Profile-change
      rebuild of every Day.

Automatic Backup
- [x] A write is due after turning it on, after a sync that added or changed a Night or Day,
      and after a Body change. None is due after a sync that changed nothing.
- [x] Turning it on with a folder holding a readable Backup returns "offer import"; with an
      unreadable one, "offer replace"; with none, "write".
- [x] The status reads "Last backup: <time>" after a write and "Backup failed: <reason>"
      after a failure, until the next write succeeds.

Shell (checked by hand on the phone, steps in the PR)
- [ ] Export backup shares a file. On a fresh install, after Onboarding, Import backup restores
      every Night, Day and Body entry. The Sleep tab, Today, scores and Body tab show them.
- [ ] After the import and a History Sync, every restored Night and Day is unchanged.
- [ ] With the automatic Backup on and an iCloud Drive folder chosen, `Serenix Backup.json` is
      updated after a sync and after a Weigh-in. "Last backup" shows that time.
- [ ] After deleting the app, reinstalling, finishing Onboarding and turning the automatic Backup
      on with the same folder, Serenix offers to import the existing Backup. Cancelling leaves the
      file unchanged.
- [ ] Moving or deleting the chosen folder shows "Backup failed: <reason>". Syncs and Body
      saves still work.
- [ ] `swift test` passes and `swift format lint --strict` is clean. The macOS CI job builds.

## Non-goals (explicitly out of scope)
- Backing up History Records, the Sync Log or the Profile.
- Restoring during Onboarding (spec 014 unchanged).
- The Apple Health export (its own spec, later). It isn't a backup: Health is write-only.
- iCloud sync of the stores, or any server (ADR 0001).
- Several dated Backups or a version history in the folder.
- Encrypting the Backup file.
- Merging a restored Night with a phone-built one of the same date. The phone's copy wins.
- Rebuilding a restored Night if its History Records ever become available again.

## Open questions
- **Free signing and folder access.** Assumption: a security-scoped bookmark to a user-picked
  folder works in a free-signed sideloaded build and survives relaunches. If it doesn't, the
  automatic Backup asks for the folder again on launch. This is checked on the phone in the
  first shell task.
- **Restoring the same Backup twice.** Every Night and Day in it is then skipped by the date
  rule. Assumption: fine.

## Notes
- Builds on spec 015's "Backup and import", which specs 016 and 017 extend.
- ADRs: 0009 (this Backup), 0001 (on-device only), 0003 (sideloading, 7-day expiry), 0006
  (sync finishes in the background), 0008 (Body store).
- Rebuild paths: spec 001 (sync), spec 005 (Profile change), spec 007 (Days missing values),
  spec 012 (Nights missing a Heart Rate Trace).
