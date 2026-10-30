# 0001 — On-device only, no backend

**Date:** 2026-10-30
**Status:** accepted

All sync, storage and computation happen on the user's iPhone, and there are no accounts or
server. This keeps health data on the phone, costs nothing to run, keeps the GDPR/breach
surface at zero, and gives WHOOP no service of ours to target. In exchange, algorithm changes
ship as app updates and there is no web or cross-device access. Backup comes from the Apple
Health export, and iCloud sync is a possible later addition.
