# ADR-0002 — SPA as OIDC public client (Auth Code + PKCE), tokens in memory

**Status:** Accepted (owner decision) · **Date:** 2026-11-18

## Context
Options: (a) SPA public client exchanging the authorization code itself; (b) Backend-for-Frontend / token relay with server session (the IETF *OAuth 2.0 for Browser-Based Apps* BCP rates BFF as the most secure pattern). The owner requires (a): the code is delivered to and redeemed by the frontend; no token relay, no server sessions. The backend stays a stateless resource server.

## Decision
- `oidc-client-ts` + `react-oidc-context`, Authorization Code + **PKCE S256**, client `varco-spa` public, standard flow only (no implicit, no direct grants).
- Tokens **in memory only** (`InMemoryWebStorage`); nothing in local/session storage or IndexedDB.
- Session continuity via Keycloak SSO cookie: top-level `prompt=none` redirect on load; *Ricordami* for long-lived SSO on phones. No iframe silent renew (third-party-cookie and iOS PWA issues are avoided anyway by same-origin, ADR-0003, but redirects are simpler and deterministic).
- Short access tokens (5 min), refresh-token rotation.
- XSS is the main residual risk → strict CSP without `unsafe-inline` scripts, no `dangerouslySetInnerHTML`, Trusted Types where supported, dependency scanning.

## Consequences
+ Stateless backend, simple horizontal scaling, matches owner's architecture.
+ Same-origin Keycloak keeps cookies first-party.
− Tokens are reachable by injected script for their lifetime → mitigated by CSP + short TTL.
− Each cold start of the PWA performs a quick redirect round-trip (≈ 300–600 ms); acceptable, masked with a branded splash.
- Future hardening (not v1): DPoP-bound tokens (Keycloak supports DPoP) to make stolen tokens unusable.
