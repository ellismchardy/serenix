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
| Sleep | Find the Sleep Period, Sleep Onset, Final Wake and Time in Bed from History Records | `src/SerenixCore/` |
| Metrics & scores | Nightly Metrics, Baseline, Sleep Score, Readiness, Load | `src/SerenixCore/` |
| BLE transport | CoreBluetooth: scan, connect, pair, write and notify. Hands raw bytes to the sync logic | `src/<iOS app — set in /scaffold>/` |
| Persistence | SwiftData store for raw History Records (30 days) and Nights, metrics and scores (kept forever) | `src/<iOS app>/` |
| Health export | Writes Resting HR, HRV, SpO2, respiratory rate and sleep to Apple Health | `src/<iOS app>/` |
| UI | SwiftUI screens | `src/<iOS app>/` |

## Data model
- **History Record**: one per second from the Strap, keyed by the Strap's record counter, with
  a UTC timestamp. Kept for 30 days, then pruned.
- **Night**: one Sleep Period, dated by the local date of its Final Wake. It holds Sleep Onset,
  Final Wake, Time in Bed, Nightly Metrics, Sleep Score and Readiness. Kept forever.
- **Day**: a local calendar day with its Load. Kept forever.
- **Baseline**: derived from the last 14 Nights, not stored. Readiness is "calibrating" until
  4 Nights exist.
- **Sync Cursor**: the last History Record the phone acknowledged to the Strap, so each sync only gets
  newer records.

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
background sync, iCloud sync, and the Whoop 4.0 and MG.

## Cross-cutting concerns
- Auth: none. No accounts. The only "auth" is BLE pairing with the Strap, which encrypts the
  link the Whoop service needs.
- Errors: `SerenixCore` returns typed errors and never crashes on malformed frames: a bad CRC
  or unknown record type is reported and skipped. The shell shows sync failures to the user.
- Logging/observability: `os.Logger` on the device only. No analytics or telemetry, so
  health data never leaves the phone (ADR 0001).
- Config/secrets: none at runtime. Signing for TestFlight or the App Store needs the Apple
  Developer Program; until then there are no secrets.
- Sync: foreground only. History Sync runs when the app opens (ADR 0004).
- Privacy: test fixtures are the owner's real nights, published in this public repo by choice;
  rules in `docs/conventions.md` (Testing).
