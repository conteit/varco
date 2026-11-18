# ADR-0011 — Test LDAP directories

**Status:** Accepted · **Date:** 2026-11-18

## Context
Production LDAP servers are provided by the customer. Dev/test/E2E need two independent directories to prove multi-directory federation. Bitnami's free OpenLDAP images were discontinued in 2025; `osixia/openldap` has been frozen since 2021 (OpenLDAP 2.4, EOL). The owner develops on Apple Silicon → images must be multi-arch.

## Decision
- Two OpenLDAP 2.6 containers (`ldap-a`, `ldap-b`) with different base DNs, seeded from LDIF in `infra/ldap/`.
- Image: **`vegardit/openldap`** (actively maintained, OpenLDAP 2.6) — T01 must verify a `linux/arm64` manifest exists. Fallback: Symas' OpenLDAP container (amd64 + arm64). Pin by tag **and** digest.
- Test data is public and labelled as such (ARCHITECTURE § 7). Plain LDAP inside the compose network for dev; production expects LDAPS/StartTLS with a corporate truststore.
- Never shipped in `compose.prod.yaml`.

## Consequences
+ Realistic federation tests, including a user only in directory B.
− Two extra containers in the dev stack (~50 MB each).
