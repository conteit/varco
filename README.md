# Varco

[![CI](https://github.com/conteit/varco/actions/workflows/ci.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/ci.yml)
[![CodeQL](https://github.com/conteit/varco/actions/workflows/codeql.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/codeql.yml)
[![Scorecard](https://github.com/conteit/varco/actions/workflows/scorecard.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/scorecard.yml)
[![Docs](https://github.com/conteit/varco/actions/workflows/docs.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/docs.yml)
[![Release](https://github.com/conteit/varco/actions/workflows/release-please.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/release-please.yml)
[![GHCR](https://github.com/conteit/varco/actions/workflows/images.yml/badge.svg)](https://github.com/conteit/varco/actions/workflows/images.yml)
[![Licence](https://img.shields.io/badge/licence-Apache--2.0-blue)](LICENSE)

**Office presence, without the friction.** An installable Italian-language PWA for recording entries and exits from your phone, planning office days, and giving office referenti a live view of who is in, and whether another referente is available.

> Status: **planning pack**. The code is built by autonomous coding agents from the documents below; this README is rewritten in issue H3.

## Getting started

_Filled by H3 (dist package, from source, Codespaces). From source today: `make bootstrap && make check`._

## Screenshots

_Filled by H3._

## Stack
React + TypeScript PWA · Keycloak (OIDC Auth Code + PKCE, federated to multiple LDAP directories, custom login theme) · Spring Boot 4 / Java 25 (Spring Modulith) · PostgreSQL · Caddy · Docker Compose.

## Engineering documents
| Document | Purpose |
|---|---|
| [`docs/SPEC.md`](docs/SPEC.md) | Roles, business rules (BR-xx), acceptance criteria (AC-xx), NFRs |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Components, auth flow, data model, API, configuration, deployment |
| [`docs/DESIGN.md`](docs/DESIGN.md) | Visual direction, screens, Italian copy glossary |
| [`docs/adr/`](docs/adr/) | Architecture decision records |
| [`tests/manual/`](tests/manual/) | Manual test scripts that gate releases |
| [`scripts/agents/`](scripts/agents/) | Local agent dispatcher and prompts (implementer, reviewer, planner) |
| [`AGENTS.md`](AGENTS.md) | Rules every coding agent follows |

Work is tracked in **GitHub issues** (task cards, design and handoff comments) — see the pinned *Plan* issue.

The final README (badges, getting started with the dist package / from source / Codespaces) and the adoption docs site on GitHub Pages are built by issues D1 and H3.

## Contributing

_Filled by H3. Conventional Commits and DCO sign-off (`git commit -s`) are enforced in CI; see [`AGENTS.md`](AGENTS.md)._

## Privacy note
Systems that record employee presence can fall under art. 4 of the Statuto dei Lavoratori and the GDPR. Production use needs review by the employer's DPO/HR. This is not legal advice.

## Licence
[Apache License 2.0](LICENSE)
