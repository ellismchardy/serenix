# Architecture

Deep reference for how the system is put together. CLAUDE.md links here so it can stay lean.

## Overview
Serenix is a single iOS app with no backend. On launch it connects to the user's Strap, runs a
History Sync, and turns the raw History Records into Nights, Nightly Metrics and scores, all on
the phone.

```
Strap ──BLE──▶ iOS shell (CoreBluetooth) ──frames──▶ SerenixCore ──▶ Nights, metrics, scores
                     │                                                     │
                     └──────────── SwiftData (on device) ◀─────────────────┘
                                          │
                                          └──▶ HealthKit (write-only export)
```

The app is split in two (ADR 0002):
- **`SerenixCore`**, a pure Swift package that imports Foundation only. It holds every
  decision worth testing. It builds and tests on Windows, Linux and macOS.
- **The iOS shell**, a thin layer of SwiftUI, CoreBluetooth, SwiftData and HealthKit that moves
  bytes and values between the outside world and `SerenixCore`. It builds only on macOS (CI)
  and is tested by hand on a real phone.

## Components
| Component | Responsibility | Location |
|-----------|----------------|----------|
| Protocol | Build command frames and decode Strap frames (CRC, header check, History Record layout). One decoder per Strap model | `src/SerenixCore/` |
| Sync logic | The History Sync state machine: which commands to send, when to acknowledge, when a sync is complete. Transport-agnostic | `src/SerenixCore/` |
| Live HR link | When Live HR runs and on which connection (in a sync or its own), quiet failures and retries, and the sync pill's phase meanwhile (ADR 0007) | `src/SerenixCore/` |
| Sleep | Find the Sleep Period, Sleep Onset, Final Wake and Time in Bed from History Records | `src/SerenixCore/` |
| Metrics & scores | Nightly Metrics, Baseline, Sleep Need, Sleep Score, Readiness, Resting HR, Load | `src/SerenixCore/` |
| Body | Trend Weight, Weekly Rate, Weight Goals (pace, Milestones, projected dates, hold), and the Body data backup file (spec 015) | `src/SerenixCore/` |
| BLE transport | CoreBluetooth: scan, connect, pair, write and notify. Hands raw bytes to the sync logic | `src/SerenixApp/` |
| Persistence | SwiftData store for raw History Records (30 days) and Nights, metrics and scores (kept forever); a separate SwiftData store for user-entered Body data (kept forever, ADR 0008) | `src/SerenixApp/` |
| Health export | Writes Resting HR (Sleeping HR never as resting heart rate), HRV, SpO2, respiratory rate and sleep to Apple Health | `src/SerenixApp/` |
| UI | SwiftUI screens | `src/SerenixApp/` |

## Data model
- **History Record**: one per second from the Strap, identified by its Record Counter and UTC
  timestamp together (the Strap can reuse a Record Counter after a reboot). Kept for 30 days,
  then pruned.
- **Night**: one Sleep Period, dated by the local date of its Final Wake. It holds Sleep Onset,
  Final Wake, Time in Bed, Time Asleep and Nightly Metrics, and its Heart Rate Trace and Wake
  Bouts (spec 012; none for Nights built from History Records no longer kept). Kept forever.
  Sleep Score and Readiness aren't stored: they're worked out from the Nights (and, for
  Readiness, the Days) each time they're shown (specs 008, 010).
- **Day**: a local calendar day with its Resting HR (spec 007), its Load, and its HR Zones hour
  by hour, Highest HR and Max HR used (spec 006). Kept forever.
- **Baseline**: not stored. Each Nightly Metric's median, and HRV's and respiratory rate's
  Spread (spec 004; Sleeping HR's from spec 008), come from the last 14 Nights; typical
  Load comes from the last 28 Days. Readiness is "calibrating" until 4 Nights exist.
- **Sleep Need and Sleep Debt**: not stored. Worked out from the Nights of the week before and
  the Profile's birth year each time they're shown (spec 009).
- **Weigh-in** and **Weight Goal**: typed in by the user, in kg and UTC, in the Body store; kept
  forever, current and ended goals alike (ADR 0008). Trend Weight, Weekly Rate and everything the
  weight screen shows are worked out from them each time, never stored (spec 015).
- **Sync Cursor**: kept by the Strap, not the phone. The phone echoes it to acknowledge each
  Batch, so each sync only gets newer records.

All scores run 0–100 on Serenix's own scales (ADR 0005). The exact formulas live in each
score's spec.

## External dependencies
- **The Strap (Whoop 5.0, firmware `50.38.x`)**: an undocumented, reverse-engineered BLE
  protocol. Reference: `hr-tracker/docs/protocol.md`. Firmware updates can break it. Unknown
  models or firmware get a warning, and the app still tries. The Whoop 4.0 is unverified; the
  MG is out of scope.
- **HealthKit**: write-only in v1. Reading other devices from Apple Health comes later.
- **GitHub Actions**: a Linux job for lint and `swift test`, and a macOS job that builds the
  unsigned `.ipa` (ADR 0003).
- **Sideloadly** (developer machine only): signs the `.ipa` with a free Apple ID and installs
  it on the phone. Installs expire after 7 days.

## Not in v1
Sleep stages (light, deep, REM), Stress, reading other devices from Apple Health, Fitbit,
starting a sync in the background, iCloud sync, and the Whoop 4.0 and MG.

## Cross-cutting concerns
- Auth: none. No accounts. The only "auth" is BLE pairing with the Strap, which encrypts the
  link the Whoop service needs. A Profile holds the user's name, and optionally their birth year,
  sex, Max HR, height and weight units, on the device only; none of it is ever sent anywhere or included in any log
  or report.
- Errors: `SerenixCore` returns typed errors and never crashes on malformed frames: a bad CRC
  or unknown record type is reported and skipped. The shell shows sync failures to the user.
- Logging/observability: `os.Logger` on the device only. No automatic analytics or
  telemetry (ADR 0001). Bug and crash reports are **user-initiated**: the user chooses to send
  the details (e.g. by email) and sees what is sent. What a report contains is set by its spec.
- Config/secrets: none at runtime. Signing for TestFlight or the App Store needs the Apple
  Developer Program; until then there are no secrets.
- Sync: History Sync starts when the app opens or on "Sync now", and a sync that has started
  finishes in the background (ADR 0006). Between syncs Serenix stays disconnected, except while
  Live HR is on screen (ADR 0007).
- Privacy: test fixtures are the owner's real nights, published in this public repo by choice;
  rules in `docs/conventions.md` (Testing).
