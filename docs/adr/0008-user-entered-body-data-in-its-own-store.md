# 0008 — User-entered Body data lives in its own store, kept forever, raw

**Date:** 2026-11-04
**Status:** accepted

Everything Serenix stored until now comes from the Strap and can be rebuilt from History Records.
What the user types on the Body tab (Weigh-ins, Intake, Complete Days, Check-ins, BP Readings, and
Weight Goals both current and ended) can't be rebuilt. So it lives in a **SwiftData store file of
its own**, apart from History Records and Nights. It is **kept forever**, any single entry can be edited or deleted, and
it is stored **raw**: each entry with its time, never Trend Weight, Weekly Rate, Expenditure, BP
Category or Habit Links. Those are worked out each time they're shown, as Sleep Score and
Readiness are. Values are stored in metric units, and the Profile's unit choice applies only on
screen. Body weight isn't kept in the Profile: Trend Weight (or the latest Weigh-in) stands in for
it.

**Considered options:** adding the Body models to the existing container (one store, but opening a
build without those models makes SwiftData drop their tables: this happened to the Heart Rate
Trace columns on 2026-11-04, and for typed-in data the loss would be permanent); storing daily
totals or derived values (smaller, but every formula fix would need a backfill, and totals can't be
edited per entry); keeping body weight in the Profile (one number, but it goes stale between
Weigh-ins).

**Consequences:** the shell opens two model containers. Older builds can't harm Body data, but a
deleted sideload still loses it, so the first Body spec ships a JSON export and import of all Body
data. Body data is never written to the Sync Log, `os.Logger` or bug reports. Apple Health is
write-only for it, once the Health export exists; reading weigh-ins from Health would need its own
decision. The Profile gains an optional Height and a unit choice (kg, lb, or st and lb).
