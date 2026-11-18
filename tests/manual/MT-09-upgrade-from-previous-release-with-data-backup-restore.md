---
id: MT-09
title: Upgrade from previous release with data, backup & restore
core: true
covers: [NFR-09]
triggers: [backend/src/main/resources/db/**, dist/**, infra/keycloak/**]   # paths whose changes since last release make this script required
duration: 20 min
---
# MT-09 — Upgrade from previous release with data, backup & restore

**Setup:** Clean folder; previous release dist package.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Install previous release in demo mode, create entries/plans/a correction | Data visible | ☐ |
| 2 | `./varco backup` | Backup file created | ☐ |
| 3 | `./varco upgrade <RC version>` | Checksums + attestations verified, migration OK, all healthy | ☐ |
| 4 | Check data from step 1 | Intact; history and audit unchanged | ☐ |
| 5 | `./varco down -v && ./varco up && ./varco restore <file>` | Data restored; login works | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
