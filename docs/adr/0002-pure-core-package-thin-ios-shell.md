# 0002 — Pure SerenixCore package plus a thin iOS shell

**Date:** 2026-10-30
**Status:** accepted

The developer has no Mac. All logic (protocol decoding, sync state machine, sleep, metrics,
scores) lives in `SerenixCore`, a Swift package that imports Foundation only, so it builds and
tests on Windows. CoreBluetooth, SwiftData, HealthKit and SwiftUI stay in a thin shell that
only moves data in and out. Without this split, nothing could be tested locally.

**Consequences:** anything that needs an Apple framework can't be unit-tested on the dev
machine, so it must stay small. A "simple" bit of logic in the shell is a smell. Move it into
the core.
