---
id: MT-01
title: Dist demo install on a clean machine (macOS arm64)
core: true
covers: [NFR-05, NFR-09]
triggers: [dist/**, compose*.yaml, infra/**, docker-bake.hcl]   # paths whose changes since last release make this script required
duration: 15 min
---
# MT-01 — Dist demo install on a clean machine (macOS arm64)

**Setup:** Mac with Docker Desktop, no previous Varco data (`docker volume ls` shows none). Download the RC dist package from the RC issue.

| # | Step | Expected result | Pass |
|---|---|---|---|
| 1 | Verify checksum: `shasum -a 256 -c CHECKSUMS` | OK for every file | ☐ |
| 2 | `./varco verify` | All image attestations verified for the RC digests | ☐ |
| 3 | `./varco init --mode demo` | `.env` created, secrets generated, no prompts beyond confirmation | ☐ |
| 4 | `./varco up` then `./varco status` | All services healthy within 3 min | ☐ |
| 5 | Open `https://localhost:8443`, accept the local CA | Branded login page (Italian) | ☐ |
| 6 | README *Getting started (dist)* commands match exactly what you ran | No deviation | ☐ |

**Record in the RC issue:** pass/fail per step, device/OS/browser versions, screenshots for failures. Any failure → bug issue linked from the RC issue.
