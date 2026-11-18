---
id: MT-06
title: Administration: offices (with and without capacity), roles, audit
core: true
covers: [AC-40, AC-41, AC-42, AC-44, AC-45, AC-47, AC-50]
triggers: [frontend/src/features/admin/**, frontend/src/features/audit/**, backend/**/office/**, backend/**/identity/**, backend/**/audit/**]   # paths whose changes since last release make this script required
duration: 15 min
---
# MT-06 — Administration: offices (with and without capacity), roles, audit

**Setup:** Desktop as `admin.varco`.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Create office *Torino* without capacity | Created; table shows `—`; live view shows only *N presenti* | ☐ |
| 2 | Set capacity 10, then *Rimuovi capienza* | Both saved; audit shows two updates with before/after | ☐ |
| 3 | Pre-register `luca.verdi`, make him *Referente* of MIL; log in as Luca (ldap-b) | Luca sees *Sede* for Milano | ☐ |
| 4 | Try to remove *Amministratore* from yourself (only admin) | Blocked with *Deve restare almeno un amministratore attivo.* | ☐ |
| 5 | Export CSV of *Registro* for PAD this week, open in Excel/Numbers | Accented names correct, `;` columns, local times | ☐ |
| 6 | Archive *Torino* | Gone from pickers; history visible to admin | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
