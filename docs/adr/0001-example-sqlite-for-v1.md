# 0001 — Example: SQLite for v1 instead of Postgres

**Date:** 2026-01-01
**Status:** accepted

Single-tenant app at an early stage; we want zero infra overhead to ship fast, so v1 uses SQLite.
Postgres was rejected for now (more scalable, but adds hosting + ops cost we don't need yet).
We accept that a migration path to Postgres is needed before going multi-tenant.

> Worked example — delete it once your first real ADR exists.
