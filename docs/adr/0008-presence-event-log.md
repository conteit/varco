# ADR-0008 — Presence as append-only events + current-state projection

**Status:** Accepted · **Date:** 2026-11-18

## Context
Admins need a trustworthy audit trail of entries/exits; the live view needs fast "who is in now" counts; users make mistakes (double taps, forgotten exits); phones go offline.

## Decision
- `presence_event` is **append-only**. Mistakes are fixed by **voiding** (`voided_at`) or by **correction events** (source `CORRECTION`) — never UPDATE of business fields, never DELETE (except retention purge).
- `current_presence` is a projection updated **in the same transaction** as event insertion, under a per-user row lock. A consistency check (`make check` integration test + optional admin endpoint later) rebuilds it from events and compares.
- Visits are paired via `pair_id` (set on EXIT to the ENTER's id) to make corrections and history simple.
- Offline: client generates `clientEventId` + `occurredAt`; server enforces idempotency and time window (BR-13/14).
- Not full event sourcing: other aggregates (offices, users) are plain CRUD with audit entries.

## Consequences
+ Clear audit semantics, simple live queries, safe retries.
− Corrections are more complex than editing a row (three explicit correction kinds, BR-17).
