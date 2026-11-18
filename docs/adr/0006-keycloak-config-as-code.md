# ADR-0006 — Keycloak configuration as code (keycloak-config-cli)

**Status:** Accepted · **Date:** 2026-11-18

## Context
Keycloak's `--import-realm` only applies when the realm does not exist, so LDAP endpoints or token settings can't be changed by redeploying. The same realm must work against test OpenLDAP in dev and against the customer's LDAP/AD in production, with 1..N directories.

## Decision
- Pin a Keycloak version (latest 26.x or newer GA at scaffold time) and the **adorsys/keycloak-config-cli** release built for that version; it runs as a one-shot compose service after Keycloak is healthy, idempotently applying YAML from `infra/keycloak/config/` with `${env:VAR}` substitution.
- Files: `00-realm.yaml` (realm, clients, scopes, tokens, theme), `10-ldap-a.yaml`, `11-ldap-b.yaml`, `90-dev-e2e-client.yaml` (dev/test only). `VARCO_LDAP_FILES` / compose overlays choose which files are mounted.
- **Rule for agents:** if no keycloak-config-cli release supports the newest Keycloak, pin Keycloak to the newest version it supports. Record versions in `infra/keycloak/VERSIONS.md`.
- Fallback (only if config-cli is unusable): realm import with env placeholders + documented reset procedure. Requires a PR note.

## Consequences
+ Reproducible realm in every environment; production LDAP is just env + file selection.
− Extra one-shot container and a version-coupling constraint.
