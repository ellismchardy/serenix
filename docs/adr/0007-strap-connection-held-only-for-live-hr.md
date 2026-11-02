# 0007 — A connection is held between syncs only while Live HR is on screen

**Date:** 2026-11-01
**Status:** accepted

ADR 0006 keeps no connection to the Strap between syncs. The Load popup (spec 006) shows Live
HR, which needs one: the Strap only streams heart rate (`0x03 01`, then a `0x28` Frame a second)
to a connected phone. So while today's Load popup is on screen and Serenix is in the
foreground, Serenix connects, turns Live HR on, and on close or leaving the foreground turns it
off (`0x03 00`) and disconnects. During a History Sync, Live HR rides on the sync's connection
and only Live HR is turned off; the sync keeps going per 0006. Opening the popup never starts a
sync.

**Considered options:** waiting for the next sync and showing the last synced heart rate (no
new connection, but up to hours old, so not "live"); holding a connection all the time, as
WHOOP's own app does (Live HR anywhere, but battery on both ends and background reconnects and
state restoration, which 0006 left to its own later spec).

**Consequences:** the shell has a second, short-lived reason to connect, and must not send
history commands on a Live HR connection or disconnect a running sync when the popup closes.
Live HR Frames go in the Sync Log. A held connection, or Live HR outside the popup (widget,
Live Activity), would need a new ADR.
