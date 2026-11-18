# ADR-0007 — Custom login page with Keycloakify

**Status:** Accepted · **Date:** 2026-11-18

## Context
The login page is the first screen users see and must share the app's design language and runtime branding. Options: FreeMarker theme extending `keycloak.v2` with CSS overrides; Keycloakify (React/Vite → theme JAR).

## Decision
- **Keycloakify** in `keycloak-theme/` (pnpm workspace), reusing `packages/brand` tokens and fonts. Only the pages needed: `login.ftl`, `login-reset-password` (disabled unless enabled), `error.ftl`, `info.ftl`, `logout-confirm.ftl`, `login-page-expired.ftl`. Account console stays default (not exposed in the app).
- Branding at runtime through Keycloakify `environmentVariables` (`VARCO_BRAND_*`) and logo from `/branding/logo.svg`.
- The JAR is built in the Keycloak image (`infra/keycloak/Dockerfile`, multi-stage: node → jar → `kc.sh build`).
- **Fallback rule:** if Keycloakify does not support the pinned Keycloak version, implement a FreeMarker theme extending `keycloak.v2` with the same tokens; record in PR.

## Consequences
+ Consistent, modern login; same Italian copy and tokens.
− Another build artefact and Node toolchain in the Keycloak image build.
