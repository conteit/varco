---
id: MT-03
title: Phone: install PWA, enter/exit, undo, planned exit (iPhone + Android)
core: true
covers: [AC-10, AC-11, AC-15, AC-22, AC-62, NFR-01]
triggers: [frontend/**, infra/edge/**]   # paths whose changes since last release make this script required
duration: 20 min
---
# MT-03 — Phone: install PWA, enter/exit, undo, planned exit (iPhone + Android)

**Setup:** Instance reachable from the phone over HTTPS (LAN URL with trusted Caddy CA, or tunnel). One iPhone (Safari) and one Android (Chrome) if available.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Install the app (Share › Aggiungi alla schermata Home / Installa app) | Icon and name from branding; opens standalone | ☐ |
| 2 | Log in as `mario.rossi`, tap *Registra ingresso* | Status *In sede · Padova · dalle HH:MM* immediately; light haptic on Android | ☐ |
| 3 | Tap *Annulla* on the toast within 10 s | Back to *Fuori sede* | ☐ |
| 4 | Enter again, set *Uscita prevista* 17:30 | Chip shows 17:30 | ☐ |
| 5 | Kill the app, reopen from the icon | Still logged in, state correct, no login loop (critical on iOS) | ☐ |
| 6 | Tap *Registra uscita* | *Fuori sede*; *Storico* shows the visit | ☐ |
| 7 | Primary action reachable with one thumb; text readable at default font size | Yes | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
