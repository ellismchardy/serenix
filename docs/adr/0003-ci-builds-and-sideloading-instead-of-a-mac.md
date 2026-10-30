# 0003 — GitHub Actions macOS builds and Sideloadly instead of a Mac

**Date:** 2026-10-30
**Status:** accepted

The iOS app is built only by a GitHub Actions macOS runner (free and unlimited on this public
repo). It produces an unsigned `.ipa` that the developer signs with a free Apple ID and
installs from Windows with Sideloadly. A rented cloud Mac (about $25/month) and buying a Mac
were rejected to keep costs at zero.

**Consequences:** no Simulator and no Xcode UI. Free-signed installs expire every 7 days. The
App Store and TestFlight need the $99/year Apple Developer Program. Whether free signing keeps
the HealthKit entitlement is unverified.
