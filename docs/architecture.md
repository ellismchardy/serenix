# Architecture

Deep reference for how the system is put together. CLAUDE.md links here so it can stay lean.

## Overview
<High-level description of the system. A diagram or bullet map of the major pieces.>

## Components
| Component | Responsibility | Location |
|-----------|----------------|----------|
| <e.g. API layer> | <what it does> | `src/api/` |
| <e.g. Domain/core> | <what it does> | `src/core/` |
| <e.g. Data access> | <what it does> | `src/db/` |

## Data model
<Key entities and their relationships.>

## External dependencies
<Third-party services, APIs, queues, etc., and why each is here.>

## Cross-cutting concerns
- Auth: <approach>
- Errors: <strategy>
- Logging/observability: <approach>
- Config/secrets: <where they live, how loaded>
