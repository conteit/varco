---
id: MT-08
title: Accessibility smoke with screen readers
core: false
covers: [NFR-02]
triggers: [frontend/src/ui/**, frontend/src/features/**, keycloak-theme/**]   # paths whose changes since last release make this script required
duration: 15 min
---
# MT-08 — Accessibility smoke with screen readers

**Setup:** iPhone VoiceOver and/or macOS VoiceOver; keyboard only on desktop.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | VoiceOver: log in, record entry | Every control announced in Italian with role; status change announced | ☐ |
| 2 | Keyboard only: navigate *Sede › Ora*, open *Chiudi presenza…*, cancel | Visible focus everywhere, dialog traps and returns focus | ☐ |
| 3 | 200 % zoom on desktop | No clipped content, no horizontal scroll on main screens | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
