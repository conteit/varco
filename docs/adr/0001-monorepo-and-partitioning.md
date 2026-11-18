# ADR-0001 — Monorepo partitioned for parallel agents

**Status:** Accepted · **Date:** 2026-11-18

## Context
Implementation is done by autonomous agents running in parallel (one issue → one sandbox → one branch). Git isolation does not prevent semantic collisions; the repo layout must make disjoint work the default.

## Decision
- Single monorepo: `backend/`, `frontend/`, `packages/brand/`, `keycloak-theme/`, `infra/`, `e2e/`, `api/`, `docs/`.
- Backend modules = Spring Modulith modules (`identity`, `office`, `presence`, `planning`, `audit`) + open `shared`. Frontend features = `src/features/<feature>/` each with its own routes, messages and tests.
- **Foundation tasks own shared files** (router registry, nav, `shared/` security, baseline migration, OpenAPI contract, `ui/` components). Feature tasks may only touch their own paths plus explicitly listed extension points.
- Pre-registration: foundation tasks create empty stubs for every feature (route placeholder, module package, message catalog file, migration range) so feature agents fill rather than wire.
- Flyway version ranges per module (ARCHITECTURE § 4.1).

## Consequences
+ Phase-1 tasks can run 3–5 in parallel with near-zero conflicts.
+ Spring Modulith `verify()` mechanically enforces backend boundaries.
− Foundation phase is sequential and must be reviewed carefully: its mistakes propagate.
