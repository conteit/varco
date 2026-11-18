# ADR-0012 — Adoption docs as code on GitHub Pages, kept in lock-step with the product

**Status:** Accepted · **Date:** 2026-11-18

## Context
Adopters need usage, deployment and configuration docs that match the version they run. The owner requires every change to stay aligned with the published doc pages. Engineering docs (`docs/`: SPEC, ADRs, PLAN, tasks) serve builders; adopters need a navigable site.

## Decision
- **VitePress** site in `website/` (pnpm workspace member) — same Node/Vite toolchain as the SPA, no Python, built-in local search, Markdown with file includes. Published to **GitHub Pages via GitHub Actions** (free for public repos).
- **Structure:** *Getting started* · *Guida utente* (Italian — end users are Italian: Dipendente, Referente, Amministratore) · *Deploy* (local, Codespaces, single VM, home server + tunnel, production LDAP/AD, TLS, backup/restore, upgrades) · *Configure* (env reference, branding, Keycloak & LDAP, retention, security headers) · *API reference* · *Architecture & ADRs* · *Security* · *Contributing* · *Changelog*. Site language: English, except the user guide.
- **Single sources, generated pages** (so drift is impossible, not just discouraged):
  - Env reference generated from annotated `.env.example` (`# @doc`, `# @default`, `# @required` comments) by `scripts/docs-gen`.
  - API reference generated from `api/openapi.yaml` (static Scalar/Redoc bundle, no runtime CDN).
  - Config examples (`infra/keycloak/config/**`, `compose.prod.yaml`, Caddyfile snippets) embedded with VitePress file includes, never copy-pasted.
  - ADRs and ARCHITECTURE included from `docs/`.
  - Screenshots produced by `make screenshots`.
  - Changelog = release-please `CHANGELOG.md`.
- **Alignment gate in CI:**
  1. `make docs-gen` output must be committed (CI fails if regeneration produces a diff).
  2. `docs-impact` check: PRs touching user-facing paths (`api/`, `.env.example`, `compose*.yaml`, `infra/keycloak/config/`, `infra/edge/`, `branding/`, `frontend/src/features/**`, `keycloak-theme/`, `backend/src/main/resources/application*.yml`) must also touch `website/`, or carry label `docs:none` with a justification line in the PR body (reviewers verify).
  3. Site build, dead-link check (lychee) and spell/style check on every PR; preview build uploaded as an artifact.
- **Versioning:** on each release the site is built from the tag and published at `/`; `main` is published at `/next/` with a banner ("documentazione della versione in sviluppo"). One Pages deployment assembles both.

## Consequences
+ Docs can't silently drift: generated references, includes, and a CI gate.
+ Every feature PR leaves the user guide current.
− Slightly larger PRs; a docs-only owner (D1) is needed for the skeleton.
