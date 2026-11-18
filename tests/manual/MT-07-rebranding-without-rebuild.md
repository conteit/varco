---
id: MT-07
title: Rebranding without rebuild
core: false
covers: [AC-60, AC-61, AC-62]
triggers: [branding/**, packages/brand/**, keycloak-theme/**, infra/edge/**]   # paths whose changes since last release make this script required
duration: 10 min
---
# MT-07 — Rebranding without rebuild

**Setup:** MT-01 instance.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Set `VARCO_BRAND_NAME=Acme Presenze`, `VARCO_BRAND_PRIMARY=#B00020`, replace `branding/logo.svg`; `./varco up` | Restart only, no image build | ☐ |
| 2 | Reload app and login page | Name, colour, logo applied on both; text on primary readable | ☐ |
| 3 | Try a very light primary (`#FFF3B0`) | Contrast auto-adjusted; still readable | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
