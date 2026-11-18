---
id: MT-04
title: Phone offline: queue and sync
core: true
covers: [AC-16, AC-17, AC-63]
triggers: [frontend/src/app/outbox/**, frontend/src/features/today/**, frontend/vite.config.ts]   # paths whose changes since last release make this script required
duration: 10 min
---
# MT-04 — Phone offline: queue and sync

**Setup:** Installed PWA from MT-03, user *Fuori sede*.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Enable airplane mode, reopen app | Last known status + *Offline* indicator | ☐ |
| 2 | Tap *Registra ingresso* | *In attesa di invio* shown | ☐ |
| 3 | Wait 2 min, disable airplane mode, bring app to foreground | Pending item sent; status *In sede* with the original tap time (not the sync time) | ☐ |
| 4 | As referente on desktop, check *Registro* | Exactly one ENTER at the original time | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
