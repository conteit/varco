# ADR-0005 — REST + OpenAPI, contract-first (not GraphQL)

**Status:** Accepted · **Date:** 2026-11-18

## Context
Owner asked: REST or GraphQL? The domain is small: a handful of resources, a few commands (enter/exit/undo/correct), and three aggregate read views (me, office live, logs). One client (the SPA). Authorization is per office and per operation. Parallel agents need a stable contract to build backend and frontend independently.

## Decision
**REST with an OpenAPI 3.1 contract, contract-first** (`api/openapi.yaml`, written in the foundation phase).
- Commands are explicit endpoints (`POST /me/presence/events`, `POST /offices/{id}/corrections`), not generic PATCHes.
- Aggregate screens get dedicated read endpoints (`/me`, `/offices/{id}/live`) — that removes the over/under-fetching argument for GraphQL.
- Frontend types generated with `openapi-typescript`; backend responses validated against the contract in integration tests.
- Errors: RFC 9457 Problem Details + stable `code`.

## Why not GraphQL
- Its strengths (many heterogeneous clients, flexible graph traversal) don't apply; costs do: per-field authorization, N+1/dataloader plumbing, query cost limiting, harder HTTP-level caching, CSV download doesn't fit, more surface for agents to get subtly wrong.
- Spring Security method-level rules map 1:1 to REST operations and are easy to test exhaustively (AC-70 security matrix).
- OpenAPI codegen gives the end-to-end typing benefit usually attributed to GraphQL.

## Consequences
+ Frontend and backend tasks proceed in parallel against the same contract.
+ Contract drift is caught in CI.
− Contract changes must go through a dedicated PR (see AGENTS.md § Contract).
