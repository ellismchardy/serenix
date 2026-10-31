# Serenix

An iOS wellness tracker that reads a **Whoop 5.0 Strap** directly over Bluetooth, so you can
get sleep, Nightly Metrics, Sleep Score, Readiness and Load from a Strap you own, without a
WHOOP membership.

Everything runs on your phone. There's no backend, no account and no telemetry.

> **Status: early development.** The project skeleton, CI and toolchain are in place; features
> are being specced and built one at a time. Nothing is usable on a phone yet.
>
> Serenix is an independent project and is **not affiliated with, endorsed by, or connected to
> WHOOP, Inc.** It talks to the Strap over an undocumented, reverse-engineered protocol that a
> firmware update could break.

## What it does (v1)

- **History Sync**: when the app opens, it pulls every new History Record (one second of heart
  rate, RR intervals, motion, skin temperature and steps, plus SpO2 during sleep) off the Strap.
- **Sleep**: finds each Night's Sleep Period, Sleep Onset, Final Wake and Time in Bed.
- **Nightly Metrics**: Resting HR, HRV, respiratory rate, skin temperature and SpO2.
- **Scores**: Sleep Score, Readiness (against your own Baseline) and daily Load, each 0–100 on
  Serenix's own scales.
- **Apple Health**: writes Resting HR, HRV, SpO2, respiratory rate and sleep to HealthKit.

Not in v1: sleep stages, Stress, background sync, iCloud sync, reading other devices, and the
Whoop 4.0 and MG. Terms are defined in [GLOSSARY.md](GLOSSARY.md).

## How it's built

- Swift 6, SwiftUI, CoreBluetooth, SwiftData and HealthKit, targeting iOS 17+.
- **`SerenixCore`** is a pure Swift package (Foundation only) that holds every decision worth
  testing: frame decoding, the sync state machine, sleep detection and scoring. It builds and
  tests on Windows, Linux and macOS.
- **`SerenixApp`** is a thin iOS shell that moves bytes and values between the outside world
  and `SerenixCore`, and is checked by hand on a real phone.
- There's no Mac in the loop: GitHub Actions builds an unsigned `.ipa` on macOS, and it's
  sideloaded with Sideloadly.

Protocol research and the Python reference implementation the algorithms are ported from live
in a separate `hr-tracker` repo.

See [docs/architecture.md](docs/architecture.md) for the full picture and
[docs/adr/](docs/adr/) for why it's built this way.

## Getting started

Full setup (Windows toolchain, pre-commit hook, sideloading onto an iPhone) is in
[docs/dev-setup.md](docs/dev-setup.md). Once the toolchain is installed:

```bash
git config core.hooksPath .githooks
swift format lint --strict --recursive src tests Package.swift
swift build
swift test
```

The iOS app is built by CI from `project.yml` (XcodeGen). Download the `Serenix-ipa` artifact
from a CI run and install it with Sideloadly. Free Apple ID installs expire after 7 days.

## Repository layout

```
src/SerenixCore/   pure logic (protocol, sync, sleep, metrics, scores)
src/SerenixApp/    iOS shell (BLE, persistence, Health export, UI)
tests/             Swift Testing suites, mirroring src/
specs/             feature specs, the source of truth for behavior
plans/             disposable execution plans
docs/              architecture, conventions, dev setup, workflows, ADRs
GLOSSARY.md        the project's shared vocabulary
```

## Development process

Serenix is a personal project and isn't open to outside contributions.

Development is spec-driven and test-first: a feature gets a spec in `specs/`, then a plan, then
is built one test-first slice at a time, and every change lands as a squash-merged PR with green
CI. [CLAUDE.md](CLAUDE.md), [docs/conventions.md](docs/conventions.md) and
[docs/workflows.md](docs/workflows.md) describe the process.

Test fixtures are trimmed real History Records from the project owner's own nights, with
identifiers removed. Raw Bluetooth captures and sysdiagnoses are never committed.

## License

[MIT](LICENSE). Some of the Claude Code development tooling in `.claude/` is adapted from
third-party projects; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
