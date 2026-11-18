---
id: MT-10
title: Production LDAP / Active Directory connection (when available)
core: false
covers: [BR-03, NFR-05]
triggers: [infra/keycloak/config/**, compose.prod.yaml]   # paths whose changes since last release make this script required
duration: 20 min
---
# MT-10 — Production LDAP / Active Directory connection (when available)

**Setup:** A real or staging directory (OpenLDAP or AD) with a read-only bind account; dist `--mode local --ldap-preset ad|openldap`.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Configure preset with ldaps and corporate CA (`KC_TRUSTSTORE_PATHS`) | Keycloak connects; *Test connection* OK in config-cli log | ☐ |
| 2 | Log in with a real account | First login provisions the user; name/email correct | ☐ |
| 3 | Change the user's display name in the directory, wait for sync, log in again | Name updated in the app | ☐ |
| 4 | Confirm no write attempts in directory logs | Read-only | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
