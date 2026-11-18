# ADR-0003 — Single origin through a Caddy edge

**Status:** Accepted · **Date:** 2026-11-18

## Context
SPA, API and Keycloak on separate origins would need CORS, would make Keycloak's SSO cookie third-party from the app's perspective, and installed iOS PWAs open out-of-scope origins in an overlay browser with separate cookie jars, breaking login persistence.

## Decision
One public origin served by **Caddy**: `/` SPA static files, `/api/*` → backend, `/auth/*` → Keycloak (`KC_HTTP_RELATIVE_PATH=/auth`, `KC_HOSTNAME=${VARCO_PUBLIC_URL}/auth`, `KC_PROXY_HEADERS=xforwarded`). Caddy also renders runtime branding (`templates`), sets security headers and terminates TLS (`tls internal` in dev, ACME in prod). Keycloak admin console (`/auth/admin`) is blocked at the edge in prod unless `VARCO_EXPOSE_KC_ADMIN=true`.

## Consequences
+ No CORS, first-party cookies, PWA scope covers login.
+ One TLS cert, one place for headers.
− CSP must accommodate Keycloak pages under the same origin: set CSP per path (`/auth/*` keeps Keycloak's own headers; SPA paths get the strict app CSP).
