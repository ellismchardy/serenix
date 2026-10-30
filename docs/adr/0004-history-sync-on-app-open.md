# 0004 — History Sync on app open instead of a continuous connection

**Date:** 2026-10-30
**Status:** accepted

The Strap stores per-second History Records, so Serenix pulls them in a History Sync when the
app comes to the foreground, rather than holding a live BLE connection. iOS throttles
background BLE, and a constant link drains both batteries.

**Consequences:** data appears only after the app is opened. If the Strap's storage fills
before a sync, the oldest records are lost; its capacity is still to be measured. Background
sync (BLE state restoration) is a possible later improvement.
