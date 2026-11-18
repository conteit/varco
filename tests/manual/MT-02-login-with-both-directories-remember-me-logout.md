---
id: MT-02
title: Login with both directories, remember me, logout
core: true
covers: [AC-01, AC-02, AC-03, AC-05]
triggers: [keycloak-theme/**, infra/keycloak/**, frontend/src/app/auth/**]   # paths whose changes since last release make this script required
duration: 10 min
---
# MT-02 — Login with both directories, remember me, logout

**Setup:** MT-01 instance. Test users from ARCHITECTURE § 7.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Log in as `mario.rossi` (ldap-a) with a wrong password | Italian error on the branded page, no stack trace | ☐ |
| 2 | Log in as `mario.rossi` correctly with *Ricordami* ticked | Lands on *Oggi* | ☐ |
| 3 | Close the browser completely, reopen `/` | Back on *Oggi* without typing credentials | ☐ |
| 4 | *Profilo › Esci*, then open `/` | Login page shown | ☐ |
| 5 | Log in as `sara.neri` (ldap-b) | Lands on *Oggi*; *Sede* tab visible | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
