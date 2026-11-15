# 0006 — History Sync starts on app open and finishes in the background

**Date:** 2026-10-31
**Status:** accepted

ADR 0004 kept History Sync foreground-only. The first phone sync showed that a day's backlog
(~90,000 History Records) takes about 6.5 minutes, and locking the phone mid-sync suspended
Serenix and stalled the sync. So Serenix declares iOS's Bluetooth background mode (central role):
a sync that started in the foreground keeps receiving Frames and acknowledging Batches while
the phone is locked or another app is in front. Syncs still only *start* when the app opens or
the user taps "Sync now", and there is still no connection between syncs.

**Considered options:** keeping the screen awake during a sync (cheap, but the user still has
to leave Serenix open and on screen); starting syncs in the background too, with state
restoration so iOS relaunches Serenix (most convenient, but much more to build and test by
hand, and it changes when data reaches the phone, so it gets its own spec later).

**Consequences:** the shell must cope with Bluetooth events while in the background, and the
10-second "stopped responding" rule has to hold even though timers don't run while iOS keeps
Serenix suspended between events. If iOS ends Serenix mid-sync, the unacknowledged Batch comes
again on the next sync, as after any interruption. App Store review will ask why Serenix uses
background Bluetooth.
