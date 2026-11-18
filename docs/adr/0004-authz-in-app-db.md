# ADR-0004 — Authentication in Keycloak, authorization in the app database

**Status:** Accepted · **Date:** 2026-11-18

## Context
Office-admin is a role **scoped per office**, and both admins and office-admins manage roles from the app UI. LDAP directories are read-only and owned by the customer. Keycloak realm roles are global; modelling "referente of office X" there would need per-office groups/roles managed through the Keycloak admin API with a privileged service account.

## Decision
- Keycloak (federated LDAP, read-only) answers **who** the user is. Tokens carry identity (`sub`, `preferred_username`, name, email) and audience — no app roles.
- App DB answers **what** they may do: `app_user.is_admin`, `office_membership(role)`.
- JIT provisioning on first API call; pre-provisioning by username so roles can be assigned before first login (SPEC BR-01, BR-37).
- Bootstrap admins via `VARCO_BOOTSTRAP_ADMINS`.

## Consequences
+ No privileged Keycloak service account needed by the backend; LDAP untouched.
+ Role changes are immediate (no token refresh needed) and fully audited in the app.
− Authorization isn't visible in tokens for other consumers (none planned).
− Usernames are the join key for pre-provisioning → must be unique across directories (BR-03).
- Option for later: map an LDAP group to a Keycloak realm role `varco-admin` and treat it as an *additional* admin source. Not in v1 to keep one source of truth.
