---
id: MT-05
title: Referente day: live view, coverage, corrections
core: true
covers: [AC-30, AC-31, AC-32, AC-33, AC-36]
triggers: [frontend/src/features/office-live/**, backend/**/presence/**]   # paths whose changes since last release make this script required
duration: 15 min
---
# MT-05 — Referente day: live view, coverage, corrections

**Setup:** Desktop browser as `giulia.bianchi` (referente PAD); phone as `marco.ferri` (referente PAD); a third session as `mario.rossi`.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Giulia enters; open *Sede › Ora* | Count 1; banner *Sei l'unico referente in sede* | ☐ |
| 2 | Marco enters from phone and sets planned exit 16:00 | Within 20 s Giulia sees count 2 and *Un altro referente è in sede: Marco Ferri, fino alle 16:00* | ☐ |
| 3 | Check the coverage timeline | Marco's lane ends 16:00; gap after Giulia's planned/close time labelled *Scoperto* if applicable; readable | ☐ |
| 4 | Mario enters; Giulia uses *Chiudi presenza…* on Mario with a note | Mario's phone/desktop shows *Fuori sede* after refresh; log shows *Rettifica* with Giulia and the note | ☐ |
| 5 | Resize to 360 px wide | Timeline lanes stack, nothing overlaps | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
