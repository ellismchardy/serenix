# 0009 — Nights and Days are backed up to a user-chosen file, and restored ones are never rebuilt

**Date:** 2026-11-19
**Status:** accepted

Deleting a sideloaded build loses its SwiftData store, and the Strap never resends acknowledged
History Records, so Nights and Days were lost for good (ADR 0001 said "v1 has no backup"). Serenix
now writes one JSON Backup of Nights, Days and Body data: by hand through the share sheet, and
optionally on its own to a folder the user picked, after each sync or Body change (spec 020). A
Night or Day added by an import is marked restored, and no rebuild ever replaces or deletes it.
The phone will never again hold the History Records behind it, so a rebuild could only produce a
worse Night or none, and a missing Night is deleted on rebuild today.

**Considered options:** waiting for the Apple Health export (write-only, so it can't restore, and
it has no place for the Heart Rate Trace, Wake Bouts or Load); iCloud sync of the stores (more
machinery, and the HealthKit/iCloud entitlements under free signing are unverified); backing up
History Records too (about 86,400 a Day, hundreds of MB a month, so rebuilds could run, but far
too large for a file the user moves around); a separate file for Nights beside the Body data
file (two things to remember before deleting a build).

**Consequences:** the Body data file (`serenix-body`) is replaced by the Backup
(`serenix-backup`, version 3), and old files still import. A restored Day keeps the Load worked
out with the Max HR of its time, even after a Profile change. A sleep-algorithm fix never
reaches restored Nights. No server is involved: the file goes only where the user puts it, so
ADR 0001 stands.
