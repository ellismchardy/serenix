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

**Update 2026-11-04:** the macOS job runs on `macos-26` with Xcode 26.6 pinned, building
against the iOS 26 SDK so the app gets the iOS 26 tab bar and controls (spec 012). It built with
Xcode 16.4 and the iOS 18.5 SDK before. The deployment target stays iOS 17. Moving to a newer
Xcode is a deliberate change to the pin, checked on the phone.
